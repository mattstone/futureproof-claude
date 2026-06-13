module BrokerPortal
  class LegalDocumentsController < ApplicationController
    before_action :authenticate_broker!
    before_action :set_broker_jurisdiction
    before_action :set_legal_document, only: [ :show, :accept, :reject ]

    # List all required documents for this broker
    def index
      # Get required documents for broker (agreements, compliance docs)
      @required_documents = LegalDocument
        .where(jurisdiction: @jurisdiction)
        .where("document_type IN (?)", [ "broker_agreement", "terms_and_conditions" ])
        .order(:document_name)

      # Get broker's acceptance status
      @acceptances = current_broker.legal_document_acceptances.index_by(&:legal_document_id)

      @pending_documents = @required_documents.reject { |doc| @acceptances[doc.id]&.accepted? }
    end

    # View a specific document
    def show
      unless @legal_document
        redirect_to broker_portal_legal_documents_path, alert: "Document not found"
        return
      end

      # Check if broker has already accepted this document
      @acceptance = current_broker.legal_document_acceptances.find_by(legal_document_id: @legal_document.id)
    end

    # Accept a document
    def accept
      unless @legal_document
        redirect_to broker_portal_legal_documents_path, alert: "Document not found"
        return
      end

      if current_broker.accept!(@legal_document, "explicit")
        redirect_to broker_portal_legal_documents_path, notice: "#{@legal_document.document_name} accepted"
      else
        redirect_to broker_portal_legal_documents_path, alert: "Unable to accept document"
      end
    end

    # Reject a document (withdraw acceptance)
    def reject
      unless @legal_document
        redirect_to broker_portal_legal_documents_path, alert: "Document not found"
        return
      end

      acceptance = current_broker.legal_document_acceptances.find_by(legal_document_id: @legal_document.id)
      if acceptance&.destroy
        redirect_to broker_portal_legal_documents_path, notice: "#{@legal_document.document_name} acceptance withdrawn"
      else
        redirect_to broker_portal_legal_documents_path, alert: "Unable to withdraw acceptance"
      end
    end

    private

    def set_broker_jurisdiction
      @jurisdiction = current_broker&.jurisdiction || "AU"
    end

    def set_legal_document
      @legal_document = LegalDocument.find_by(id: params[:id])
    end

    def authenticate_broker!
      redirect_to root_path unless current_broker
    end
  end
end
