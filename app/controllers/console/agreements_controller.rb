# Partner agreements: generated from legal-document templates, edited as
# drafts, sent for signing, signatures recorded with full audit metadata.
class Console::AgreementsController < Console::BaseController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_agreement, only: [ :show, :edit, :update, :send_for_signing, :sign, :record_signature, :cancel, :renew ]

  def index
    @agreements = Agreement.includes(:agreeable, :agreement_signatures, :legal_document).recent

    @agreements = scope_by_jurisdiction(@agreements, :jurisdiction)
    @agreements = @agreements.where(agreeable_type: params[:party_type]) if params[:party_type].present?
    @agreements = @agreements.where(status: params[:status]) if params[:status].present?
    if params[:search].present?
      @agreements = @agreements.where("title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%")
    end

    @total = @agreements.count
    @pending = @agreements.pending_signature.count
    @executed = @agreements.where(status: :fully_executed).count
    @expiring = @agreements.where(status: :fully_executed).where(expires_at: ..60.days.from_now).count
    @records = @agreements.page(params[:page]).per(25)
  end

  def show
  end

  def new
    @agreement = Agreement.new
    @party_type = params[:party_type] || "Lender"
    @preselected_party_id = params[:agreeable_id]
    @parties = load_parties(@party_type)
    @templates = load_templates(@party_type)
  end

  def create
    party = find_party(params[:agreement][:agreeable_type], params[:agreement][:agreeable_id])
    template = LegalDocument.find(params[:agreement][:legal_document_id])

    @agreement = Agreement.generate_from_template(
      legal_document: template,
      agreeable: party,
      created_by: current_user,
      customizations: (params[:customizations] || {}).to_unsafe_h
    )

    if @agreement.save
      redirect_to console_agreement_path(@agreement), notice: "Agreement created — edit and customise it before sending."
    else
      @party_type = params[:agreement][:agreeable_type] || "Lender"
      @parties = load_parties(@party_type)
      @templates = load_templates(@party_type)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    unless @agreement.editable?
      redirect_to console_agreement_path(@agreement), alert: "Only draft agreements can be edited."
    end
  end

  def update
    unless @agreement.editable?
      redirect_to console_agreement_path(@agreement), alert: "Only draft agreements can be edited."
      return
    end

    if @agreement.update(agreement_params)
      redirect_to console_agreement_path(@agreement), notice: "Agreement updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def send_for_signing
    @agreement.send_for_signing!
    redirect_to console_agreement_path(@agreement), notice: "Agreement sent for signing."
  rescue => e
    redirect_to console_agreement_path(@agreement), alert: e.message
  end

  def sign
    @signer_role = params[:role] || "counterparty"
    if @agreement.signed_by?(@signer_role)
      redirect_to console_agreement_path(@agreement), alert: "#{@signer_role.titleize} has already signed."
    end
  end

  def record_signature
    sig_params = params.require(:signature).permit(:signer_name, :signer_email, :signer_title, :typed_signature, :signer_role)

    @agreement.record_signature!(
      role: sig_params[:signer_role],
      signer_name: sig_params[:signer_name],
      signer_email: sig_params[:signer_email],
      signer_title: sig_params[:signer_title],
      typed_signature: sig_params[:typed_signature],
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    if @agreement.status_fully_executed?
      redirect_to console_agreement_path(@agreement), notice: "Agreement fully executed — both parties have signed."
    else
      redirect_to console_agreement_path(@agreement), notice: "Signature recorded."
    end
  rescue => e
    redirect_to sign_console_agreement_path(@agreement, role: params.dig(:signature, :signer_role)), alert: e.message
  end

  def cancel
    @agreement.cancel!
    redirect_to console_agreements_path, notice: "Agreement cancelled."
  rescue => e
    redirect_to console_agreement_path(@agreement), alert: e.message
  end

  # New draft from the same template + party, at the template's current
  # version — the path for an executed agreement coming up for expiry.
  def renew
    renewal = @agreement.renew!(created_by: current_user)
    AuditLog.log_action(user: current_user, action: "agreement_renewed", resource: @agreement,
                        reason: "Renewal draft ##{renewal.id} created")
    redirect_to console_agreement_path(renewal), notice: "Renewal draft created from the current template — review and send."
  rescue => e
    redirect_to console_agreement_path(@agreement), alert: e.message
  end

  private

  def set_agreement
    @agreement = Agreement.find(params[:id])
  end

  def agreement_params
    params.require(:agreement).permit(:title, :content, :rich_content, :notes, :expires_at)
  end

  def load_parties(party_type)
    case party_type
    when "WholesaleFunder" then WholesaleFunder.order(:name)
    when "Broker" then Broker.order(:name)
    else Lender.order(:name)
    end
  end

  def load_templates(party_type)
    doc_type = case party_type
    when "WholesaleFunder" then "wholesale_funder_contract"
    when "Broker" then "broker_contract"
    else "lender_contract"
    end
    LegalDocument.where(document_type: doc_type, is_active: true).order(:jurisdiction)
  end

  def find_party(type, id)
    case type
    when "Lender" then Lender.find(id)
    when "WholesaleFunder" then WholesaleFunder.find(id)
    when "Broker" then Broker.find(id)
    else raise "Unknown party type: #{type}"
    end
  end
end
