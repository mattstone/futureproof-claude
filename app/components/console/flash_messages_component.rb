class Console::FlashMessagesComponent < Console::BaseComponent
  STYLE = { "notice" => "success", "alert" => "error" }.freeze

  def initialize(flash:)
    @flash = flash
  end

  def call
    messages = @flash.select { |_type, message| message.present? && message.is_a?(String) }
    return if messages.empty?

    safe_join(messages.map do |type, message|
      tag.div(message, class: "console-flash console-flash-#{STYLE.fetch(type, type)}", role: "status")
    end)
  end
end
