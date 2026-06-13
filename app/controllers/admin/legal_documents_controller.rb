module Admin
  class LegalDocumentsController < BaseController
    before_action :set_legal_document, only: [ :show, :edit, :update, :activate, :archive, :publish, :approve, :restore ]

    # Permissions
    def authorize!
      authorize_admin_access!
    end

    # List all legal documents, filtered by global jurisdiction switcher and query params
    def index
      # Get jurisdiction from global admin switcher (stored in session)
      current_jurisdiction = session[:admin_jurisdiction] || "Summary"

      @legal_documents = LegalDocument.all

      # Filter by jurisdiction from global switcher
      unless current_jurisdiction == "Summary"
        @legal_documents = @legal_documents.where(jurisdiction: current_jurisdiction)
      end

      # Filter by document type
      @legal_documents = @legal_documents.of_type(params[:document_type]) if params[:document_type].present?

      # Filter by party type
      @legal_documents = @legal_documents.where(party_type: params[:party_type]) if params[:party_type].present?

      # Filter by status
      @legal_documents = @legal_documents.where(status: params[:status]) if params[:status].present?

      # Search by title
      if params[:q].present?
        @legal_documents = @legal_documents.where("title ILIKE ?", "%#{params[:q]}%")
      end

      @legal_documents = @legal_documents.order(document_type: :asc, jurisdiction: :asc, version: :desc)

      # Stats (before pagination, after filters)
      @total_documents = @legal_documents.count
      @active_documents = @legal_documents.where(status: "active").count
      @pending_documents = @legal_documents.where(status: "draft").count
    end

    # View a specific legal document
    def show
      @versions = @legal_document.legal_document_versions.recent
      @acceptances = @legal_document.legal_document_acceptances.recent.limit(10)
      @changes_from_previous = @legal_document.changes_from_previous
    end

    # Edit document content
    def edit
      authorize_admin_access!
    end

    # Update document
    def update
      @legal_document.current_admin_user = current_admin_user

      if @legal_document.update(legal_document_params)
        redirect_to admin_legal_document_path(@legal_document), notice: "Legal document updated successfully"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # Create new document
    def new
      @legal_document = LegalDocument.new
      @jurisdictions = LegalDocument::JURISDICTIONS
      @document_types = LegalDocument::DOCUMENT_TYPES
      @party_types = LegalDocument::PARTY_TYPES
    end

    # Create
    def create
      @legal_document = LegalDocument.new(legal_document_params)
      @legal_document.current_admin_user = current_admin_user
      @legal_document.status = :draft
      @legal_document.is_draft = true

      if @legal_document.save
        redirect_to admin_legal_document_path(@legal_document), notice: "Document created successfully"
      else
        @jurisdictions = LegalDocument::JURISDICTIONS
        @document_types = LegalDocument::DOCUMENT_TYPES
        @party_types = LegalDocument::PARTY_TYPES
        render :new, status: :unprocessable_entity
      end
    end

    # Publish document for review
    def publish
      @legal_document.current_admin_user = current_admin_user

      if @legal_document.publish!
        redirect_to admin_legal_document_path(@legal_document), notice: "Document published for review"
      else
        redirect_to admin_legal_document_path(@legal_document), alert: "Failed to publish document"
      end
    end

    # Approve document
    def approve
      @legal_document.current_admin_user = current_admin_user

      if @legal_document.approve!
        redirect_to admin_legal_document_path(@legal_document), notice: "Document approved"
      else
        redirect_to admin_legal_document_path(@legal_document), alert: "Failed to approve document"
      end
    end

    # Activate document (make it the active version)
    def activate
      @legal_document.current_admin_user = current_admin_user

      if @legal_document.activate!
        redirect_to admin_legal_documents_path, notice: "Document activated and is now in effect"
      else
        redirect_to admin_legal_document_path(@legal_document), alert: "Failed to activate document"
      end
    end

    # Archive document
    def archive
      @legal_document.current_admin_user = current_admin_user

      if @legal_document.archive!
        redirect_to admin_legal_documents_path, notice: "Document archived"
      else
        redirect_to admin_legal_document_path(@legal_document), alert: "Failed to archive document"
      end
    end

    # Restore archived document to draft
    def restore
      @legal_document.current_admin_user = current_admin_user
      @legal_document.update!(status: :draft, is_draft: true)
      redirect_to admin_legal_document_path(@legal_document), notice: "Document restored to draft"
    end

    # Show compliance status across jurisdictions
    def compliance_dashboard
      @jurisdictions = LegalDocument::JURISDICTIONS
      @compliance_status = {}

      @jurisdictions.each do |jurisdiction|
        @compliance_status[jurisdiction] = LegalDocumentService.jurisdiction_compliance_status(jurisdiction)
      end
    end

    # Templates management
    def templates
      @templates = LegalDocumentTemplate.all
      @templates = @templates.for_jurisdiction(params[:jurisdiction]) if params[:jurisdiction].present?
      @templates = @templates.for_type(params[:document_type]) if params[:document_type].present?
      @templates = @templates.ordered

      @jurisdictions = LegalDocument::JURISDICTIONS
      @document_types = LegalDocument::DOCUMENT_TYPES
    end

    # Setup jurisdiction from templates
    def setup_jurisdiction
      jurisdiction = params[:jurisdiction]

      unless LegalDocument::JURISDICTIONS.include?(jurisdiction)
        redirect_to admin_legal_documents_compliance_dashboard_path, alert: "Invalid jurisdiction"
        return
      end

      results = LegalDocumentService.setup_jurisdiction(jurisdiction, current_admin_user)

      message = "Created #{results[:created].count} documents. "
      message += "Errors: #{results[:errors].count}" if results[:errors].any?

      redirect_to admin_legal_documents_path(jurisdiction: jurisdiction), notice: message
    end

    # Export compliance report
    def export_compliance_report
      @jurisdictions = LegalDocument::JURISDICTIONS
      @compliance_report = {}

      @jurisdictions.each do |jurisdiction|
        @compliance_report[jurisdiction] = LegalDocumentService.jurisdiction_compliance_status(jurisdiction)
      end

      respond_to do |format|
        format.html
        format.csv do
          send_data generate_compliance_csv, filename: "compliance_report_#{Date.today}.csv"
        end
        format.json do
          render json: @compliance_report
        end
      end
    end

    # Acceptance tracking
    def acceptance_tracking
      @document_type = params[:document_type] || "terms_conditions"
      @jurisdiction = params[:jurisdiction] || "AU"

      @document = LegalDocument.where(
        document_type: @document_type,
        jurisdiction: @jurisdiction,
        is_active: true
      ).first

      if @document
        @acceptances = @document.legal_document_acceptances.recent
        @acceptance_rate = calculate_acceptance_rate(@document)
      else
        redirect_to admin_legal_documents_path, alert: "Document not found"
      end
    end

    private

    def set_legal_document
      @legal_document = LegalDocument.find(params[:id])
    end

    def legal_document_params
      params.require(:legal_document).permit(
        :document_type,
        :jurisdiction,
        :party_type,
        :title,
        :content,
        :rich_content,
        :effective_from,
        :effective_to,
        :is_active,
        :is_draft,
        :status
      )
    end

    def generate_compliance_csv
      CSV.generate do |csv|
        csv << [ "Jurisdiction", "Total Active Documents", "Privacy Policy", "Terms & Conditions", "Customer Contract", "Lender Contract", "Compliance Score" ]

        @compliance_report.each do |jurisdiction, report|
          csv << [
            jurisdiction,
            report[:total_active],
            report[:coverage][:privacy_policy] ? "✓" : "✗",
            report[:coverage][:terms_conditions] ? "✓" : "✗",
            report[:coverage][:customer_contract] ? "✓" : "✗",
            report[:coverage][:lender_contract] ? "✓" : "✗",
            "#{report[:compliance_score]}%"
          ]
        end
      end
    end

    def calculate_acceptance_rate(document)
      total_applications = Application.where(jurisdiction: document.jurisdiction).count
      accepted = document.legal_document_acceptances.where("acceptance_type IN (?)", [ "explicit", "required_for_application" ]).count

      return 0 if total_applications.zero?
      ((accepted.to_f / total_applications) * 100).round(2)
    end
  end
end
