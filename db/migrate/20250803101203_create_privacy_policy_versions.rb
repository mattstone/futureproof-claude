class CreatePrivacyPolicyVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :privacy_policy_versions do |t|
      t.references :privacy_policy, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.text :change_details
      t.text :previous_content
      t.text :new_content

      t.timestamps
    end
  end
end
