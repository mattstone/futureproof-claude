# GithubBridge — opens GitHub PRs/issues on behalf of admin users.
#
# This is the only write-path from the admin to the prompt files: business
# users propose, git records, the CTO reviews and merges (merge = deploy).
# Nothing here ever pushes to the base branch or merges anything.
#
# Configuration (config/credentials or ENV):
#   github_bridge:
#     token: <fine-grained PAT: contents + pull requests + issues on the repo>
#     repo: mattstone/futureproof-claude
#     base: master
class GithubBridge
  class BridgeError < StandardError; end
  class NotConfiguredError < BridgeError; end

  PROMPT_LABEL = "prompt-change".freeze
  REQUEST_LABEL = "change-request".freeze

  def self.configured?
    new.configured?
  rescue StandardError
    false
  end

  def initialize(client: nil, repo: nil, base: nil)
    @client = client
    @repo = repo || config[:repo] || "mattstone/futureproof-claude"
    @base = base || config[:base] || "master"
  end

  def configured?
    @client.present? || token.present?
  end

  # Creates a branch with the edited prompt file and opens a PR.
  # Returns { number:, url:, type: 'pr' }.
  def propose_prompt_edit(user:, slot:, new_content:, title:, impact:)
    ensure_configured!
    branch = "prompt/#{slot.key}-#{Time.current.strftime('%Y%m%d%H%M%S')}"
    base_sha = client.ref(@repo, "heads/#{@base}").object.sha
    client.create_ref(@repo, "heads/#{branch}", base_sha)

    existing = client.contents(@repo, path: slot.path, ref: branch)
    client.update_contents(
      @repo, slot.path,
      "Prompt edit: #{slot.key} — #{title}",
      existing.sha,
      normalize(new_content),
      branch: branch,
      author: { name: user.full_name.presence || user.email, email: user.email }
    )

    pr = client.create_pull_request(
      @repo, @base, branch,
      "[Prompt] #{title}",
      edit_body(user: user, slot: slot, title: title, impact: impact)
    )
    client.add_labels_to_an_issue(@repo, pr.number, [ PROMPT_LABEL ])

    { number: pr.number, url: pr.html_url, type: "pr" }
  rescue Octokit::Error => e
    raise BridgeError, "GitHub rejected the proposal: #{e.message}"
  end

  # Opens an issue describing a plain-language change request. The trailing
  # @claude block triggers the Claude Code GitHub Action, which implements
  # the request and opens a draft PR for the CTO to review.
  # Returns { number:, url:, type: 'issue' }.
  def propose_change_request(user:, title:, description:, impact:)
    ensure_configured!
    issue = client.create_issue(
      @repo,
      "[Change request] #{title}",
      request_body(user: user, description: description, impact: impact),
      labels: REQUEST_LABEL
    )

    { number: issue.number, url: issue.html_url, type: "issue" }
  rescue Octokit::Error => e
    raise BridgeError, "GitHub rejected the change request: #{e.message}"
  end

  # Returns the current state string for a tracked PR/issue:
  # 'open', 'merged', or 'closed'.
  def fetch_state(github_type:, github_number:)
    ensure_configured!
    if github_type == "pr"
      pr = client.pull_request(@repo, github_number)
      pr.merged ? "merged" : pr.state
    else
      client.issue(@repo, github_number).state
    end
  rescue Octokit::Error => e
    raise BridgeError, "Could not fetch state from GitHub: #{e.message}"
  end

  private

  def ensure_configured!
    return if configured?

    raise NotConfiguredError,
          "GitHub bridge is not configured. Set github_bridge.token in Rails credentials " \
          "or the GITHUB_BRIDGE_TOKEN environment variable."
  end

  def client
    @client ||= Octokit::Client.new(access_token: token, auto_paginate: false)
  end

  def token
    config[:token] || ENV["GITHUB_BRIDGE_TOKEN"]
  end

  def config
    @config ||= Rails.application.credentials.github_bridge.to_h.symbolize_keys
  rescue StandardError
    @config = {}
  end

  def normalize(content)
    content.to_s.gsub("\r\n", "\n").sub(/\n*\z/, "\n")
  end

  def impact_section(impact)
    <<~MD.strip
      ## Impact assessment (answered by the proposer)

      > #{PromptChangeRequest::IMPACT_QUESTION}

      **Answer:** #{impact[:answer].to_s.humanize}
      #{impact[:details].present? ? "\n**Details:** #{impact[:details]}" : ''}
    MD
  end

  def edit_body(user:, slot:, title:, impact:)
    <<~MD
      Proposed by **#{user.full_name.presence || user.email}** (#{user.email}) via the FutureProof admin.

      **Prompt slot:** `#{slot.key}` (`#{slot.path}`)
      **Summary:** #{title}

      #{impact_section(impact)}

      ---
      Review checklist: terminology (no "loan"), advice wall intact, no proprietary-model leakage.
      Merging this PR deploys the change to production.
    MD
  end

  def request_body(user:, description:, impact:)
    <<~MD
      Requested by **#{user.full_name.presence || user.email}** (#{user.email}) via the FutureProof admin.

      ## Request

      #{description}

      #{impact_section(impact)}

      ---
      @claude Please implement this change request. Prompt files live in `docs/prompts/`
      (the runtime support-chat prompt is `docs/prompts/runtime/`). Follow CLAUDE.md,
      run `bundle exec rails test`, and open a **draft** pull request — do not merge.
    MD
  end
end
