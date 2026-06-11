require "test_helper"

class PromptChangeRequestTest < ActiveSupport::TestCase
  def setup
    @user = users(:regular_user)
  end

  def valid_attrs(overrides = {})
    {
      user: @user,
      kind: :direct_edit,
      target_slot: "support_chat",
      title: "Soften the escalation wording",
      description: "New prompt content here",
      impact_answer: :wording_only
    }.merge(overrides)
  end

  test "valid direct edit persists and records the impact question verbatim" do
    pcr = PromptChangeRequest.create!(valid_attrs)

    assert_equal PromptChangeRequest::IMPACT_QUESTION, pcr.impact_question
    assert pcr.impact_wording_only?
  end

  test "impact details required unless wording only" do
    pcr = PromptChangeRequest.new(valid_attrs(impact_answer: :affects_functionality))
    assert_not pcr.valid?
    assert pcr.errors[:impact_details].any?

    pcr.impact_details = "Changes which tools the agent may call"
    assert pcr.valid?
  end

  test "direct edits require a registered target slot" do
    assert_not PromptChangeRequest.new(valid_attrs(target_slot: nil)).valid?
    assert_not PromptChangeRequest.new(valid_attrs(target_slot: "bogus")).valid?
  end

  test "change requests do not require a slot" do
    pcr = PromptChangeRequest.new(valid_attrs(kind: :change_request, target_slot: nil,
                                              description: "The agent should stop offering callbacks"))
    assert pcr.valid?
  end

  test "record is immutable after create except github linkage and state" do
    pcr = PromptChangeRequest.create!(valid_attrs)

    pcr.update_github_ref!(number: 99, type: "pr", url: "https://github.com/x/y/pull/99")
    pcr.update_state!("merged")
    assert_equal "merged", pcr.reload.state_cache

    pcr.title = "rewritten history"
    assert_not pcr.valid?
    assert pcr.errors[:title].any?

    pcr.reload
    pcr.impact_answer = :affects_data
    assert_not pcr.valid?
  end
end
