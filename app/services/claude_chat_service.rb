class ClaudeChatService
  MODEL = "claude-sonnet-4-6"
  MAX_TOKENS = 1024
  MAX_TOOL_ITERATIONS = 3

  Result = Struct.new(:text, :tool_calls, :usage, :stop_reason, keyword_init: true)

  class ConfigurationError < StandardError; end

  def self.available?
    ENV["ANTHROPIC_API_KEY"].present?
  end

  def initialize(client: nil)
    @client = client || build_client
  end

  def chat(system:, messages:, tools: nil, tool_dispatcher: nil)
    raise ConfigurationError, "ANTHROPIC_API_KEY not configured" unless @client

    conversation = messages.dup
    aggregate_usage = empty_usage
    executed_tool_calls = []

    MAX_TOOL_ITERATIONS.times do |iteration|
      response = @client.messages.create(
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: build_system_blocks(system),
        messages: conversation,
        **(tools.present? ? { tools: tools } : {})
      )

      merge_usage!(aggregate_usage, response.usage)
      stop_reason = response.stop_reason

      if stop_reason.to_s != "tool_use" || tool_dispatcher.nil?
        return Result.new(
          text: extract_text(response),
          tool_calls: executed_tool_calls,
          usage: aggregate_usage,
          stop_reason: stop_reason
        )
      end

      tool_uses = extract_tool_uses(response)
      break if tool_uses.empty?

      conversation << { role: "assistant", content: assistant_content_for(response) }
      tool_results = tool_uses.map do |tool_use|
        result = tool_dispatcher.call(name: tool_use[:name], input: tool_use[:input])
        executed_tool_calls << tool_use.merge(result: result, iteration: iteration + 1)
        {
          type: "tool_result",
          tool_use_id: tool_use[:id],
          content: result.to_s
        }
      end
      conversation << { role: "user", content: tool_results }
    end

    Result.new(
      text: "(Stopped — reached tool-iteration cap)",
      tool_calls: executed_tool_calls,
      usage: aggregate_usage,
      stop_reason: :max_iterations
    )
  end

  private

  def build_client
    return nil unless self.class.available?
    Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])
  end

  def build_system_blocks(system)
    return system if system.is_a?(Array)

    [
      {
        type: "text",
        text: system.to_s,
        cache_control: { type: "ephemeral" }
      }
    ]
  end

  def extract_text(response)
    response.content
            .select { |block| block.respond_to?(:type) && block.type.to_s == "text" }
            .map { |block| block.respond_to?(:text) ? block.text : "" }
            .join("\n\n")
            .strip
  end

  def extract_tool_uses(response)
    response.content
            .select { |block| block.respond_to?(:type) && block.type.to_s == "tool_use" }
            .map { |block| { id: block.id, name: block.name, input: block.input.to_h } }
  end

  def assistant_content_for(response)
    response.content.map do |block|
      if block.respond_to?(:to_h)
        block.to_h
      else
        block
      end
    end
  end

  def empty_usage
    {
      input_tokens: 0,
      output_tokens: 0,
      cache_creation_input_tokens: 0,
      cache_read_input_tokens: 0
    }
  end

  def merge_usage!(aggregate, usage)
    return unless usage

    aggregate[:input_tokens] += usage.input_tokens.to_i
    aggregate[:output_tokens] += usage.output_tokens.to_i
    aggregate[:cache_creation_input_tokens] += usage.cache_creation_input_tokens.to_i if usage.respond_to?(:cache_creation_input_tokens)
    aggregate[:cache_read_input_tokens] += usage.cache_read_input_tokens.to_i if usage.respond_to?(:cache_read_input_tokens)
  end
end
