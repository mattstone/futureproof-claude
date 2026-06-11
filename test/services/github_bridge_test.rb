require "test_helper"
require "ostruct"

class GithubBridgeTest < ActiveSupport::TestCase
  # Records every call; returns canned GitHub-shaped responses.
  class FakeClient
    attr_reader :calls

    def initialize
      @calls = []
    end

    def ref(repo, ref)
      @calls << [ :ref, repo, ref ]
      OpenStruct.new(object: OpenStruct.new(sha: "basesha123"))
    end

    def create_ref(repo, ref, sha)
      @calls << [ :create_ref, repo, ref, sha ]
    end

    def contents(repo, path:, ref:)
      @calls << [ :contents, repo, path, ref ]
      OpenStruct.new(sha: "filesha456")
    end

    def update_contents(repo, path, message, file_sha, content, branch:, author:)
      @calls << [ :update_contents, repo, path, message, file_sha, content, branch, author ]
    end

    def create_pull_request(repo, base, head, title, body)
      @calls << [ :create_pull_request, repo, base, head, title, body ]
      OpenStruct.new(number: 77, html_url: "https://github.com/#{repo}/pull/77")
    end

    def add_labels_to_an_issue(repo, number, labels)
      @calls << [ :add_labels_to_an_issue, repo, number, labels ]
    end

    def create_issue(repo, title, body, labels:)
      @calls << [ :create_issue, repo, title, body, labels ]
      OpenStruct.new(number: 88, html_url: "https://github.com/#{repo}/issues/88")
    end

    def pull_request(repo, number)
      @calls << [ :pull_request, repo, number ]
      OpenStruct.new(merged: true, state: "closed")
    end

    def issue(repo, number)
      @calls << [ :issue, repo, number ]
      OpenStruct.new(state: "open")
    end
  end

  def setup
    @user = users(:regular_user)
    @client = FakeClient.new
    @bridge = GithubBridge.new(client: @client, repo: "acme/repo", base: "master")
    @impact = { answer: :affects_functionality, details: "Adjusts escalation behaviour" }
  end

  test "propose_prompt_edit branches, commits as the proposer, opens a labelled PR" do
    slot = PromptFiles.slot(:runtime, "support_chat")

    result = @bridge.propose_prompt_edit(
      user: @user, slot: slot, new_content: "New prompt text",
      title: "Soften escalation wording", impact: @impact
    )

    assert_equal({ number: 77, url: "https://github.com/acme/repo/pull/77", type: "pr" }, result)

    create_ref = @client.calls.find { |c| c[0] == :create_ref }
    assert_match %r{\Aheads/prompt/support_chat-\d{14}\z}, create_ref[2]
    assert_equal "basesha123", create_ref[3]

    update = @client.calls.find { |c| c[0] == :update_contents }
    assert_equal slot.path, update[2]
    assert_equal "filesha456", update[4]
    assert_equal "New prompt text\n", update[5], "content should be newline-normalized"
    assert_equal @user.email, update[7][:email], "commit must be authored as the proposer"

    pr = @client.calls.find { |c| c[0] == :create_pull_request }
    assert_equal "[Prompt] Soften escalation wording", pr[4]
    assert_includes pr[5], @user.email
    assert_includes pr[5], PromptChangeRequest::IMPACT_QUESTION
    assert_includes pr[5], "Affects functionality"
    assert_includes pr[5], "Adjusts escalation behaviour"

    labels = @client.calls.find { |c| c[0] == :add_labels_to_an_issue }
    assert_equal [ 77, [ "prompt-change" ] ], labels[2..3]
  end

  test "propose_change_request opens a labelled issue with the @claude block and impact answers" do
    result = @bridge.propose_change_request(
      user: @user, title: "Stop offering phone callbacks",
      description: "The support agent should direct users to email only.", impact: @impact
    )

    assert_equal({ number: 88, url: "https://github.com/acme/repo/issues/88", type: "issue" }, result)

    issue = @client.calls.find { |c| c[0] == :create_issue }
    assert_equal "[Change request] Stop offering phone callbacks", issue[2]
    assert_includes issue[3], "@claude"
    assert_includes issue[3], "draft"
    assert_includes issue[3], PromptChangeRequest::IMPACT_QUESTION
    assert_equal "change-request", issue[4]
  end

  test "fetch_state distinguishes merged PRs from open issues" do
    assert_equal "merged", @bridge.fetch_state(github_type: "pr", github_number: 77)
    assert_equal "open", @bridge.fetch_state(github_type: "issue", github_number: 88)
  end

  test "raises NotConfiguredError without a token and no injected client" do
    bridge = GithubBridge.new(repo: "acme/repo")
    slot = PromptFiles.slot(:core, "master")

    error = assert_raises(GithubBridge::NotConfiguredError) do
      bridge.propose_prompt_edit(user: @user, slot: slot, new_content: "x", title: "t", impact: @impact)
    end
    assert_match(/not configured/, error.message)
  end
end
