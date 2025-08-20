class CreateLenderClausesSystem < ActiveRecord::Migration[8.0]
  def change
    # Clause positions - defines standard insertion points in contracts (must be first)
    create_table :clause_positions do |t|
      t.string :name, null: false
      t.string :section_identifier, null: false # e.g., 'after_section_3', 'before_signatures'
      t.text :description
      t.integer :display_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true
      t.timestamps

      t.index :section_identifier, unique: true
      t.index :display_order
      t.index :is_active
    end

    # Main lender clauses table
    create_table :lender_clauses do |t|
      t.references :lender, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content, null: false
      t.text :description
      t.integer :version, null: false, default: 1
      t.boolean :is_active, null: false, default: false
      t.boolean :is_draft, null: false, default: true
      t.datetime :last_updated, null: false
      t.references :created_by, null: true, foreign_key: { to_table: :users }
      t.timestamps

      t.index [:lender_id, :title], name: 'index_lender_clauses_on_lender_and_title'
      t.index [:lender_id, :version], unique: true
      t.index [:is_active, :is_draft]
      t.index :last_updated
    end

    # Lender clause version history table
    create_table :lender_clause_versions do |t|
      t.references :lender_clause, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :action, null: false # 'created', 'updated', 'activated', 'published'
      t.text :change_details
      t.text :previous_content
      t.text :new_content
      t.timestamps

      t.index [:lender_clause_id, :created_at]
      t.index :action
    end

    # Contract clause usage tracking - links contracts to specific clause versions
    create_table :contract_clause_usages do |t|
      t.references :mortgage_contract, null: false, foreign_key: true
      t.references :lender_clause, null: false, foreign_key: true
      t.references :clause_position, null: false, foreign_key: true
      t.integer :contract_version_at_usage, null: false # Contract version when clause was added
      t.integer :clause_version_at_usage, null: false # Clause version when added to contract
      t.text :clause_content_snapshot, null: false # Full clause content at time of usage
      t.text :substituted_content # Content after placeholder substitution
      t.boolean :is_active, null: false, default: true
      t.datetime :added_at, null: false
      t.datetime :removed_at, null: true
      t.references :added_by, null: true, foreign_key: { to_table: :users }
      t.references :removed_by, null: true, foreign_key: { to_table: :users }
      t.timestamps

      t.index [:mortgage_contract_id, :is_active]
      t.index [:lender_clause_id, :contract_version_at_usage]
      t.index [:clause_position_id, :is_active]
      t.index :added_at
    end

    # Add default clause positions using SQL to avoid model dependency issues
    reversible do |direction|
      direction.up do
        execute <<~SQL
          INSERT INTO clause_positions (name, section_identifier, description, display_order, is_active, created_at, updated_at) VALUES
          ('After Loan Details', 'after_section_2', 'Insert clauses after the loan agreement details section', 1, true, NOW(), NOW()),
          ('After Equity Preservation', 'after_section_3', 'Insert clauses after the equity preservation features section', 2, true, NOW(), NOW()),
          ('After Repayment Terms', 'after_section_4', 'Insert clauses after the repayment terms section', 3, true, NOW(), NOW()),
          ('After Security and Insurance', 'after_section_5', 'Insert clauses after the security and insurance section', 4, true, NOW(), NOW()),
          ('After Default and Enforcement', 'after_section_6', 'Insert clauses after the default and enforcement section', 5, true, NOW(), NOW()),
          ('Before Signatures', 'before_signatures', 'Insert clauses just before the signature section', 6, true, NOW(), NOW());
        SQL
      end
      
      direction.down do
        execute "DELETE FROM clause_positions WHERE section_identifier IN ('after_section_2', 'after_section_3', 'after_section_4', 'after_section_5', 'after_section_6', 'before_signatures');"
      end
    end
  end
end
