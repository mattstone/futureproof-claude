module LenderPortal
  class LegalDocumentsController < LenderPortal::BaseController
    before_action :set_lender_jurisdiction
    before_action :set_legal_document, only: [ :show, :accept, :reject ]

    # List all required documents for this lender
    def index
      # Get required documents for lender (agreements, compliance docs)
      @required_documents = LegalDocument
        .where(jurisdiction: @jurisdiction)
        .where("document_type IN (?)", [ "lender_agreement", "compliance_agreement" ])
        .order(:document_name)

      # Get lender's acceptance status
      @acceptances = current_user.legal_document_acceptances.index_by(&:legal_document_id)

      @pending_documents = @required_documents.reject { |doc| @acceptances[doc.id]&.accepted? }
    end

    # View a specific document
    def show
      unless @legal_document
        redirect_to lender_portal_legal_documents_path, alert: "Document not found"
        return
      end

      # Check if lender has already accepted this document
      @acceptance = current_user.legal_document_acceptances.find_by(legal_document_id: @legal_document.id)
    end

    # Accept a document
    def accept
      unless @legal_document
        redirect_to lender_portal_legal_documents_path, alert: "Document not found"
        return
      end

      if current_user.accept!(@legal_document, "explicit")
        redirect_to lender_portal_legal_documents_path, notice: "#{@legal_document.document_name} accepted"
      else
        redirect_to lender_portal_legal_documents_path, alert: "Unable to accept document"
      end
    end

    # Reject a document (withdraw acceptance)
    def reject
      unless @legal_document
        redirect_to lender_portal_legal_documents_path, alert: "Document not found"
        return
      end

      acceptance = current_user.legal_document_acceptances.find_by(legal_document_id: @legal_document.id)
      if acceptance&.destroy
        redirect_to lender_portal_legal_documents_path, notice: "#{@legal_document.document_name} acceptance withdrawn"
      else
        redirect_to lender_portal_legal_documents_path, alert: "Unable to withdraw acceptance"
      end
    end

    private

    def set_lender_jurisdiction
      @jurisdiction = "AU"  # Default; can be made dynamic based on lender profile
    end

    def set_legal_document
      @legal_document = LegalDocument.find_by(id: params[:id])
    end
  end
end
