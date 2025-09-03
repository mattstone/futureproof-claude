class AddEmailCategoryAndBodyToEmailTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :email_templates, :email_category, :string, null: false, default: 'operational'
    add_column :email_templates, :content_body, :text
    
    # Add index for email category filtering
    add_index :email_templates, :email_category
    
    # Update existing templates to have the operational category
    reversible do |dir|
      dir.up do
        # All current templates are operational
        EmailTemplate.update_all(email_category: 'operational')
        
        # Migrate existing content to content_body, preserving full content in content field for now
        EmailTemplate.find_each do |template|
          template.update_column(:content_body, template.content)
        end
      end
    end
  end
end
