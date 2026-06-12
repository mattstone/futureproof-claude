# Audit trail strip — works across every *Version model via their shared
# interface (admin_user, action_description, created_at).
class Console::ChangeHistoryComponent < Console::BaseComponent
  def initialize(versions:, title: "Change history", limit: 20)
    @versions = versions.first(limit)
    @title = title
  end

  attr_reader :versions, :title

  def actor_label(version)
    actor = version.respond_to?(:admin_user) ? version.admin_user : nil
    actor&.email || "System"
  end

  def action_label(version)
    if version.respond_to?(:action_description)
      version.action_description
    elsif version.respond_to?(:action)
      version.action.to_s.humanize.downcase
    else
      "changed"
    end
  end
end
