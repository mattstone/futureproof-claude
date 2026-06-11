require "test_helper"

class PromptFilesTest < ActiveSupport::TestCase
  test "registry covers all seventeen slots across four layers" do
    assert_equal 17, PromptFiles.all_slots.size
    assert_equal %i[core agent constituent runtime], PromptFiles::LAYERS
    assert_equal 1, PromptFiles.slots_for(:core).size
    assert_equal 5, PromptFiles.slots_for(:agent).size
    assert_equal 5, PromptFiles.slots_for(:constituent).size
    assert_equal 6, PromptFiles.slots_for(:runtime).size
  end

  test "every registered slot file exists in the repo" do
    PromptFiles.all_slots.each do |slot|
      assert File.exist?(Rails.root.join(slot.path)), "missing prompt file: #{slot.path}"
    end
  end

  test "read returns file content and sha fingerprints it" do
    content = PromptFiles.read(:runtime, "support_chat")

    assert content.present?
    assert_includes content, "HARD RULES"
    assert_equal Digest::SHA256.hexdigest(content)[0, 12], PromptFiles.sha(:runtime, "support_chat")
  end

  test "read returns nil for unknown slots" do
    assert_nil PromptFiles.read(:runtime, "nonexistent")
    assert_nil PromptFiles.sha(:core, "nonexistent")
  end

  test "find_by_key resolves slots without a layer" do
    assert_equal "docs/prompts/master.md", PromptFiles.find_by_key("master").path
    assert_nil PromptFiles.find_by_key("nope")
  end
end
