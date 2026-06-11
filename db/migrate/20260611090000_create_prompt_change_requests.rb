class CreatePromptChangeRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :prompt_change_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :kind, null: false, default: 0
      t.string :target_slot
      t.string :title, null: false
      t.text :description, null: false
      t.string :impact_question, null: false
      t.integer :impact_answer, null: false
      t.text :impact_details
      t.integer :github_number
      t.string :github_type
      t.string :github_url
      t.string :state_cache
      t.datetime :state_checked_at

      t.timestamps
    end

    add_index :prompt_change_requests, :target_slot
    add_index :prompt_change_requests, [ :user_id, :created_at ]
  end
end
