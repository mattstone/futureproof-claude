class LegalDocumentService
  # Bulk create documents from templates for a jurisdiction
  def self.setup_jurisdiction(jurisdiction, admin_user)
    templates = LegalDocumentTemplate.for_jurisdiction(jurisdiction).active
    
    results = {
      created: [],
      errors: []
    }
    
    templates.each do |template|
      begin
        doc = LegalDocument.create!(
          document_type: template.document_type,
          jurisdiction: template.jurisdiction,
          party_type: template.party_type,
          title: template.template_name,
          content: template.template_content,
          version: "1.0",
          effective_from: Time.current,
          status: :draft,
          is_draft: true,
          current_admin_user: admin_user
        )
        results[:created] << doc
      rescue => e
        results[:errors] << { template: template.display_name, error: e.message }
      end
    end
    
    results
  end

  # Require user to accept essential documents for application
  def self.require_documents_for_application(application, user)
    jurisdiction = application.jurisdiction
    
    # Essential documents for customer applications
    essential_types = %w[terms_conditions privacy_policy]
    
    docs = LegalDocument.where(
      jurisdiction: jurisdiction,
      document_type: essential_types,
      is_active: true
    ).where(party_type: ["universal", "customer"]).effective
    
    docs.each do |doc|
      unless user.accepted?(doc)
        LegalDocumentAcceptance.create!(
          legal_document: doc,
          user: user,
          application: application,
          accepted_at: Time.current,
          acceptance_type: "required_for_application"
        )
      end
    end
  end

  # Require lender to accept their agreement
  def self.require_documents_for_lender(lender, admin_user)
    jurisdiction = lender.jurisdiction
    
    # Lender-specific documents
    lender_docs = LegalDocument.where(
      jurisdiction: jurisdiction,
      party_type: ["universal", "lender"],
      is_active: true
    ).effective
    
    lender_docs.each do |doc|
      unless lender.accepted?(doc)
        LegalDocumentAcceptance.create!(
          legal_document: doc,
          lender: lender,
          accepted_at: Time.current,
          acceptance_type: "required_for_application"
        )
      end
    end
  end

  # Check if all required documents for an application are accepted
  def self.all_required_documents_accepted?(application)
    jurisdiction = application.jurisdiction
    user = application.user
    
    required = LegalDocument.where(
      jurisdiction: jurisdiction,
      is_active: true
    ).where("party_type IN (?)", ["universal", "customer"])
     .where("document_type IN (?)", %w[terms_conditions privacy_policy])
     .effective
    
    required.all? { |doc| user.accepted?(doc) }
  end

  # Generate acceptance summary for an application
  def self.acceptance_summary(application)
    jurisdiction = application.jurisdiction
    user = application.user
    
    docs = LegalDocument.for_jurisdiction(jurisdiction).effective
    
    summary = {
      jurisdiction: jurisdiction,
      total_documents: docs.count,
      accepted: [],
      pending: [],
      superseded: []
    }
    
    docs.each do |doc|
      acceptance = user.acceptance_of(doc)
      
      if acceptance
        if doc.is_active?
          summary[:accepted] << {
            document: doc.document_type_display,
            version: doc.version,
            accepted_at: acceptance.accepted_at,
            is_current: true
          }
        else
          summary[:superseded] << {
            document: doc.document_type_display,
            version: doc.version,
            accepted_at: acceptance.accepted_at,
            is_current: false
          }
        end
      else
        if doc.is_active? && doc.effective?
          summary[:pending] << {
            document: doc.document_type_display,
            version: doc.version,
            is_required: %w[terms_conditions privacy_policy].include?(doc.document_type)
          }
        end
      end
    end
    
    summary
  end

  # Get documents needing re-acceptance (old versions)
  def self.documents_needing_reacceptance(user, jurisdiction)
    active_docs = LegalDocument.for_jurisdiction(jurisdiction).active.effective
    
    reacceptance_needed = []
    
    active_docs.each do |doc|
      acceptance = user.acceptance_of(doc)
      if acceptance && acceptance.document_version != doc.version
        reacceptance_needed << {
          document: doc.document_type_display,
          old_version: acceptance.document_version,
          new_version: doc.version,
          reason: "Document has been updated"
        }
      end
    end
    
    reacceptance_needed
  end

  # Clone document to another jurisdiction (with modifications)
  def self.clone_to_jurisdiction(source_doc, target_jurisdiction, customizations = {}, admin_user = nil)
    new_doc = source_doc.dup
    new_doc.jurisdiction = target_jurisdiction
    new_doc.content = apply_jurisdiction_customizations(
      new_doc.content,
      source_doc.jurisdiction,
      target_jurisdiction,
      customizations
    )
    new_doc.version = "1.0"
    new_doc.is_draft = true
    new_doc.status = :draft
    new_doc.current_admin_user = admin_user
    
    new_doc.save!
    new_doc
  end

  # Apply jurisdiction-specific changes to content
  def self.apply_jurisdiction_customizations(content, source_jurisdiction, target_jurisdiction, customizations = {})
    modified = content.dup
    
    # Standard replacements per jurisdiction
    jurisdiction_names = {
      "AU" => "Australia",
      "US" => "United States",
      "NZ" => "New Zealand",
      "UK" => "United Kingdom"
    }
    
    source_name = jurisdiction_names[source_jurisdiction]
    target_name = jurisdiction_names[target_jurisdiction]
    
    modified = modified.gsub(source_name, target_name) if source_name && target_name
    
    # Apply custom substitutions
    customizations.each do |key, value|
      modified = modified.gsub("{{#{key}}}", value.to_s)
    end
    
    modified
  end

  # Export document as PDF (requires additional PDF gem)
  def self.export_as_pdf(legal_document)
    # Placeholder for PDF generation
    # Would use Prawn, WickedPDF, or similar
    raise NotImplementedError, "PDF export requires configuration"
  end

  # Get audit trail for a document
  def self.audit_trail(legal_document)
    legal_document.legal_document_versions
      .recent
      .map do |version|
        {
          timestamp: version.created_at,
          action: version.action_display,
          performed_by: version.created_by,
          details: version.change_details,
          change_size: version.new_content&.length.to_i - version.previous_content&.length.to_i
        }
      end
  end

  # Get jurisdiction compliance status
  def self.jurisdiction_compliance_status(jurisdiction)
    required_docs = %w[privacy_policy terms_conditions]
    
    docs = LegalDocument.for_jurisdiction(jurisdiction).active.effective
    
    {
      jurisdiction: jurisdiction,
      total_active: docs.count,
      coverage: {
        privacy_policy: docs.of_type("privacy_policy").exists?,
        terms_conditions: docs.of_type("terms_conditions").exists?,
        customer_contract: docs.of_type("customer_contract").exists?,
        lender_contract: docs.of_type("lender_contract").exists?,
        wholesale_funder_contract: docs.of_type("wholesale_funder_contract").exists?
      },
      compliance_score: calculate_compliance_score(jurisdiction)
    }
  end

  private

  def self.calculate_compliance_score(jurisdiction)
    required_docs = %w[privacy_policy terms_conditions]
    docs = LegalDocument.for_jurisdiction(jurisdiction).active.effective
    
    docs_count = required_docs.select do |doc_type|
      docs.of_type(doc_type).exists?
    end.length
    
    ((docs_count.to_f / required_docs.length) * 100).round(2)
  end
end
