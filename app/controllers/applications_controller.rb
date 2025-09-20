class ApplicationsController < ApplicationController
  before_action :authenticate_user!, except: [:messages]
  before_action :verify_secure_token, only: [:messages], if: -> { params[:token].present? }
  before_action :authenticate_user!, only: [:messages], unless: -> { params[:token].present? }
  before_action :prevent_admin_access, except: [:messages]
  before_action :set_application, only: [:show, :edit, :update, :income_and_loan, :update_income_and_loan, :summary, :submit, :congratulations, :messages, :reply_to_message, :mark_all_messages_as_read]

  def new
    # Get or create application
    @application = current_user.applications.status_created.first || current_user.applications.build

    # Set defaults
    @application.ownership_status = :individual
    @application.borrower_age = 60 if @application.borrower_age.to_i < 18

    # Pre-populate home value if passed from home page calculator
    if params[:home_value].present?
      @application.home_value = params[:home_value].to_i
    end
  end

  def create
    # Get existing created application or build new one
    @application = current_user.applications.status_created.first || current_user.applications.build
    
    # Update with form data
    @application.assign_attributes(application_params)
    
    # If no existing mortgage checkbox is unchecked, clear the mortgage amount
    unless @application.has_existing_mortgage?
      @application.existing_mortgage_amount = 0
    end
    
    @application.status = :property_details
    
    if @application.save
      redirect_to income_and_loan_application_path(@application), notice: 'Property details saved successfully!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # Step 2 completion page - could redirect to step 3 later
  end

  def edit
    # Allow editing of step 2 information
  end

  def update
    # Update status to property_details when updating property details
    @application.assign_attributes(application_params)
    
    # If no existing mortgage checkbox is unchecked, clear the mortgage amount
    unless @application.has_existing_mortgage?
      @application.existing_mortgage_amount = 0
    end
    
    @application.status = :property_details
    
    if @application.save
      redirect_to income_and_loan_application_path(@application), notice: 'Property details updated successfully!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def income_and_loan
    # Show income and loan options form (step 3)
    # Status should already be property_details from previous step
  end

  def update_income_and_loan
    # Assign parameters and validate with context
    @application.assign_attributes(income_loan_params)
    # Set status to income_and_loan_options when completing this step
    @application.status = :income_and_loan_options
    
    if @application.valid?(:income_loan_update) && @application.save
      # Status is now income_and_loan_options after completing income and loan step
      redirect_to summary_application_path(@application), notice: 'Income and loan details saved successfully!'
    else
      render :income_and_loan, status: :unprocessable_entity
    end
  end

  def summary
    # Show application summary (step 4)
  end

  def submit
    # Submit the application and send confirmation email
    @application.update!(status: :submitted)
    
    # Send confirmation email
    UserMailer.application_submitted(@application).deliver_now
    
    redirect_to congratulations_application_path(@application), notice: 'Your application has been submitted successfully!'
  end

  def congratulations
    # Show congratulations page after submission
  end

  def messages
    # Show messages page for customer
    @messages = @application.message_threads
    @new_message = @application.application_messages.build
    
    # If a specific message ID is provided (from email link), highlight it
    @highlight_message_id = params[:message_id]&.to_i
    
    # Mark admin messages as read when customer views them
    @application.application_messages.admin_messages.unread.update_all(
      status: 'read', 
      read_at: Time.current
    )
  end

  def reply_to_message
    # Customer replying to admin message
    @message = @application.application_messages.build(reply_params)
    @message.sender = current_user
    @message.message_type = 'customer_to_admin'
    @message.status = 'sent'
    @message.sent_at = Time.current
    
    # If replying to a specific message, mark the parent as replied
    if params[:parent_message_id].present?
      parent_message = @application.application_messages.find(params[:parent_message_id])
      parent_message.mark_as_replied!
      @message.parent_message = parent_message
    end
    
    respond_to do |format|
      if @message.save
        format.html { redirect_to messages_application_path(@application), notice: 'Your reply has been sent!' }
        format.turbo_stream { 
          flash.now[:notice] = 'Your reply has been sent!'
          render :reply_success 
        }
      else
        format.html { 
          @messages = @application.message_threads
          @new_message = @message
          render :messages, status: :unprocessable_entity
        }
        format.turbo_stream { render :reply_error }
      end
    end
  end

  def mark_all_messages_as_read
    if @application.user == current_user
      # Mark all admin messages as read for this application
      @application.application_messages
                  .where(message_type: 'admin_to_customer', status: 'sent')
                  .update_all(status: 'read')

      # Get updated total unread count across all applications
      unread_count = current_user.applications.joins(:application_messages)
        .where(application_messages: { message_type: 'admin_to_customer', status: 'sent' })
        .count('application_messages.id')

      render json: {
        success: true,
        unread_count: unread_count,
        message: 'All messages marked as read'
      }
    else
      render json: { success: false, error: 'Unauthorized' }, status: :forbidden
    end
  end

  def autocomplete
    query = params[:query]

    if query.blank? || query.length < 3
      render json: []
      return
    end

    begin
      # Get suggestions from CoreLogic API
      service = CoreLogicService.new
      suggestions = service.get_property_suggestions(query)

      # Format for autocomplete display
      formatted_suggestions = suggestions.map do |suggestion|
        {
          id: suggestion['property_id'] || suggestion['propertyId'],
          text: suggestion['suggestion'],
          property_type: suggestion['suggestion_type'] || suggestion['suggestionType'] || 'Property',
          is_active: suggestion['is_active_property'] || suggestion['isActiveProperty'],
          is_unit: (suggestion['suggestion_type'] || suggestion['suggestionType'])&.downcase&.include?('unit')
        }
      end

      render json: formatted_suggestions
    rescue => e
      Rails.logger.error "CoreLogic autocomplete error: #{e.message}"
      render json: { error: 'Unable to fetch suggestions' }, status: :service_unavailable
    end
  end

  def get_property_details
    property_id = params[:property_id]

    if property_id.blank?
      render json: { error: 'Property ID is required' }, status: :bad_request
      return
    end

    begin
      service = CoreLogicService.new
      property_details = service.get_complete_property_details(property_id)

      render json: property_details
    rescue => e
      Rails.logger.error "CoreLogic property details error: #{e.message}"
      render json: { error: 'Unable to fetch property details' }, status: :service_unavailable
    end
  end

  private

  def prevent_admin_access
    if current_user&.admin?
      redirect_to dashboard_path, alert: 'Admin users cannot complete applications. This feature is for customers only.'
    end
  end

  def set_application
    @application = current_user.applications.find(params[:id])
  end

  def application_params
    params.require(:application).permit(
      :address,
      :home_value,
      :ownership_status,
      :property_state,
      :has_existing_mortgage,
      :existing_mortgage_amount,
      :status,
      :rejected_reason,
      :borrower_age,
      :borrower_names,
      :company_name,
      :super_fund_name,
      :property_id,
      :property_type,
      :property_images,
      :property_valuation_low,
      :property_valuation_middle,
      :property_valuation_high,
      :corelogic_data
    )
  end

  def income_loan_params
    params.require(:application).permit(
      :loan_term,
      :income_payout_term,
      :mortgage_id,
      :growth_rate
    )
  end

  def reply_params
    params.require(:application_message).permit(:subject, :content, :parent_message_id)
  end
  
  def verify_secure_token
    return unless params[:token].present?
    
    begin
      # Decrypt and verify the secure token
      payload = SecureTokenEncryptor.decrypt_and_verify(params[:token])
      
      # Check if token has expired
      if payload['expires_at'] < Time.current.to_i
        redirect_to new_user_session_path, alert: 'This link has expired. Please log in to access your messages.'
        return
      end
      
      # Verify the application and user match, and that the token is for the requested application
      application = Application.find_by(id: payload['application_id'])
      user = User.find_by(id: payload['user_id'])
      requested_application_id = params[:id].to_i
      
      unless application && user && application.user == user && application.id == requested_application_id
        redirect_to new_user_session_path, alert: 'Invalid access link. Please log in to continue.'
        return
      end
      
      # Store the intended redirect path in Rails cache (session gets reset on login)
      # Redirect to dashboard with application expanded instead of messages page
      intended_path = "#{dashboard_path}?section=applications&application_id=#{application.id}"
      
      cache_key = "user_#{user.id}_pending_redirect"
      Rails.cache.write(cache_key, intended_path, expires_in: 10.minutes)
      
      redirect_to new_user_session_path, notice: 'Please log in to access your message.'
      
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_user_session_path, alert: 'Invalid access link. Please log in to continue.'
    end
  end
end