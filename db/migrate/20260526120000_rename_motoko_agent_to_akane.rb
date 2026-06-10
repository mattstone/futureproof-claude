class RenameMotokoAgentToAkane < ActiveRecord::Migration[8.0]
  # Bare AR classes (no app validations) so the migration is insulated from model changes.
  class MigrationAiAgent < ActiveRecord::Base
    self.table_name = "ai_agents"
  end

  class MigrationChatAgent < ActiveRecord::Base
    self.table_name = "chat_agents"
  end

  NEUTRAL_GREETING = "Hi there! I'm the FutureProof assistant, and I'm here to help you get started with your application!".freeze
  NEUTRAL_SIGNATURE = "Looking forward to helping you,\nThe FutureProof team".freeze

  def up
    rename_agent(MigrationAiAgent, "Motoko", "Akane")
    rename_agent(MigrationChatAgent, "Motoko", "Akane")

    akane = MigrationAiAgent.find_by(name: "Akane")
    return unless akane

    akane.update_columns(avatar_filename: "Akane.png") if akane.avatar_filename == "Motoko.png"
    neutralize_greeting(akane)
    fix_handoff_targets(akane)
  end

  def down
    # Names are reversible; the greeting/handoff JSON edits were bug fixes and are left in place.
    rename_agent(MigrationAiAgent, "Akane", "Motoko")
    rename_agent(MigrationChatAgent, "Akane", "Motoko")

    motoko = MigrationAiAgent.find_by(name: "Motoko")
    motoko.update_columns(avatar_filename: "Motoko.png") if motoko && motoko.avatar_filename == "Akane.png"
  end

  private

  # Idempotent + collision-safe: only renames when the source exists and the target name is free.
  def rename_agent(klass, from, to)
    source = klass.find_by(name: from)
    return unless source

    if klass.where(name: to).where.not(id: source.id).exists?
      say "Skipping #{klass.table_name} rename: '#{to}' already exists (left '#{from}' ##{source.id} untouched)"
      return
    end

    source.update_columns(name: to)
    say "Renamed #{klass.table_name} ##{source.id} '#{from}' -> '#{to}'"
  end

  def neutralize_greeting(agent)
    style = agent.communication_style || {}
    return unless style.is_a?(Hash)

    greeting = style["greeting"].to_s
    return unless greeting.include?("Motoko") || greeting.downcase.include?("reverse mortgage")

    style["greeting"] = NEUTRAL_GREETING
    style["signature"] = NEUTRAL_SIGNATURE if style["signature"].to_s.include?("Motoko")
    agent.update_columns(communication_style: style)
    say "Neutralized greeting for ai_agents ##{agent.id}"
  end

  # Fixes the historical "rei" typo in stored handoff targets (lifecycle_stages + handoff_rules).
  def fix_handoff_targets(agent)
    changed = false

    stages = agent.lifecycle_stages
    if stages.is_a?(Array)
      stages.each do |stage|
        next unless stage.is_a?(Hash)

        rules = stage["handoff_rules"]
        if rules.is_a?(Hash) && rules["handoff_to"].to_s.casecmp("rei").zero?
          rules["handoff_to"] = "rie"
          changed = true
        end
      end
      agent.update_columns(lifecycle_stages: stages) if changed
    end

    top = agent.handoff_rules
    if top.is_a?(Hash) && top["handoff_to"].to_s.casecmp("rei").zero?
      top["handoff_to"] = "rie"
      agent.update_columns(handoff_rules: top)
      changed = true
    end

    say "Fixed 'rei' handoff target(s) for ai_agents ##{agent.id}" if changed
  end
end
