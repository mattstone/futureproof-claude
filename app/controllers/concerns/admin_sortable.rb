# Whitelisted column sorting for admin index views.
# Usage: scope = sort_scope(scope, allowed: %w[created_at home_value], default: nil)
# View: <%= sortable_header "Created", :created_at %>
module AdminSortable
  extend ActiveSupport::Concern

  private

  def sort_scope(scope, allowed:, default: nil)
    column = params[:sort].presence_in(allowed.map(&:to_s)) || default
    return scope unless column

    direction = params[:direction] == "asc" ? :asc : :desc
    scope.reorder(column => direction)
  end
end
