class CreatePrivacyPolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :privacy_policies do |t|
      t.string :title
      t.text :content
      t.datetime :last_updated
      t.boolean :is_active
      t.integer :version

      t.timestamps
    end
  end
end
