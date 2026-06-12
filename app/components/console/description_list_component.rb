# Label/value pairs for show pages. Accepts a plain hash for simple values
# and/or item slots with blocks for rich values (links, badges).
class Console::DescriptionListComponent < Console::BaseComponent
  Item = Struct.new(:term, :block, keyword_init: true)

  # Manual builder — see DataTableComponent#with_column for why not a slot.
  def with_item(term, &block)
    items << Item.new(term: term, block: block)
    nil
  end

  def items
    @items ||= []
  end

  def initialize(rows: {}, columns: 2)
    @rows = rows
    @columns = columns
  end

  attr_reader :rows, :columns
end
