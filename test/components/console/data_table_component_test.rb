require "test_helper"

class Console::DataTableComponentTest < ViewComponent::TestCase
  Row = Struct.new(:name, :amount)

  def rows
    [ Row.new("Alice", 100), Row.new("Bob", 250) ]
  end

  test "renders one cell per column per record via captured blocks" do
    render_inline Console::DataTableComponent.new(records: rows, id: "people") do |table|
      table.with_column("Name") { |row| row.name }
      table.with_column("Amount", numeric: true) { |row| row.amount.to_s }
    end

    assert_selector "turbo-frame#people"
    assert_selector "table.console-table"
    # Regression: the frame must break links out to the top page. Without it,
    # a row's drill-in link loads the show page INTO this frame, which lacks a
    # matching <turbo-frame>, and Turbo blanks the table with "Content missing".
    assert_selector "turbo-frame#people[target='_top']"
    assert_selector "th", text: "Name"
    assert_selector "th.console-table-numeric", text: "Amount"
    assert_selector "td", text: "Alice"
    assert_selector "td.console-table-numeric", text: "250"
    assert_selector "tbody tr", count: 2
  end

  test "sortable headers link into the current query string" do
    with_request_url "/console?status=open" do
      render_inline Console::DataTableComponent.new(records: rows, id: "people") do |table|
        table.with_column("Name", sort: "name") { |row| row.name }
      end
    end

    link = page.find(".console-table-sort")
    assert_includes link[:href], "sort=name"
    assert_includes link[:href], "direction=asc"
    assert_includes link[:href], "status=open"
  end

  test "empty records render the empty state, not a bare table" do
    render_inline Console::DataTableComponent.new(records: [], id: "people", empty_message: "No people found.") do |table|
      table.with_column("Name") { |row| row.name }
    end

    assert_selector "td.console-table-empty", text: "No people found."
  end

  test "csv link renders when a path is given" do
    render_inline Console::DataTableComponent.new(records: rows, id: "people", csv_path: "/console/people.csv") do |table|
      table.with_column("Name") { |row| row.name }
    end

    assert_selector "a.console-table-csv[href='/console/people.csv']", text: "Export CSV"
  end
end
