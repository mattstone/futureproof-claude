# Search box + filter dropdowns above an index table. Submits as GET via the
# existing auto-submit Stimulus controller (debounced typing, instant selects).
class Console::FilterBarComponent < Console::BaseComponent
  SelectFilter = Struct.new(:name, :options, :selected, :label, :include_blank, keyword_init: true)

  # Manual builder — see DataTableComponent#with_column for why not a slot.
  def with_select(name, options:, selected: nil, label: nil, include_blank: "All")
    selects << SelectFilter.new(name: name, options: options, selected: selected,
                                label: label || name.to_s.humanize, include_blank: include_blank)
    nil
  end

  def selects
    @selects ||= []
  end

  def initialize(url:, search: true, search_name: :search, search_value: nil, search_placeholder: "Search…", clear_url: nil)
    @url = url
    @search = search
    @search_name = search_name
    @search_value = search_value
    @search_placeholder = search_placeholder
    @clear_url = clear_url
  end

  attr_reader :url, :search, :search_name, :search_value, :search_placeholder, :clear_url

  def show_clear?
    clear_url.present? && (search_value.present? || selects.any? { |s| s.selected.present? })
  end
end
