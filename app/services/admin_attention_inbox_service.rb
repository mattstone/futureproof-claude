class AdminAttentionInboxService
  Item = Struct.new(
    :type, :icon, :title, :subtitle, :detail,
    :resource_type, :resource_id, :action_id, :created_at,
    keyword_init: true
  )

  MAX_ITEMS = 10
  LOW_CONFIDENCE_THRESHOLD = 0.7
  LOW_CONFIDENCE_LIMIT = 5

  def call
    items = flagged_action_items
    items.concat(low_confidence_items(exclude_action_ids: items.map(&:action_id).compact))
    items.concat(unverified_document_items)
    items.sort_by { |i| i.created_at || Time.at(0) }.reverse.first(MAX_ITEMS)
  rescue => e
    Rails.logger.error("AdminAttentionInboxService error: #{e.message}")
    []
  end

  private

  def flagged_action_items
    AgentAction.includes(:ai_agent, :actionable)
               .where(decision: %w[flag reject], status: 'completed')
               .where.not(status: 'overridden')
               .order(created_at: :desc)
               .limit(MAX_ITEMS)
               .filter_map { |action| flag_item(action) }
  end

  def flag_item(action)
    return nil unless action.actionable.present?

    Item.new(
      type: :agent_flag,
      icon: '⚠️',
      title: "Agent Flagged: #{action.actionable.class.name.titleize} ##{action.actionable.id}",
      subtitle: "#{action.ai_agent&.name || 'Agent'} flagged as #{action.decision}. Confidence: #{percent(action.confidence)}",
      detail: action.reasoning.to_s.truncate(120),
      resource_type: action.actionable.class.name,
      resource_id: action.actionable.id,
      action_id: action.id,
      created_at: action.created_at
    )
  end

  def low_confidence_items(exclude_action_ids:)
    AgentAction.includes(:ai_agent, :actionable)
               .where(status: 'completed')
               .where.not(confidence: nil)
               .where('confidence < ?', LOW_CONFIDENCE_THRESHOLD)
               .where.not(id: exclude_action_ids)
               .order(created_at: :desc)
               .limit(LOW_CONFIDENCE_LIMIT)
               .filter_map { |action| low_confidence_item(action) }
  end

  def low_confidence_item(action)
    return nil unless action.actionable.present?

    Item.new(
      type: :low_confidence,
      icon: '🔍',
      title: "Low Confidence: #{action.action_type.humanize} on #{action.actionable.class.name.titleize} ##{action.actionable.id}",
      subtitle: "#{action.ai_agent&.name || 'Agent'} — #{percent(action.confidence)} confidence (#{action.decision || 'no decision'})",
      detail: action.reasoning.to_s.truncate(120),
      resource_type: action.actionable.class.name,
      resource_id: action.actionable.id,
      action_id: action.id,
      created_at: action.created_at
    )
  end

  def unverified_document_items
    ApplicationDocument.includes(:application)
                       .where(status: %w[uploaded pending])
                       .order(created_at: :desc)
                       .group_by(&:application_id)
                       .filter_map { |app_id, docs| document_item(app_id, docs) }
  end

  def document_item(app_id, docs)
    app = docs.first.application
    return nil unless app

    doc_names = docs.map { |d| d.document_type.to_s.humanize }.join(', ')
    Item.new(
      type: :document_review,
      icon: '📄',
      title: "Unverified Documents: #{docs.size} document#{'s' if docs.size != 1} need manual review",
      subtitle: "Application ##{app_id}: #{doc_names.truncate(80)}",
      detail: nil,
      resource_type: 'Application',
      resource_id: app.id,
      action_id: nil,
      created_at: docs.map(&:created_at).max
    )
  end

  def percent(value)
    "#{(value.to_f * 100).round(0)}%"
  end
end
