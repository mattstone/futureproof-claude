module AdminTableHelper
  # Sortable column header link. Preserves existing filter params; toggles
  # direction on repeat click; shows ▲/▼ on the active column.
  def sortable_header(label, column)
    column = column.to_s
    active = params[:sort] == column
    next_direction = active && params[:direction] != "asc" ? "asc" : "desc"
    arrow = if active
      params[:direction] == "asc" ? " ▲" : " ▼"
    else
      ""
    end

    link_to "#{label}#{arrow}",
            url_for(request.query_parameters.merge(sort: column, direction: next_direction)),
            class: "sortable-header#{' sortable-header-active' if active}"
  end

  # Standard CSV export link for the current index view (keeps filters).
  def csv_export_link
    link_to "⬇ Export CSV",
            url_for(request.query_parameters.merge(format: :csv)),
            class: "admin-btn admin-btn-secondary admin-btn-sm"
  end
end
