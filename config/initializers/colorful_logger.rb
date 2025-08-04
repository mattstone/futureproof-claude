if Rails.env.development?
  # Enhanced colorful logger that works with Rails TaggedLogging
  class ColorfulFormatter
    # ANSI color codes
    COLORS = {
      DEBUG: "\e[36m",  # Cyan
      INFO:  "\e[32m",  # Green
      WARN:  "\e[33m",  # Yellow
      ERROR: "\e[31m",  # Red
      FATAL: "\e[35m",  # Magenta
      RESET: "\e[0m"    # Reset
    }.freeze

    EMOJI = {
      DEBUG: "🔍",
      INFO:  "ℹ️ ",
      WARN:  "⚠️ ",
      ERROR: "❌",
      FATAL: "💀"
    }.freeze

    def initialize(original_formatter)
      @original_formatter = original_formatter
    end

    def call(severity, datetime, progname, msg)
      line = @original_formatter.call(severity, datetime, progname, msg)
      colorize_log_line(line, severity)
    end

    # Required methods for TaggedLogging compatibility
    def tagged(*tags)
      @original_formatter.tagged(*tags) if @original_formatter.respond_to?(:tagged)
      yield
    end

    def push_tags(*tags)
      @original_formatter.push_tags(*tags) if @original_formatter.respond_to?(:push_tags)
    end

    def pop_tags(size = 1)
      @original_formatter.pop_tags(size) if @original_formatter.respond_to?(:pop_tags)
    end

    def clear_tags!
      @original_formatter.clear_tags! if @original_formatter.respond_to?(:clear_tags!)
    end

    def current_tags
      @original_formatter.current_tags if @original_formatter.respond_to?(:current_tags)
    end

    private

    def colorize_log_line(line, severity)
      color = COLORS[severity.to_sym] || COLORS[:RESET]
      emoji = EMOJI[severity.to_sym] || ""
      
      "#{color}#{emoji} #{line}#{COLORS[:RESET]}"
    end
  end

  # Apply the colorful formatter after Rails initializes
  Rails.application.configure do
    config.after_initialize do
      if Rails.logger && Rails.logger.formatter
        Rails.logger.formatter = ColorfulFormatter.new(Rails.logger.formatter)
      end
    end
  end
end