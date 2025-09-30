class AddLifecycleConfigurationToAiAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_agents, :lifecycle_stages, :jsonb, default: []
    add_column :ai_agents, :business_rules, :jsonb, default: {}
    add_column :ai_agents, :communication_style, :jsonb, default: {}
    add_column :ai_agents, :handoff_rules, :jsonb, default: {}
    add_column :ai_agents, :agent_config, :jsonb, default: {}

    # Add indexes for JSONB columns for better query performance
    add_index :ai_agents, :lifecycle_stages, using: :gin
    add_index :ai_agents, :business_rules, using: :gin
    add_index :ai_agents, :agent_config, using: :gin
  end
end
