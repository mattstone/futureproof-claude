class AddVersionToTermsOfUses < ActiveRecord::Migration[8.0]
  def change
    add_column :terms_of_uses, :version, :integer, default: 1, null: false
    add_index :terms_of_uses, :version
    
    # Set version for existing records
    reversible do |dir|
      dir.up do
        TermsOfUse.reset_column_information
        TermsOfUse.find_each.with_index(1) do |terms, index|
          terms.update_column(:version, index)
        end
      end
    end
  end
end
