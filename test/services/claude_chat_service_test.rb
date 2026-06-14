require "test_helper"

class ClaudeChatServiceTest < ActiveSupport::TestCase
  ContentBlock = Struct.new(:type, :text, :id, :name, :input, keyword_init: true) do
    def to_h
      { type: type, text: text, id: id, name: name, input: input }.compact
    end
  end

  Usage = Struct.new(
    :input_tokens, :output_tokens,
    :cache_creation_input_tokens, :cache_read_input_tokens,
    keyword_init: true
  )

  FakeResponse = Struct.new(:content, :stop_reason, :usage, keyword_init: true)

  class FakeMessages
    def initialize(responses)
      @responses = responses
      @calls = []
    end

    attr_reader :calls

    def create(**args)
      @calls << args
      raise "ran out of fake responses" if @responses.empty?
      @responses.shift
    end
  end

  class FakeClient
    def initialize(messages_double)
      @messages_double = messages_double
    end

    def messages
      @messages_double
    end
  end

  def text_response(text, usage = nil)
    FakeResponse.new(
      content: [ ContentBlock.new(type: "text", text: text) ],
      stop_reason: "end_turn",
      usage: usage || Usage.new(input_tokens: 10, output_tokens: 5, cache_creation_input_tokens: 0, cache_read_input_tokens: 0)
    )
  end

  def tool_use_response(name, input, id: "toolu_1")
    FakeResponse.new(
      content: [ ContentBlock.new(type: "tool_use", id: id, name: name, input: input) ],
      stop_reason: "tool_use",
      usage: Usage.new(input_tokens: 8, output_tokens: 3, cache_creation_input_tokens: 0, cache_read_input_tokens: 0)
    )
  end

  test "available? reflects ANTHROPIC_API_KEY presence" do
    original = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "sk-test"
    assert ClaudeChatService.available?

    ENV.delete("ANTHROPIC_API_KEY")
    refute ClaudeChatService.available?
  ensure
    ENV["ANTHROPIC_API_KEY"] = original
  end

  test "available? honours the AI_ASSISTANT_DISABLED kill switch" do
    original_key = ENV["ANTHROPIC_API_KEY"]
    original_kill = ENV["AI_ASSISTANT_DISABLED"]
    ENV["ANTHROPIC_API_KEY"] = "sk-test"

    ENV["AI_ASSISTANT_DISABLED"] = "1"
    refute ClaudeChatService.available?, "kill switch should disable live Claude even with a key present"

    ENV["AI_ASSISTANT_DISABLED"] = "false"
    assert ClaudeChatService.available?, "an explicit falsey value keeps it enabled"

    ENV.delete("AI_ASSISTANT_DISABLED")
    assert ClaudeChatService.available?, "default (unset) is enabled"
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_key
    original_kill.nil? ? ENV.delete("AI_ASSISTANT_DISABLED") : (ENV["AI_ASSISTANT_DISABLED"] = original_kill)
  end

  test "raises ConfigurationError when no client and no API key" do
    original = ENV["ANTHROPIC_API_KEY"]
    ENV.delete("ANTHROPIC_API_KEY")
    service = ClaudeChatService.new

    assert_raises(ClaudeChatService::ConfigurationError) do
      service.chat(system: "You are the FutureProof assistant.", messages: [ { role: "user", content: "hi" } ])
    end
  ensure
    ENV["ANTHROPIC_API_KEY"] = original
  end

  test "single-turn text response" do
    fake = FakeMessages.new([ text_response("EPM stands for Equity Preservation Mortgage.") ])
    service = ClaudeChatService.new(client: FakeClient.new(fake))

    result = service.chat(system: "You are the FutureProof assistant.", messages: [ { role: "user", content: "What is EPM?" } ])

    assert_equal "EPM stands for Equity Preservation Mortgage.", result.text
    assert_equal "end_turn", result.stop_reason
    assert_empty result.tool_calls
    assert_equal 10, result.usage[:input_tokens]
    assert_equal 5, result.usage[:output_tokens]
  end

  test "system prompt is wrapped in a cached text block" do
    fake = FakeMessages.new([ text_response("ok") ])
    service = ClaudeChatService.new(client: FakeClient.new(fake))
    service.chat(system: "You are the FutureProof assistant.", messages: [ { role: "user", content: "hi" } ])

    system_arg = fake.calls.first[:system]
    assert_kind_of Array, system_arg
    assert_equal "text", system_arg.first[:type]
    assert_equal({ type: "ephemeral" }, system_arg.first[:cache_control])
  end

  test "passes through pre-built system block array unchanged" do
    pre_built = [ { type: "text", text: "Pre-built", cache_control: { type: "ephemeral" } } ]
    fake = FakeMessages.new([ text_response("ok") ])
    service = ClaudeChatService.new(client: FakeClient.new(fake))

    service.chat(system: pre_built, messages: [ { role: "user", content: "hi" } ])

    assert_equal pre_built, fake.calls.first[:system]
  end

  test "tool-use loop dispatches tools and re-prompts" do
    fake = FakeMessages.new([
      tool_use_response("get_user_region", {}),
      text_response("Your region is AU.")
    ])
    dispatcher = ->(name:, input:) { name == "get_user_region" ? "AU" : "unknown" }
    service = ClaudeChatService.new(client: FakeClient.new(fake))

    result = service.chat(
      system: "You are the FutureProof assistant.",
      messages: [ { role: "user", content: "Where am I?" } ],
      tools: [ { name: "get_user_region", description: "returns region", input_schema: { type: "object" } } ],
      tool_dispatcher: dispatcher
    )

    assert_equal "Your region is AU.", result.text
    assert_equal 1, result.tool_calls.size
    assert_equal "get_user_region", result.tool_calls.first[:name]
    assert_equal "AU", result.tool_calls.first[:result]
  end

  test "tool-use without a dispatcher returns first response and stops" do
    fake = FakeMessages.new([ tool_use_response("get_user_region", {}) ])
    service = ClaudeChatService.new(client: FakeClient.new(fake))

    result = service.chat(
      system: "You are the FutureProof assistant.",
      messages: [ { role: "user", content: "hi" } ],
      tools: [ { name: "get_user_region", description: "returns region", input_schema: { type: "object" } } ]
    )

    assert_equal "tool_use", result.stop_reason
    assert_empty result.tool_calls
  end

  test "tool-use loop caps at MAX_TOOL_ITERATIONS" do
    responses = Array.new(ClaudeChatService::MAX_TOOL_ITERATIONS) { tool_use_response("looping", {}, id: SecureRandom.hex(4)) }
    fake = FakeMessages.new(responses)
    dispatcher = ->(name:, input:) { "noop" }
    service = ClaudeChatService.new(client: FakeClient.new(fake))

    result = service.chat(
      system: "You are the FutureProof assistant.",
      messages: [ { role: "user", content: "go" } ],
      tools: [ { name: "looping", description: "loops forever", input_schema: { type: "object" } } ],
      tool_dispatcher: dispatcher
    )

    assert_equal :max_iterations, result.stop_reason
    assert_equal ClaudeChatService::MAX_TOOL_ITERATIONS, result.tool_calls.size
  end

  test "aggregates token usage across iterations" do
    fake = FakeMessages.new([
      tool_use_response("get_user_region", {}),
      text_response("AU.", Usage.new(input_tokens: 20, output_tokens: 4, cache_creation_input_tokens: 0, cache_read_input_tokens: 100))
    ])
    service = ClaudeChatService.new(client: FakeClient.new(fake))

    result = service.chat(
      system: "You are the FutureProof assistant.",
      messages: [ { role: "user", content: "where" } ],
      tools: [ { name: "get_user_region", description: "returns region", input_schema: { type: "object" } } ],
      tool_dispatcher: ->(name:, input:) { "AU" }
    )

    assert_equal 28, result.usage[:input_tokens]   # 8 + 20
    assert_equal 7, result.usage[:output_tokens]   # 3 + 4
    assert_equal 100, result.usage[:cache_read_input_tokens]
  end
end
