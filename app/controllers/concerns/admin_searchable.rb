# Admin searchable concern
# Provides common search and filter functionality for admin controllers
module AdminSearchable
  extend ActiveSupport::Concern

  private

  # Apply search filters to a scope
  # @param scope [ActiveRecord::Relation] The base scope to filter
  # @param search_term [String] The search term from params
  # @param searchable_columns [Array<String>] Column names to search in
  # @return [ActiveRecord::Relation] Filtered scope
  def apply_search_filters(scope, search_term, searchable_columns)
    return scope if search_term.blank?

    conditions = searchable_columns.map do |column|
      "#{column} ILIKE :search"
    end.join(' OR ')

    scope.where(conditions, search: "%#{sanitize_sql_like(search_term)}%")
  end

  # Apply status filter to a scope
  # @param scope [ActiveRecord::Relation] The base scope to filter
  # @param status [String] The status from params
  # @return [ActiveRecord::Relation] Filtered scope
  def apply_status_filter(scope, status)
    return scope if status.blank?
    return scope if status == 'all'

    scope.where(status: status)
  end

  # Apply pagination
  # @param scope [ActiveRecord::Relation] The base scope to paginate
  # @param page [Integer] Page number (default: 1)
  # @param per_page [Integer] Items per page (default: 20)
  # @return [ActiveRecord::Relation] Paginated scope
  def apply_pagination(scope, page = 1, per_page = 20)
    page = page.to_i
    page = 1 if page < 1
    per_page = per_page.to_i
    per_page = 20 if per_page < 1 || per_page > 100

    scope.offset((page - 1) * per_page).limit(per_page)
  end

  # Sanitize LIKE queries to prevent SQL injection
  def sanitize_sql_like(string)
    string.gsub(/[\\%_]/) { |m| "\\#{m}" }
  end
end