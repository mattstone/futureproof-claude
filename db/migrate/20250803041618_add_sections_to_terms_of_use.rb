class AddSectionsToTermsOfUse < ActiveRecord::Migration[8.0]
  def change
    add_column :terms_of_uses, :sections, :text
  end
end
