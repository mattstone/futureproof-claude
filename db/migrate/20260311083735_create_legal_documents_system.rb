class CreateLegalDocumentsSystem < ActiveRecord::Migration[7.1]
  def change
    # Core legal documents table
    create_table :legal_documents do |t|
      t.string :document_type, null: false  # privacy_policy, terms_conditions, customer_contract, lender_contract, wholesale_funder_contract, broker_contract, investment_provider_contract
      t.string :jurisdiction, null: false   # AU, US, NZ, UK
      t.string :party_type, null: false     # customer, lender, broker, wholesale_funder, investment_provider, universal
      t.string :title, null: false
      t.text :content, null: false
      t.string :version, null: false        # e.g., "1.0", "1.1", "2.0"
      t.datetime :effective_from, null: false
      t.datetime :effective_to, null: true
      t.boolean :is_active, default: false, null: false
      t.boolean :is_draft, default: true, null: false
      t.integer :status, default: 0  # draft, review, approved, active, archived
      t.timestamps

      t.index [ :document_type, :jurisdiction, :party_type, :is_active ], name: :idx_legal_docs_lookup
      t.index [ :document_type, :jurisdiction, :party_type, :version ], unique: true, name: :idx_legal_docs_unique
      t.index [ :is_active, :effective_from ], name: :idx_legal_docs_active
    end

    # Track changes and versions
    create_table :legal_document_versions do |t|
      t.references :legal_document, null: false, foreign_key: true
      t.references :admin_user, foreign_key: { to_table: :users }, null: true
      t.string :action  # created, updated, activated, deactivated, archived
      t.text :change_details
      t.text :previous_content, null: true
      t.text :new_content, null: true
      t.timestamps

      t.index [ :legal_document_id, :created_at ], name: :idx_legal_doc_versions
    end

    # Acceptance tracking (when users/lenders accept documents)
    create_table :legal_document_acceptances do |t|
      t.references :legal_document, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :lender, null: true, foreign_key: true
      t.references :application, null: true, foreign_key: true
      t.datetime :accepted_at, null: false
      t.string :acceptance_type  # explicit, implicit, required_for_application
      t.text :notes
      t.timestamps

      t.index [ :legal_document_id, :user_id, :accepted_at ], name: :idx_legal_acceptances_user
      t.index [ :legal_document_id, :lender_id, :accepted_at ], name: :idx_legal_acceptances_lender
    end

    # Document templates for quick generation
    create_table :legal_document_templates do |t|
      t.string :document_type, null: false
      t.string :jurisdiction, null: false
      t.string :party_type, null: false
      t.string :template_name, null: false
      t.text :template_content, null: false
      t.text :instructions  # How to customize for a specific case
      t.integer :sort_order, default: 0
      t.boolean :is_active, default: true
      t.timestamps

      t.index [ :document_type, :jurisdiction, :party_type ], name: :idx_legal_templates_lookup
    end

    # Signature tracking (optional, for future e-signature integration)
    create_table :legal_document_signatures do |t|
      t.references :legal_document_acceptance, null: false, foreign_key: true
      t.string :signer_name, null: false
      t.string :signer_email, null: false
      t.string :signature_method  # electronic, wet_signature, witnessed
      t.string :signature_provider  # docusign, adobe_sign, manual
      t.text :signature_data, null: true
      t.datetime :signed_at, null: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps

      t.index [ :legal_document_acceptance_id, :signed_at ], name: :idx_legal_signatures
    end
  end
end
