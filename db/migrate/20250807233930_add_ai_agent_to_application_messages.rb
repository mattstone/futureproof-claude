class AddAiAgentToApplicationMessages < ActiveRecord::Migration[8.0]
  def change
    add_reference :application_messages, :ai_agent, null: true, foreign_key: true
  end
end
