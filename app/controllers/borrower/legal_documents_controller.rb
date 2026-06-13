module Borrower
  class LegalDocumentsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_borrower_access!
    before_action :set_legal_document, only: [ :show, :accept, :reject ]

    # List all required documents for this borrower
    def index
      @jurisdiction = current_user.country_of_residence&.upcase || "AU"

      # Get required documents for borrower
      @required_documents = LegalDocument
        .where(jurisdiction: @jurisdiction)
        .where(document_type: [ "privacy_policy", "terms_and_conditions" ])
        .order(:document_name)

      # Get user's acceptance status
      @acceptances = current_user.legal_document_acceptances.index_by(&:legal_document_id)

      @pending_documents = @required_documents.reject { |doc| @acceptances[doc.id]&.accepted? }
    end

    # View a specific document
    def show
      unless @legal_document
        redirect_to borrower_legal_documents_path, alert: "Document not found"
        return
      end

      # Check if user has already accepted this document
      @acceptance = current_user.legal_document_acceptances.find_by(legal_document_id: @legal_document.id)
    end

    # Accept a document
    def accept
      unless @legal_document
        redirect_to borrower_legal_documents_path, alert: "Document not found"
        return
      end

      if current_user.accept!(@legal_document, "explicit")
        redirect_to borrower_legal_documents_path, notice: "#{@legal_document.document_name} accepted"
      else
        redirect_to borrower_legal_documents_path, alert: "Unable to accept document"
      end
    end

    # Reject a document (withdraw acceptance)
    def reject
      unless @legal_document
        redirect_to borrower_legal_documents_path, alert: "Document not found"
        return
      end

      acceptance = current_user.legal_document_acceptances.find_by(legal_document_id: @legal_document.id)
      if acceptance&.destroy
        redirect_to borrower_legal_documents_path, notice: "#{@legal_document.document_name} acceptance withdrawn"
      else
        redirect_to borrower_legal_documents_path, alert: "Unable to withdraw acceptance"
      end
    end

    private

    def set_legal_document
      @legal_document = LegalDocument.find_by(id: params[:id])
    end

    def require_borrower_access!
      # Borrowers can only see documents for their jurisdiction
      redirect_to root_path unless current_user
    end
  end
end
