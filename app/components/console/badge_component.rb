# THE status badge. One status→variant map for every model in the Console —
# if two pages disagree about what colour "submitted" is, that's a bug here,
# not a style choice there.
class Console::BadgeComponent < Console::BaseComponent
  VARIANTS = {
    success: %w[approved accepted active verified passed completed complete sent merged ok healthy resolved published funded signed],
    warning: %w[submitted processing pending in_progress awaiting_funding on_hold draft review_requested needs_attention awaiting_signature partial],
    error:   %w[rejected failed declined cancelled locked overdue error escalated breached closed_unresolved],
    info:    %w[created new open contacted property_details income_and_loan_options user_details summary in_review],
    neutral: %w[archived inactive closed superseded demo unknown]
  }.freeze

  def self.variant_for(status)
    status = status.to_s
    VARIANTS.each { |variant, statuses| return variant if statuses.include?(status) }
    :neutral
  end

  def initialize(status:, label: nil)
    @status = status.to_s
    @label = label || @status.humanize
  end

  def call
    variant = self.class.variant_for(@status)
    tag.span(@label, class: "console-badge console-badge-#{variant}")
  end
end
