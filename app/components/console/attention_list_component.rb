# Renders AdminManagementAttentionService::Signal structs — the Today
# work queue. Severity ordering is the service's job; this just displays.
class Console::AttentionListComponent < Console::BaseComponent
  def initialize(signals:, empty_message: "All clear — nothing needs attention.")
    @signals = signals
    @empty_message = empty_message
  end

  attr_reader :signals, :empty_message
end
