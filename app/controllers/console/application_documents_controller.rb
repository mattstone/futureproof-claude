class Console::ApplicationDocumentsController < Console::BaseController
  before_action -> { require_capability(:view_pipeline) }
  before_action :set_application
  before_action :set_document, only: [ :verify, :reject, :auto_verify ]

  def verify
    @document.verify!(agent_name: current_user.display_name, notes: params[:notes])
    redirect_to console_application_path(@application), notice: "Document verified."
  rescue => e
    redirect_to console_application_path(@application), alert: "Failed to verify: #{e.message}"
  end

  def reject
    @document.reject!(agent_name: current_user.display_name, reason: params[:reason].presence || "Does not meet requirements")
    redirect_to console_application_path(@application), notice: "Document rejected."
  rescue => e
    redirect_to console_application_path(@application), alert: "Failed to reject: #{e.message}"
  end

  def auto_verify
    result = MockDocumentVerificationService.verify_document(@document)

    case result[:status]
    when "verified"
      @document.verify!(agent_name: "AI Verification", notes: result[:notes])
      redirect_to console_application_path(@application), notice: "Document auto-verified (confidence: #{(result[:confidence] * 100).round}%)."
    when "rejected"
      @document.reject!(agent_name: "AI Verification", reason: result[:notes])
      redirect_to console_application_path(@application), alert: "Document auto-rejected: #{result[:notes]}"
    else
      redirect_to console_application_path(@application), notice: "Document requires manual review (confidence: #{(result[:confidence] * 100).round}%)."
    end
  end

  def request_all
    @application.create_document_requests!
    redirect_to console_application_path(@application), notice: "Document requests created for all required types."
  end

  private

  def set_application
    @application = scoped_applications.find(params[:application_id])
  end

  def set_document
    @document = @application.application_documents.find(params[:id])
  end
end
