class Admin::ApplicationsController < Admin::BaseController
  before_action :set_application, only: [:show, :edit, :update, :send_message, :create_message, :advance_to_processing, :update_checklist_item, :approve, :reject]
  before_action :set_application_versions, only: [:show]
  before_action :set_messages, only: [:show, :edit, :update_checklist_item]
  before_action :log_view, only: [:show]

  def index
    @applications = filtered_applications.page(params[:page]).per(10)

    # Status filter options (accepted included — reachable via explicit filter)
    @status_options = Application.statuses.map { |key, _| [key.humanize, key] }

    respond_to do |format|
      format.html # Full page render
      format.turbo_stream # Turbo Frame partial render
    end
  end

  def search
    # Same logic as index but for POST requests via Turbo Stream
    @applications = filtered_applications.page(params[:page]).per(10)
    @status_options = Application.statuses.map { |key, _| [key.humanize, key] }

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("applications_results", partial: "results") }
      format.html { render :index }
    end
  end

  def show
    @agent_actions = @application.agent_actions.includes(:ai_agent).order(created_at: :desc)
    @outstanding_docs_count = @application.application_documents.where(status: ['pending', 'rejected']).count
    @unread_messages_count = @application.unread_customer_messages_count
    @quotes = @application.quotes.latest_first
    @lenders = Lender.order(:name)
  end

  # Drives the full Application#approve! workflow (loan terms, broker
  # commission, contract generation) — not a bare status flip.
  def approve
    loan_amount = params[:loan_amount].to_f
    interest_rate = params[:interest_rate].to_f
    term_years = params[:term_years].to_i
    lender = Lender.find_by(id: params[:lender_id])

    if loan_amount <= 0 || interest_rate <= 0 || term_years <= 0 || lender.nil?
      redirect_to admin_application_path(@application),
                  alert: "Approval needs a loan amount, interest rate, term and lender." and return
    end

    @application.current_user = current_user
    @application.approve!(loan_amount: loan_amount, interest_rate: interest_rate,
                          term_years: term_years, lender: lender)

    if @application.reload.contract.present?
      redirect_to admin_application_path(@application),
                  notice: "Application approved — contract ##{@application.contract.id} created."
    else
      redirect_to admin_application_path(@application),
                  notice: "Application approved. Contract was NOT auto-created (#{@application.contract_generation_failure || 'see logs'}) — create it manually.",
                  status: :see_other
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_application_path(@application), alert: "Approval failed: #{e.message}"
  end

  def reject
    if params[:rejected_reason].blank?
      redirect_to admin_application_path(@application), alert: "A rejection reason is required." and return
    end

    @application.current_user = current_user
    @application.reject!(reason: params[:rejected_reason])
    redirect_to admin_application_path(@application), notice: "Application rejected."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_application_path(@application), alert: "Rejection failed: #{e.message}"
  end

  def new
    @application = Application.new
    @users = scoped_users.order(:first_name, :last_name)
  end

  def create
    @application = Application.new(application_params)
    @application.current_user = current_user # Track who created it

    if @application.save
      redirect_to admin_application_path(@application), notice: 'Application was successfully created.'
    else
      @users = scoped_users.order(:first_name, :last_name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Messages variables are set by set_messages before_action
  end

  def update
    @application.current_user = current_user # Track who updated it

    params_to_update = application_params
    old_status = @application.status
    old_valuation = @application.property_valuation_middle

    # Check if this is a valuation change
    valuation_change = params[:valuation_change] == 'true'

    # Clear rejected_reason if changing from rejected status to a non-rejected status
    if @application.status == 'rejected' && params_to_update[:status] && params_to_update[:status] != 'rejected'
      params_to_update[:rejected_reason] = nil
    end

    respond_to do |format|
      if @application.update(params_to_update)
        # Track valuation changes in application history
        if valuation_change && old_valuation != @application.property_valuation_middle
          new_valuation = @application.property_valuation_middle
          explanation = params[:valuation_explanation].present? ? params[:valuation_explanation] : "No reason provided"

          @application.application_versions.create!(
            user: current_user,
            action: 'valuation_updated',
            change_details: "Property valuation changed from #{ActionController::Base.helpers.number_to_currency(old_valuation, precision: 0)} to #{ActionController::Base.helpers.number_to_currency(new_valuation, precision: 0)} by #{current_user.display_name}. Reason: #{explanation}"
          )
        end

        # Check if status changed to accepted for Hotwire removal
        status_changed_to_accepted = old_status != 'accepted' && @application.status == 'accepted'

        if valuation_change
          format.json { render json: { success: true, message: 'Valuation updated successfully' } }
          format.html { redirect_to edit_admin_application_path(@application), notice: 'Property valuation was successfully updated.' }
        else
          format.html { redirect_to admin_application_path(@application), notice: 'Application status was successfully updated.' }
        end

        format.turbo_stream {
          flash.now[:notice] = valuation_change ? 'Property valuation was successfully updated.' : 'Application status was successfully updated.'
          @status_changed_to_accepted = status_changed_to_accepted
          render :status_updated
        }
      else
        # Set up variables for edit view on validation error
        @messages = @application.message_threads
        @new_message = @application.application_messages.build
        @ai_agents = AiAgent.active.order(:name)
        @suggested_agent = AiAgent.suggest_for_application(@application)

        format.json { render json: { success: false, errors: @application.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :status_update_error }
      end
    end
  end

  def create_message
    @message = @application.application_messages.build(message_params)
    @message.sender = current_user
    @message.message_type = 'admin_to_customer'
    @message.status = 'draft'

    # Determine where to redirect based on where the form was submitted from
    redirect_path = params[:from_view] == 'show' ? admin_application_path(@application) : edit_admin_application_path(@application)

    respond_to do |format|
      if @message.save
        if params[:send_now].present?
          if @message.send_message!
            format.html { redirect_to redirect_path, notice: 'Message sent successfully!' }
            format.turbo_stream { 
              flash.now[:notice] = 'Message sent successfully!'
              set_turbo_stream_variables
              render :message_sent 
            }
          else
            format.html { redirect_to redirect_path, alert: 'Failed to send message.' }
            format.turbo_stream { 
              flash.now[:alert] = 'Failed to send message.'
              render :message_error 
            }
          end
        else
          format.html { redirect_to redirect_path, notice: 'Message saved as draft!' }
          format.turbo_stream { 
            flash.now[:notice] = 'Message saved as draft!'
            set_turbo_stream_variables
            render :message_draft_saved 
          }
        end
      else
        # Handle validation errors by reloading the appropriate view
        if params[:from_view] == 'show'
          @application_versions = @application.application_versions.includes(:user).recent.limit(50)
          @messages = @application.message_threads
          @new_message = @message # Keep the invalid message object for error display
          @ai_agents = AiAgent.active.order(:name)
          @suggested_agent = AiAgent.suggest_for_application(@application)
          format.html { render :show, status: :unprocessable_entity }
          format.turbo_stream { render :message_validation_error }
        else
          @messages = @application.message_threads
          @new_message = @message # Keep the invalid message object for error display
          @ai_agents = AiAgent.active.order(:name)
          @suggested_agent = AiAgent.suggest_for_application(@application)
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream { render :message_validation_error }
        end
      end
    end
  end

  def send_message
    @message = @application.application_messages.find(params[:message_id])

    respond_to do |format|
      if @message.draft? && @message.send_message!
        format.html { redirect_to admin_application_path(@application), notice: 'Message sent successfully!' }
        format.turbo_stream { 
          flash.now[:notice] = 'Message sent successfully!'
          set_turbo_stream_variables
          render :message_sent 
        }
      else
        format.html { redirect_to admin_application_path(@application), alert: 'Failed to send message.' }
        format.turbo_stream { 
          flash.now[:alert] = 'Failed to send message.'
          render :message_error 
        }
      end
    end
  end

  def advance_to_processing
    if @application.status_submitted?
      @application.advance_to_processing_with_checklist!(current_user)
      redirect_to admin_application_path(@application), notice: 'Application advanced to processing and checklist created.'
    else
      redirect_to admin_application_path(@application), alert: 'Application must be submitted to advance to processing.'
    end
  end

  def update_checklist_item
    @checklist_item = @application.application_checklists.find(params[:checklist_item_id])
    
    if params[:completed] == 'true'
      @checklist_item.mark_completed!(current_user)
      
      # Log the checklist change
      @application.application_versions.create!(
        user: current_user,
        action: 'checklist_updated',
        change_details: "Checklist item '#{@checklist_item.name}' marked as completed by #{current_user.display_name}"
      )
      
      
      if @application.checklist_completed?
        flash[:notice] = "🎉 All checklist items completed! Application can now be accepted."
      else
        flash[:notice] = "Checklist item marked as completed."
      end
    else
      @checklist_item.mark_incomplete!
      
      # Log the checklist change
      @application.application_versions.create!(
        user: current_user,
        action: 'checklist_updated',
        change_details: "Checklist item '#{@checklist_item.name}' marked as incomplete by #{current_user.display_name}"
      )
      
      flash[:notice] = "Checklist item marked as incomplete."
    end
    
    # Broadcast the checklist update to the customer dashboard
    broadcast_checklist_update
    
    respond_to do |format|
      format.html { redirect_to params[:redirect_to] || admin_application_path(@application) }
      format.turbo_stream { render :checklist_updated }
    end
  end


  private

  # Shared filtering for index/search. Default view is the active pipeline
  # (accepted applications are managed via their contracts), but an explicit
  # status filter or a search reaches EVERY application — an admin must
  # always be able to find an application by ID/email/address.
  def filtered_applications
    scope = scoped_applications.includes(:user, :mortgage, :application_messages).recent

    if params[:search].present?
      term = params[:search].to_s.strip
      scope = scope.joins(:user)
      scope = if term.match?(/\A\d+\z/)
        scope.where(
          "applications.id = ? OR applications.address ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ? OR users.email ILIKE ?",
          term.to_i, "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%"
        )
      else
        scope.where(
          "applications.address ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ? OR users.email ILIKE ?",
          "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%"
        )
      end
    end

    if params[:status].present?
      scope = scope.where(status: params[:status])
    elsif params[:search].blank?
      scope = scope.where.not(status: :accepted) # default: active pipeline
    end

    scope
  end


  def set_application
    @application = scoped_applications.find(params[:id])
  end

  def set_application_versions
    @application_versions = @application.application_versions.includes(:user).recent.limit(50)
  end

  def set_messages
    @messages = @application.message_threads
    @new_message = @application.application_messages.build
    @ai_agents = AiAgent.active.order(:name)
    # Suggest default agent based on application context
    @suggested_agent = AiAgent.suggest_for_application(@application)
  end

  def log_view
    @application.log_view_by(current_user)
  end
  
  def broadcast_checklist_update
    # Broadcast to the user's dashboard stream for real-time updates
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{@application.user_id}_dashboard",
      target: "checklist-#{@application.id}",
      partial: "dashboard/customer_checklist",
      locals: { application: @application }
    )
  end

  def set_turbo_stream_variables
    @ai_agents = AiAgent.active.order(:name)
    @suggested_agent = AiAgent.suggest_for_application(@application)
  end

  def application_params
    # Allow status, rejected_reason, and property_valuation_middle to be updated by admins
    permitted_params = params.require(:application).permit(:status, :rejected_reason, :property_valuation_middle)

    # Validate that status is one of the allowed values
    # Note: submitted status changes are now handled by the advance_to_processing_with_checklist! method
    if permitted_params[:status].present?
      allowed_statuses = %w[rejected accepted]
      unless allowed_statuses.include?(permitted_params[:status])
        # If invalid status, don't include it in permitted params
        permitted_params.delete(:status)
      end
    end

    # Only include rejected_reason if status is 'rejected', otherwise remove it from params
    if permitted_params[:status] != 'rejected'
      permitted_params.delete(:rejected_reason)
    end

    # Validate property_valuation_middle if present
    if permitted_params[:property_valuation_middle].present?
      valuation = permitted_params[:property_valuation_middle].to_i
      if valuation < 100000 || valuation > 50000000
        # Remove invalid valuation
        permitted_params.delete(:property_valuation_middle)
      end
    end

    permitted_params
  end

  def message_params
    params.require(:application_message).permit(:subject, :content, :parent_message_id, :ai_agent_id)
  end
end
