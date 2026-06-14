# THE index table. Sorting, pagination, CSV export link, and empty state are
# baked in — a console page never writes a raw <table>.
#
#   <%= render Console::DataTableComponent.new(records: @applications, id: "applications",
#                                              csv_path: console_applications_path(format: :csv)) do |table| %>
#     <% table.with_column "Customer", sort: "users.last_name" do |application| %>
#       <%= link_to application.user.email, console_application_path(application) %>
#     <% end %>
#     <% table.with_column "Status" do |application| %>
#       <%= render Console::BadgeComponent.new(status: application.status) %>
#     <% end %>
#   <% end %>
#
# Sort headers merge into the current query string, so they compose with the
# FilterBar. The whole table self-wraps in a turbo frame keyed by `id`, so
# sorting/pagination/filtering only repaint the table.
class Console::DataTableComponent < Console::BaseComponent
  Column = Struct.new(:label, :sort, :numeric, :block, keyword_init: true)

  # Manual builder (not a ViewComponent slot): columns carry a per-row block
  # that we re-capture for every record, which slots can't express. The
  # template's first line forces `content` so these register before the
  # header row renders.
  def with_column(label, sort: nil, numeric: false, &block)
    columns << Column.new(label: label, sort: sort, numeric: numeric, block: block)
    nil
  end

  def columns
    @columns ||= []
  end

  # row_class: an optional ->(record) { "console-row-error" | nil } that tags a
  # row for triage emphasis (left accent + faint tint), so at-risk / stalled
  # rows surface without reading every badge.
  # empty_action: optional rendered link (a "New X" button) shown under the
  # empty-state message so a genuinely-empty resource offers a next step.
  def initialize(records:, id:, csv_path: nil, empty_message: "Nothing here yet.", row_class: nil, empty_action: nil)
    @records = records
    @id = id
    @csv_path = csv_path
    @empty_message = empty_message
    @row_class = row_class
    @empty_action = empty_action
  end

  attr_reader :records, :id, :csv_path, :empty_message, :row_class, :empty_action

  def row_class_for(record)
    row_class&.call(record).presence
  end

  def paginated?
    records.respond_to?(:current_page)
  end

  def current_sort
    helpers.params[:sort].to_s
  end

  def current_direction
    helpers.params[:direction].to_s == "desc" ? "desc" : "asc"
  end

  def sort_url(column)
    direction = (current_sort == column.sort && current_direction == "asc") ? "desc" : "asc"
    query = helpers.request.query_parameters.merge("sort" => column.sort, "direction" => direction)
    "#{helpers.request.path}?#{query.to_query}"
  end

  def sort_indicator(column)
    return "" unless current_sort == column.sort

    current_direction == "asc" ? "▲" : "▼"
  end
end
