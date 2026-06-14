# Headline number with a label; links to a pre-filtered index when href given.
class Console::StatCardComponent < Console::BaseComponent
  def initialize(value:, label:, href: nil, variant: nil, context: nil)
    @value = value
    @label = label
    @href = href
    @variant = variant # :success/:warning/:error tints the value
    @context = context # optional quiet caption under the label
  end

  def call
    parts = [
      tag.span(@value, class: "console-stat-value #{"console-stat-value-#{@variant}" if @variant}".strip),
      tag.span(@label, class: "console-stat-label")
    ]
    parts << tag.span(@context, class: "console-stat-context") if @context.present?
    inner = safe_join(parts)

    if @href
      link_to(inner, @href, class: "console-stat console-stat-link")
    else
      tag.div(inner, class: "console-stat")
    end
  end
end
