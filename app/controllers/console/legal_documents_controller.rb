# The consolidated legal-document register: versioned, jurisdictional,
# with a draft→review→approved→active→archived lifecycle, compliance
# dashboard and acceptance tracking.
class Console::LegalDocumentsController < Console::BaseController
  before_action -> { require_capability(:manage_product) }
  before_action :set_legal_document, only: [ :show, :edit, :update, :publish, :approve, :activate, :archive, :restore ]

  def index
    @legal_documents = LegalDocument.all
    @legal_documents = @legal_documents.where(jurisdiction: current_jurisdiction) unless current_jurisdiction == "Summary"
    @legal_documents = @legal_documents.of_type(params[:document_type]) if params[:document_type].present?
    @legal_documents = @legal_documents.where(party_type: params[:party_type]) if params[:party_type].present?
    @legal_documents = @legal_documents.where(status: params[:status]) if params[:status].present?
    if params[:search].present?
      @legal_documents = @legal_documents.where("title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%")
    end
    @legal_documents = @legal_documents.order(document_type: :asc, jurisdiction: :asc, version: :desc)

    @total_documents = @legal_documents.count
    @active_documents = @legal_documents.where(status: "active").count
    @draft_documents = @legal_documents.where(status: "draft").count

    @records = @legal_documents.page(params[:page]).per(25)
  end

  def show
    @versions = @legal_document.legal_document_versions.recent
    @acceptances = @legal_document.legal_document_acceptances.recent.limit(10)
  end

  def new
    @legal_document = LegalDocument.new(jurisdiction: current_jurisdiction == "Summary" ? "AU" : current_jurisdiction)
  end

  def create
    @legal_document = LegalDocument.new(legal_document_params)
    @legal_document.current_admin_user = current_user
    @legal_document.status = :draft
    @legal_document.is_draft = true

    if @legal_document.save
      redirect_to console_legal_document_path(@legal_document), notice: "Document created as draft."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @legal_document.current_admin_user = current_user

    if @legal_document.update(legal_document_params)
      redirect_to console_legal_document_path(@legal_document), notice: "Document updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def publish
    @legal_document.current_admin_user = current_user
    lifecycle(:publish!, "Document published for review")
  end

  def approve
    @legal_document.current_admin_user = current_user
    lifecycle(:approve!, "Document approved")
  end

  def activate
    @legal_document.current_admin_user = current_user
    lifecycle(:activate!, "Document activated — it is now in effect")
  end

  def archive
    @legal_document.current_admin_user = current_user
    lifecycle(:archive!, "Document archived")
  end

  def restore
    @legal_document.current_admin_user = current_user
    @legal_document.update!(status: :draft, is_draft: true)
    redirect_to console_legal_document_path(@legal_document), notice: "Document restored to draft."
  end

  def compliance_dashboard
    @jurisdictions = LegalDocument::JURISDICTIONS
    @compliance_status = @jurisdictions.index_with do |jurisdiction|
      LegalDocumentService.jurisdiction_compliance_status(jurisdiction)
    end

    respond_to do |format|
      format.html
      format.csv { send_data compliance_csv, filename: "compliance_report_#{Date.today}.csv" }
    end
  end

  def acceptance_tracking
    @document_type = params[:document_type] || "terms_of_use"
    @jurisdiction = params[:jurisdiction] || "AU"

    @document = LegalDocument.find_by(document_type: @document_type, jurisdiction: @jurisdiction, is_active: true)

    if @document
      @acceptances = @document.legal_document_acceptances.includes(:user).recent.limit(100)
      @acceptance_count = @document.legal_document_acceptances.count
    else
      redirect_to console_legal_documents_path, alert: "No active #{@document_type.humanize} for #{@jurisdiction}."
    end
  end

  private

  def lifecycle(action, success_message)
    if @legal_document.public_send(action)
      redirect_to console_legal_document_path(@legal_document), notice: success_message
    else
      redirect_to console_legal_document_path(@legal_document), alert: "Action failed: #{@legal_document.errors.full_messages.to_sentence}"
    end
  end

  def set_legal_document
    @legal_document = LegalDocument.find(params[:id])
  end

  def legal_document_params
    params.require(:legal_document).permit(
      :document_type, :jurisdiction, :party_type, :title, :content,
      :rich_content, :effective_from, :effective_to
    )
  end

  def compliance_csv
    CSV.generate do |csv|
      csv << [ "Jurisdiction", "Total Active Documents", "Privacy Policy", "Terms & Conditions", "Customer Contract", "Lender Contract", "Compliance Score" ]
      @compliance_status.each do |jurisdiction, report|
        csv << [
          jurisdiction,
          report[:total_active],
          report[:coverage][:privacy_policy] ? "yes" : "no",
          report[:coverage][:terms_conditions] ? "yes" : "no",
          report[:coverage][:customer_contract] ? "yes" : "no",
          report[:coverage][:lender_contract] ? "yes" : "no",
          "#{report[:compliance_score]}%"
        ]
      end
    end
  end
end
