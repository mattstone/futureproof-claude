class CreateChatSystem < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_agents do |t|
      t.string :name, null: false
      t.string :agent_type, null: false  # onboarding, loan_specialist, legal, support, operations
      t.text :description
      t.text :system_prompt
      t.string :avatar_emoji, default: "🤖"
      t.string :status, default: "active"  # active, inactive, maintenance
      t.jsonb :capabilities, default: {}
      t.jsonb :region_support, default: ["us", "au", "nz", "uk"]
      t.timestamps
    end

    create_table :chat_conversations do |t|
      t.references :user, foreign_key: true
      t.references :chat_agent, foreign_key: true
      t.string :region, default: "us"
      t.string :status, default: "active"  # active, archived, escalated
      t.string :subject
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    create_table :chat_messages do |t|
      t.references :chat_conversation, null: false, foreign_key: true
      t.string :role, null: false  # user, agent, system
      t.text :content, null: false
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :chat_agents, :agent_type
    add_index :chat_agents, :status
    add_index :chat_conversations, :status
    add_index :chat_conversations, :region
    add_index :chat_messages, :role
  end
end
