class CreateAiAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_agents do |t|
      t.string :name, null: false
      t.string :agent_type, null: false
      t.text :description
      t.string :avatar_filename, null: false
      t.boolean :is_active, default: true
      t.string :role_title
      t.text :specialties
      t.string :greeting_style

      t.timestamps
    end
    
    add_index :ai_agents, :agent_type
    add_index :ai_agents, :is_active
  end
end
