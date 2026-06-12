require "test_helper"

# Render coverage for the rest of the Console component kit.
class Console::ComponentKitTest < ViewComponent::TestCase
  test "page header renders title, subtitle and actions" do
    render_inline Console::PageHeaderComponent.new(title: "Applications", subtitle: "All active applications") do |header|
      header.with_action { "ACTION-CONTENT" }
    end

    assert_selector ".console-page-title", text: "Applications"
    assert_selector ".console-page-subtitle", text: "All active applications"
    assert_selector ".console-page-actions", text: "ACTION-CONTENT"
  end

  test "card renders title, header action and body" do
    render_inline Console::CardComponent.new(title: "Decision") do |card|
      card.with_header_action { "EDIT-LINK" }
      "BODY-CONTENT"
    end

    assert_selector ".console-card-title", text: "Decision"
    assert_selector ".console-card-header", text: /EDIT-LINK/
    assert_selector ".console-card-body", text: "BODY-CONTENT"
  end

  test "stat card renders as link when href given, div otherwise" do
    render_inline Console::StatCardComponent.new(value: 7, label: "Awaiting decision", href: "/console/applications")
    assert_selector "a.console-stat[href='/console/applications'] .console-stat-value", text: "7"

    render_inline Console::StatCardComponent.new(value: 3, label: "Open tickets", variant: :warning)
    assert_selector "div.console-stat .console-stat-value-warning", text: "3"
  end

  test "description list renders hash rows and slot items" do
    render_inline Console::DescriptionListComponent.new(rows: { "Email" => "a@b.co", "Phone" => nil }) do |dl|
      dl.with_item("Status") { "RICH-VALUE" }
    end

    assert_selector ".console-dl-term", text: "Email"
    assert_selector ".console-dl-value", text: "a@b.co"
    assert_selector ".console-dl-value", text: "—" # nil → em dash, not blank
    assert_selector ".console-dl-value", text: "RICH-VALUE"
  end

  test "flash messages map devise keys to console styles" do
    render_inline Console::FlashMessagesComponent.new(flash: { "notice" => "Saved", "alert" => "Nope" })

    assert_selector ".console-flash-success", text: "Saved"
    assert_selector ".console-flash-error", text: "Nope"
  end

  test "flash messages render nothing when flash is empty" do
    render_inline Console::FlashMessagesComponent.new(flash: {})
    assert_no_selector ".console-flash"
  end

  test "related records render links and hide entirely when empty" do
    render_inline Console::RelatedRecordsComponent.new do |related|
      related.with_item("Contract #12", href: "/console/contracts/12", meta: "active")
    end
    assert_selector "a.console-related-item[href='/console/contracts/12']", text: /Contract #12/
    assert_selector ".console-related-meta", text: "active"

    render_inline Console::RelatedRecordsComponent.new
    assert_no_selector ".console-related"
  end

  test "attention list renders signals with severity and drill-down" do
    signal = AdminManagementAttentionService::Signal.new(
      severity: :critical, category: :support, headline: "4 unanswered messages",
      detail: "Oldest is 3 days old", drill_down_path: "/console", metric: "4"
    )
    render_inline Console::AttentionListComponent.new(signals: [ signal ])

    assert_selector ".console-attention-item.console-attention-critical"
    assert_selector ".console-attention-headline", text: /4 unanswered messages/
    assert_selector ".console-attention-detail", text: "Oldest is 3 days old"
    assert_selector "a.console-attention-link[href='/console']"
  end

  test "attention list renders the all-clear state" do
    render_inline Console::AttentionListComponent.new(signals: [])
    assert_selector ".console-attention-empty"
  end

  test "tabs render bar and panels with only the active one visible" do
    render_inline Console::TabsComponent.new(active: "two") do |tabs|
      tabs.with_tab("First", id: "one") { "PANEL-ONE" }
      tabs.with_tab("Second", id: "two") { "PANEL-TWO" }
    end

    assert_selector ".console-tab", count: 2
    assert_selector ".console-tab.is-active", text: "Second"
    assert_selector "#panel-two.is-active", text: "PANEL-TWO"
    assert_selector "#panel-one[hidden]", visible: :all
  end

  test "change history renders actor, action and time for version records" do
    version = Struct.new(:admin_user, :action_description, :created_at) do
      def respond_to_missing?(*) = false
    end.new(Struct.new(:email).new("cto@futureproof.com"), "changed application status", 2.hours.ago)

    render_inline Console::ChangeHistoryComponent.new(versions: [ version ])

    assert_selector ".console-history-actor", text: "cto@futureproof.com"
    assert_selector ".console-history-action", text: "changed application status"
    assert_selector ".console-history-time"
  end

  test "change history shows empty state" do
    render_inline Console::ChangeHistoryComponent.new(versions: [])
    assert_text "No changes recorded yet."
  end

  test "filter bar renders search, selects and auto-submit wiring" do
    render_inline Console::FilterBarComponent.new(url: "/console/applications", search_value: "smith", clear_url: "/console/applications") do |bar|
      bar.with_select(:status, options: %w[submitted approved], selected: "approved")
    end

    assert_selector "form.console-filter-bar[action='/console/applications'][data-controller='auto-submit']"
    assert_selector "input.console-filter-search[value='smith']"
    assert_selector "select.console-filter-select option[selected]", text: "approved"
    assert_selector "a.console-filter-clear", text: "Clear"
  end
end
