# Horizontal strip of links to associated records, shown on show pages so
# nobody dead-ends (the "related records" lesson from the old admin).
class Console::RelatedRecordsComponent < Console::BaseComponent
  Item = Struct.new(:label, :href, :meta, keyword_init: true)

  # Manual builder — see DataTableComponent#with_column for why not a slot.
  def with_item(label, href: nil, meta: nil)
    items << Item.new(label: label, href: href, meta: meta)
    nil
  end

  def items
    @items ||= []
  end

  def initialize(title: "Related")
    @title = title
  end

  attr_reader :title

  def render?
    content # force the builder block so items register before we decide
    items.any?
  end
end
