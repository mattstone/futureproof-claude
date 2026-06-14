# Portfolio contracts. Most contracts are created automatically on approval;
# new/create here is the manual fallback the Decision panel points at when
# pool allocation failed.
class Console::ContractsController < Console::ResourceController
  before_action -> { require_capability(:view_pipeline) }
  before_action :set_contract, only: [ :show, :edit, :update, :create_message, :send_message, :transition, :destroy ]

  resource Contract
  sortable created: "contracts.created_at",
           allocated: "contracts.allocated_amount",
           status: "contracts.status",
           start: "contracts.start_date",
           end: "contracts.end_date"
  default_sort :created, :desc
  filters status: ->(scope, value) { scope.where(status: value) }
  preloads application: :user

  csv_column("ID") { |c| c.id }
  csv_column("Customer") { |c| c.application.user.display_name }
  csv_column("Application") { |c| c.application_id }
  csv_column("Status") { |c| c.status }
  csv_column("Allocated") { |c| c.allocated_amount }
  csv_column("Start") { |c| c.start_date }
  csv_column("End") { |c| c.end_date }
  csv_column("Lender") { |c| c.lender&.name }
  csv_column("Return %") { |c| c.investment_return_rate }

  # The legitimate servicing moves and where they may start from. Anything
  # else goes through edit (bare parity) — these are the audited operations.
  SERVICING_TRANSITIONS = {
    "start_holiday" => { from: %w[ok], to: :in_holiday, label: "Start payment holiday" },
    "end_holiday" => { from: %w[in_holiday], to: :ok, label: "End payment holiday" },
    "flag_at_risk" => { from: %w[ok in_holiday], to: :investment_at_risk, label: "Flag investment at risk" },
    "restore" => { from: %w[investment_at_risk], to: :ok, label: "Restore to performing" },
    "complete" => { from: %w[ok in_holiday investment_at_risk], to: :complete, label: "Complete (run-off)" }
  }.freeze

  def show
    @versions = @contract.contract_versions.includes(:admin_user).recent.limit(20)
    @contract.log_view_by(current_user)
    @distributions = @contract.application.distributions.recent.limit(12)
    @income_paid = @contract.application.distributions.completed_distributions.sum(:amount)
    @failed_distributions = @contract.application.distributions.where(status: :failed).count
    @available_transitions = SERVICING_TRANSITIONS.select { |_k, t| t[:from].include?(@contract.status) }
    set_messages
  end

  def transition
    spec = SERVICING_TRANSITIONS[params[:kind]]

    unless spec && spec[:from].include?(@contract.status)
      redirect_to console_contract_path(@contract), alert: "That transition isn't available from #{@contract.status_display}." and return
    end

    if params[:reason].blank?
      redirect_to console_contract_path(@contract), alert: "A reason is required — it goes in the audit log." and return
    end

    from_status = @contract.status
    @contract.current_admin_user = current_user
    @contract.update!(status: spec[:to])
    AuditLog.log_action(
      user: current_user, action: "contract_#{params[:kind]}", resource: @contract,
      reason: params[:reason],
      notes: "#{from_status} -> #{spec[:to]}"
    )
    redirect_to console_contract_path(@contract), notice: "#{spec[:label]} — recorded."
  end

  def new
    @contract = Contract.new
    @applications = contractless_accepted_applications
  end

  def create
    @contract = Contract.new(contract_params)
    @contract.current_admin_user = current_user

    if @contract.save
      redirect_to console_contract_path(@contract), notice: "Contract created."
    else
      @applications = contractless_accepted_applications
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @contract.errors.add(:application_id, "already has a contract")
    @applications = contractless_accepted_applications
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    @contract.current_admin_user = current_user

    if @contract.update(contract_params.except(:application_id))
      redirect_to console_contract_path(@contract), notice: "Contract updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def create_message
    @message = @contract.contract_messages.build(message_params)
    @message.sender = current_user
    @message.message_type = "admin_to_customer"
    @message.status = "draft"

    respond_to do |format|
      if @message.save
        if params[:send_now].present? && @message.send_message!
          format.html { redirect_to console_contract_path(@contract), notice: "Message sent." }
          format.turbo_stream do
            flash.now[:notice] = "Message sent."
            set_messages
            render :message_sent
          end
        elsif params[:send_now].present?
          format.html { redirect_to console_contract_path(@contract), alert: "Failed to send message." }
          format.turbo_stream do
            flash.now[:alert] = "Failed to send message."
            render :message_error
          end
        else
          format.html { redirect_to console_contract_path(@contract), notice: "Message saved as draft." }
          format.turbo_stream do
            flash.now[:notice] = "Message saved as draft."
            set_messages
            render :message_sent
          end
        end
      else
        format.html { redirect_to console_contract_path(@contract), alert: @message.errors.full_messages.to_sentence }
        format.turbo_stream do
          set_messages(keep_new_message: @message)
          render :message_sent
        end
      end
    end
  end

  def send_message
    @message = @contract.contract_messages.find(params[:message_id])

    if @message.draft? && @message.send_message!
      redirect_to console_contract_path(@contract), notice: "Message sent."
    else
      redirect_to console_contract_path(@contract), alert: "Failed to send message."
    end
  end

  # Destroying a contract deallocates its pool capital (model callback) —
  # reserved for mistakes, hence reason + audit.
  def destroy
    if params[:reason].blank?
      redirect_to console_contract_path(@contract), alert: "A reason is required — it goes in the audit log." and return
    end

    @contract.current_admin_user = current_user
    @contract.destroy
    AuditLog.log_action(user: current_user, action: "contract_deleted", resource: @contract,
                        reason: params[:reason], notes: "Application ##{@contract.application_id}, #{@contract.formatted_allocated_amount} deallocated")
    redirect_to console_contracts_path, notice: "Contract deleted and pool capital deallocated."
  end

  protected

  # Contracts have no region column of their own — they inherit the selected
  # jurisdiction from their application, so filter by the region-scoped app set.
  def base_scope
    app_ids = region_scoped_application_ids
    return scoped_contracts unless app_ids

    scoped_contracts.where(application_id: app_ids)
  end

  # One grouped query for the index's unread-message indicators.
  def unread_message_counts(contracts)
    ContractMessage.customer_messages.unread
                   .where(contract_id: contracts.map(&:id))
                   .group(:contract_id).count
  end
  helper_method :unread_message_counts

  # Custom: numeric terms match contract or application IDs.
  def apply_search(scope)
    term = params[:search].to_s.strip
    return scope if term.blank?

    scope = scope.joins(application: :user)
    like = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    if term.match?(/\A\d+\z/)
      scope.where(
        "contracts.id = :id OR applications.id = :id OR applications.address ILIKE :like OR users.first_name ILIKE :like OR users.last_name ILIKE :like OR users.email ILIKE :like",
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

  def set_contract
    @contract = scoped_contracts.find(params[:id])
  end

  def set_messages(keep_new_message: nil)
    @messages = @contract.message_threads
    @new_message = keep_new_message || @contract.contract_messages.build
    @ai_agents = AiAgent.all
    @suggested_agent = suggested_agent_for(@contract)
  end

  def suggested_agent_for(contract)
    name = case contract.status
    when "awaiting_funding" then "Funding Specialist"
    when "awaiting_investment" then "Investment Advisor"
    when "investment_at_risk" then "Support Specialist"
    else "Customer Success Manager"
    end
    AiAgent.find_by(name: name) || AiAgent.first
  end

  def contractless_accepted_applications
    scoped_applications.where(status: :accepted)
                       .where.not(id: Contract.select(:application_id))
                       .includes(:user).order("users.first_name", "users.last_name")
  end

  def contract_params
    params.require(:contract).permit(:application_id, :status, :start_date, :end_date)
  end

  def message_params
    params.require(:contract_message).permit(:subject, :content, :parent_message_id, :ai_agent_id)
  end
end
