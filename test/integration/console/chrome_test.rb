require "test_helper"

class Console::ChromeTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin_user) }

  test "main content is wrapped in the console_main turbo frame" do
    get console_root_path
    assert_select "turbo-frame#console_main"
    # The page content (Today) lives inside the frame.
    assert_select "turbo-frame#console_main .console-page-title", text: "Today"
  end

  test "the sidebar persists across navigations (turbo-permanent) and drives the content frame" do
    get console_root_path
    assert_select "aside#console-sidebar[data-turbo-permanent]"
    assert_select "nav.console-nav[data-turbo-frame=?]", "console_main"
  end

  test "nav links are registered as console--nav targets and carry icons" do
    get console_root_path
    assert_select "a.console-nav-link[data-console--nav-target=link]", minimum: 5
    assert_select "a.console-nav-link .console-nav-icon"
  end

  test "nav groups are collapsible and the active group is open" do
    get console_contracts_path
    # Operations group (contains Contracts) renders open.
    assert_select "details.console-nav-group[open] summary.console-nav-group-title", text: "Operations"
  end

  test "external footer links break out of the content frame" do
    get console_root_path
    assert_select "a[href='/admin'][data-turbo-frame=_top]"
  end

  test "nav is organised into function groups" do
    get console_root_path
    %w[Operations Marketing Partners Finance Development].each do |group|
      assert_select "summary.console-nav-group-title", text: group
    end
    assert_select "summary.console-nav-group-title", text: "Legal & Compliance"
  end

  test "items land in their function group" do
    get console_root_path
    assert_select "a.console-nav-link[href=?]", console_applications_path, text: /Acquisition/
    assert_select "a.console-nav-link[href=?]", console_funder_pools_path, text: /Funding pools/
    assert_select "a.console-nav-link[href=?]", console_legal_documents_path, text: /Legal documents/
    assert_select "a.console-nav-link[href=?]", console_analytics_path, text: /Business performance/
    assert_select "a.console-nav-link[href=?]", console_ai_agents_path, text: /Agent configuration/
  end
end
