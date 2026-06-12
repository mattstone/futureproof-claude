require "test_helper"

class Console::BadgeComponentTest < ViewComponent::TestCase
  test "maps statuses to variants through the single shared map" do
    render_inline Console::BadgeComponent.new(status: :approved)
    assert_selector ".console-badge.console-badge-success", text: "Approved"

    render_inline Console::BadgeComponent.new(status: "rejected")
    assert_selector ".console-badge.console-badge-error", text: "Rejected"

    render_inline Console::BadgeComponent.new(status: "submitted")
    assert_selector ".console-badge.console-badge-warning", text: "Submitted"
  end

  test "unknown statuses fall back to neutral rather than breaking" do
    render_inline Console::BadgeComponent.new(status: "some_future_status")
    assert_selector ".console-badge.console-badge-neutral", text: "Some future status"
  end

  test "label can override the humanized status" do
    render_inline Console::BadgeComponent.new(status: "in_progress", label: "Working")
    assert_selector ".console-badge.console-badge-warning", text: "Working"
  end

  test "every status in the map belongs to exactly one variant" do
    all = Console::BadgeComponent::VARIANTS.values.flatten
    assert_equal all.uniq.length, all.length, "duplicate status in BadgeComponent::VARIANTS: #{all.tally.select { |_, c| c > 1 }.keys}"
  end
end
