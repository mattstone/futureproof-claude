# The pipeline cockpit. Index defaults to the active pipeline (accepted
# applications are managed via their contracts), but an explicit status
# filter or a search reaches EVERY application — an admin must always be
# able to find an application by ID, email or address.
class Console::ApplicationsController < Console::ResourceController
  before_action -> { require_capability(:view_pipeline) }
  before_action :set_application, except: [ :index ]
  before_action :log_view, only: [ :show ]

  resource Application
  sortable created: "applications.created_at",
           value: "applications.home_value",
           status: "applications.status",
           updated: "applications.updated_at"
  default_sort :created, :desc
  preloads :user, :mortgage

  csv_column("ID") { |a| a.id }
  csv_column("Customer") { |a| a.user.display_name }
  csv_column("Email") { |a| a.user.email }
  csv_column("Address") { |a| a.address }
  csv_column("Home value") { |a| a.home_value }
  csv_column("Status") { |a| a.status }
  csv_column("Mortgage") { |a| a.mortgage&.name }
  csv_column("Created") { |a| a.created_at.iso8601 }

  def show
    @versions = @application.application_versions.includes(:user).recent.limit(50)
    @agent_actions = @application.agent_actions.includes(:ai_agent).order(created_at: :desc)
    @outstanding_docs_count = @application.application_documents.where(status: %w[pending rejected]).count
    @jurisdiction_rules = begin
      EpmJurisdictionService.new(@application.region).rules
    rescue StandardError
      nil
    end
    @unread_messages_count = @application.unread_customer_messages_count
    @quotes = @application.quotes.latest_first
    @lenders = Lender.status_active.order(:name)
    set_messages
  end

  # Drives the full Application#approve! workflow (loan terms, broker
  # commission, contract generation) — not a bare status flip.
  def approve
    # Spec (customers.md): KYC + AML are required in every market before
    # approval. The panel warns; this is the enforcement.
    unless @application.kyc_submission&.verified? && @application.aml_check&.passed?
      redirect_to console_application_path(@application),
                  alert: "Cannot approve — KYC and AML must both be cleared first." and return
    end

    loan_amount = params[:loan_amount].to_f
    interest_rate = params[:interest_rate].to_f
    term_years = params[:term_years].to_i
    lender = Lender.find_by(id: params[:lender_id])

    if loan_amount <= 0 || interest_rate <= 0 || term_years <= 0 || lender.nil?
      redirect_to console_application_path(@application),
                  alert: "Approval needs a loan amount, interest rate, term and lender." and return
    end

    @application.current_user = current_user
    @application.approve!(loan_amount: loan_amount, interest_rate: interest_rate,
                          term_years: term_years, lender: lender)

    if @application.reload.contract.present?
      redirect_to console_application_path(@application),
                  notice: "Application approved — contract ##{@application.contract.id} created."
    else
      redirect_to console_application_path(@application),
                  notice: "Application approved. Contract was NOT auto-created (#{@application.contract_generation_failure || 'see logs'}) — create it manually.",
                  status: :see_other
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to console_application_path(@application), alert: "Approval failed: #{e.message}"
  end

  def reject
    if params[:rejected_reason].blank?
      redirect_to console_application_path(@application), alert: "A rejection reason is required." and return
    end

    @application.current_user = current_user
    @application.reject!(reason: params[:rejected_reason])
    redirect_to console_application_path(@application), notice: "Application rejected."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to console_application_path(@application), alert: "Rejection failed: #{e.message}"
  end

  def advance_to_processing
    if @application.status_submitted?
      @application.advance_to_processing_with_checklist!(current_user)
      redirect_to console_application_path(@application), notice: "Application advanced to processing and checklist created."
    else
      redirect_to console_application_path(@application), alert: "Application must be submitted to advance to processing."
    end
  end

  def update_checklist_item
    @checklist_item = @application.application_checklists.find(params[:checklist_item_id])

    if params[:completed] == "true"
      @checklist_item.mark_completed!(current_user)
      log_checklist_change("completed")
      flash.now[:notice] = @application.checklist_completed? ? "All checklist items completed! Application can now be approved." : "Checklist item marked as completed."
    else
      @checklist_item.mark_incomplete!
      log_checklist_change("incomplete")
      flash.now[:notice] = "Checklist item marked as incomplete."
    end

    broadcast_checklist_update

    respond_to do |format|
      format.html do
        flash[:notice] = flash.now[:notice]
        redirect_to console_application_path(@application)
      end
      format.turbo_stream { render :checklist_updated }
    end
  end

  # Replaces the legacy JSON valuation flow with a plain form post.
  def update_valuation
    new_valuation = params[:property_valuation_middle].to_i

    if new_valuation < 100_000 || new_valuation > 50_000_000
      redirect_to console_application_path(@application), alert: "Valuation must be between $100,000 and $50,000,000." and return
    end

    old_valuation = @application.property_valuation_middle
    @application.current_user = current_user

    if @application.update(property_valuation_middle: new_valuation)
      explanation = params[:valuation_explanation].presence || "No reason provided"
      @application.application_versions.create!(
        user: current_user,
        action: "valuation_updated",
        change_details: "Property valuation changed from #{helpers.number_to_currency(old_valuation, precision: 0)} to #{helpers.number_to_currency(new_valuation, precision: 0)} by #{current_user.display_name}. Reason: #{explanation}"
      )
      redirect_to console_application_path(@application), notice: "Property valuation updated."
    else
      redirect_to console_application_path(@application), alert: "Valuation update failed: #{@application.errors.full_messages.to_sentence}"
    end
  end

  # --- Compliance decisions -------------------------------------------------
  # Thin audited wrappers over the model lifecycle methods; the decision
  # maker's name lands on the record AND in the audit log.

  def verify_kyc
    submission = @application.kyc_submission
    return compliance_missing("KYC") unless submission

    submission.verify!(current_user.display_name)
    audit_compliance("kyc_verified", submission, params[:notes])
    redirect_to console_application_path(@application), notice: "KYC verified."
  end

  def reject_kyc
    submission = @application.kyc_submission
    return compliance_missing("KYC") unless submission
    return compliance_reason_required unless params[:reason].present?

    submission.reject!(params[:reason], current_user.display_name)
    audit_compliance("kyc_rejected", submission, params[:reason])
    redirect_to console_application_path(@application), notice: "KYC rejected — the customer must resubmit."
  end

  def pass_aml
    check = @application.aml_check
    return compliance_missing("AML") unless check

    check.pass!
    audit_compliance("aml_passed", check, params[:notes])
    redirect_to console_application_path(@application), notice: "AML check passed."
  end

  def fail_aml
    check = @application.aml_check
    return compliance_missing("AML") unless check
    return compliance_reason_required unless params[:reason].present?

    check.fail!(params[:reason])
    audit_compliance("aml_failed", check, params[:reason])
    redirect_to console_application_path(@application), notice: "AML check failed — application should not proceed."
  end

  def create_message
    @message = @application.application_messages.build(message_params)
    @message.sender = current_user
    @message.message_type = "admin_to_customer"
    @message.status = "draft"

    respond_to do |format|
      if @message.save
        if params[:send_now].present?
          if @message.send_message!
            format.html { redirect_to console_application_path(@application), notice: "Message sent." }
            format.turbo_stream do
              flash.now[:notice] = "Message sent."
              set_messages
              render :message_sent
            end
          else
            format.html { redirect_to console_application_path(@application), alert: "Failed to send message." }
            format.turbo_stream do
              flash.now[:alert] = "Failed to send message."
              render :message_error
            end
          end
        else
          format.html { redirect_to console_application_path(@application), notice: "Message saved as draft." }
          format.turbo_stream do
            flash.now[:notice] = "Message saved as draft."
            set_messages
            render :message_draft_saved
          end
        end
      else
        format.html { redirect_to console_application_path(@application), alert: @message.errors.full_messages.to_sentence }
        format.turbo_stream do
          set_messages(keep_new_message: @message)
          render :message_validation_error
        end
      end
    end
  end

  def send_message
    @message = @application.application_messages.find(params[:message_id])

    respond_to do |format|
      if @message.draft? && @message.send_message!
        format.html { redirect_to console_application_path(@application), notice: "Message sent." }
        format.turbo_stream do
          flash.now[:notice] = "Message sent."
          set_messages
          render :message_sent
        end
      else
        format.html { redirect_to console_application_path(@application), alert: "Failed to send message." }
        format.turbo_stream do
          flash.now[:alert] = "Failed to send message."
          render :message_error
        end
      end
    end
  end

  protected

  def base_scope
    scope = scope_by_jurisdiction(scoped_applications, :region)

    if params[:status].present?
      scope = scope.where(status: params[:status])
    elsif params[:search].blank?
      scope = scope.where.not(status: :accepted) # default: active pipeline
    end

    scope
  end

  # Numeric terms also match the application ID.
  def apply_search(scope)
    term = params[:search].to_s.strip
    return scope if term.blank?

    scope = scope.joins(:user)
    like = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    if term.match?(/\A\d+\z/)
      scope.where(
        "applications.id = :id OR applications.address ILIKE :like OR users.first_name ILIKE :like OR users.last_name ILIKE :like OR users.email ILIKE :like",
        id: term.to_i, like: like
      )
    else
      scope.where(
        "applications.address ILIKE :like OR users.first_name ILIKE :like OR users.last_name ILIKE :like OR users.email ILIKE :like",
        like: like
      )
    end
  end

  private

  def compliance_missing(kind)
    redirect_to console_application_path(@application), alert: "No #{kind} record exists for this application yet."
  end

  def compliance_reason_required
    redirect_to console_application_path(@application), alert: "A reason is required — it goes on the record and in the audit log."
  end

  def audit_compliance(action, resource, reason)
    AuditLog.log_action(user: current_user, action: action, resource: resource,
                        reason: reason.presence || "No notes", notes: "Application ##{@application.id}")
  end

  def set_application
    @application = scoped_applications.find(params[:id])
  end

  def set_messages(keep_new_message: nil)
    @messages = @application.message_threads
    @new_message = keep_new_message || @application.application_messages.build
    @ai_agents = AiAgent.active.order(:name)
    @suggested_agent = AiAgent.suggest_for_application(@application)
  end

  def log_view
    @application.log_view_by(current_user)
  end

  def log_checklist_change(state)
    @application.application_versions.create!(
      user: current_user,
      action: "checklist_updated",
      change_details: "Checklist item '#{@checklist_item.name}' marked as #{state} by #{current_user.display_name}"
    )
  end

  # CONTRACT: renders into the CUSTOMER dashboard — partial path, target id
  # and locals must stay byte-identical to the legacy admin's broadcast.
  def broadcast_checklist_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{@application.user_id}_dashboard",
      target: "checklist-#{@application.id}",
      partial: "dashboard/customer_checklist",
      locals: { application: @application }
    )
  end

  def message_params
    params.require(:application_message).permit(:subject, :content, :parent_message_id, :ai_agent_id)
  end
end
