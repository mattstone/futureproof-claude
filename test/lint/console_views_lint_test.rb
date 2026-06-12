require "test_helper"

# CI-gating twin of `rails console:lint` — same checker, so a violation
# fails the required test job, not just a rake task someone forgot to run.
class ConsoleViewsLintTest < ActiveSupport::TestCase
  test "console views follow the structural rules" do
    offenses = Console::ViewLinter.offenses
    assert_empty offenses, "console:lint offences:\n#{offenses.join("\n")}"
  end
end
