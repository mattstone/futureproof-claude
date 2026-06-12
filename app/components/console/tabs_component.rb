class Console::TabsComponent < Console::BaseComponent
  Tab = Struct.new(:label, :id, :block, keyword_init: true)

  # Manual builder — see DataTableComponent#with_column for why not a slot.
  def with_tab(label, id:, &block)
    tabs << Tab.new(label: label, id: id, block: block)
    nil
  end

  def tabs
    @tabs ||= []
  end

  def initialize(active: nil)
    @active = active # tab id; defaults to the first tab
  end

  def active_index
    index = tabs.find_index { |tab| tab.id.to_s == @active.to_s }
    index || 0
  end
end
