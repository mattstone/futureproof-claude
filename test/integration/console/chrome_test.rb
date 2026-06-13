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
    # Portfolio group (contains Contracts) renders open.
    assert_select "details.console-nav-group[open] summary.console-nav-group-title", text: "Portfolio"
  end

  test "external footer links break out of the content frame" do
    get console_root_path
    assert_select "a[href='/admin'][data-turbo-frame=_top]"
  end
end
