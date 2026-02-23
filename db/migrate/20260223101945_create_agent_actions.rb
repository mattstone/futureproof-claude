class CreateAgentActions < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_actions do |t|
      t.references :ai_agent, null: false, foreign_key: true
      t.string :actionable_type
      t.bigint :actionable_id
      t.string :action_type, null: false
      t.string :decision
      t.float :confidence
      t.text :reasoning
      t.jsonb :context, default: {}
      t.jsonb :result, default: {}
      t.string :status, default: "completed"
      t.string :overridden_by
      t.text :override_reason
      t.timestamps
    end

    add_index :agent_actions, [:actionable_type, :actionable_id]
    add_index :agent_actions, :action_type
  end
end
