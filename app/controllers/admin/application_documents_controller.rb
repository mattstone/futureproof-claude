class Admin::ApplicationDocumentsController < Admin::BaseController
  before_action :set_application
  before_action :set_document, only: [ :destroy, :verify, :reject, :auto_verify ]

  def index
    @documents = @application.application_documents.order(:document_type)
  end

  def create
    @document = @application.application_documents.build(document_params)
    @document.uploaded_at = Time.current if params[:application_document][:file].present?
    @document.status = :uploaded if params[:application_document][:file].present?

    if @document.save
      redirect_to admin_application_path(@application), notice: "Document uploaded successfully."
    else
      redirect_to admin_application_path(@application), alert: "Failed to upload document: #{@document.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    @document.destroy
    redirect_to admin_application_path(@application), notice: "Document removed."
  end

  def verify
    @document.verify!(agent_name: current_user.display_name, notes: params[:notes])
    redirect_to admin_application_path(@application), notice: "Document verified."
  rescue => e
    redirect_to admin_application_path(@application), alert: "Failed to verify: #{e.message}"
  end

  def reject
    @document.reject!(agent_name: current_user.display_name, reason: params[:reason] || "No reason provided")
    redirect_to admin_application_path(@application), notice: "Document rejected."
  rescue => e
    redirect_to admin_application_path(@application), alert: "Failed to reject: #{e.message}"
  end

  def auto_verify
    result = MockDocumentVerificationService.verify_document(@document)

    case result[:status]
    when "verified"
      @document.verify!(agent_name: "AI Verification", notes: result[:notes])
      redirect_to admin_application_path(@application), notice: "Document auto-verified (confidence: #{(result[:confidence] * 100).round}%)."
    when "rejected"
      @document.reject!(agent_name: "AI Verification", reason: result[:notes])
      redirect_to admin_application_path(@application), alert: "Document auto-rejected: #{result[:notes]}"
    else
      redirect_to admin_application_path(@application), notice: "Document requires manual review (confidence: #{(result[:confidence] * 100).round}%)."
    end
  end

  def request_all
    @application.create_document_requests!
    redirect_to admin_application_path(@application), notice: "Document requests created for all required types."
  end

  private

  def set_application
    @application = Application.find(params[:application_id])
  end

  def set_document
    @document = @application.application_documents.find(params[:id])
  end

  def document_params
    params.require(:application_document).permit(:document_type, :name, :notes, :file)
  end
end
