# Declarative index + CSV for Console resources. Show pages and forms stay
# bespoke per controller (uniform via components); listing a collection is
# the same job everywhere, so it's written once, here.
#
#   class Console::UsersController < Console::ResourceController
#     resource User
#     searches :email, :first_name, :last_name
#     sortable email: "users.email", created: "users.created_at"
#     default_sort :created, :desc
#     filters admin: ->(scope, value) { scope.where(admin: value == "true") }
#     csv_column("Email") { |user| user.email }
#
#     def base_scope = policy-scoped relation   # ALWAYS overridden
#   end
#
# Every collection ends .strict_loading — an N+1 raises in development and
# test instead of shipping. Declare needed associations with `preloads`.
class Console::ResourceController < Console::BaseController
  PER_PAGE = 25

  class_attribute :resource_class, instance_writer: false
  class_attribute :search_columns, instance_writer: false, default: []
  class_attribute :sortable_columns, instance_writer: false, default: {}
  class_attribute :default_sort_key, instance_writer: false
  class_attribute :default_sort_direction, instance_writer: false, default: :asc
  class_attribute :filter_lambdas, instance_writer: false, default: {}
  class_attribute :csv_columns, instance_writer: false, default: {}
  class_attribute :preload_associations, instance_writer: false, default: []
  class_attribute :search_joins, instance_writer: false

  class << self
    def resource(klass)
      self.resource_class = klass
    end

    def searches(*columns, joins: nil)
      self.search_columns = columns
      self.search_joins = joins
    end

    def sortable(**mapping)
      self.sortable_columns = mapping.stringify_keys
    end

    def default_sort(key, direction = :asc)
      self.default_sort_key = key.to_s
      self.default_sort_direction = direction
    end

    def filters(**lambdas)
      self.filter_lambdas = lambdas.stringify_keys
    end

    def csv_column(header, &block)
      self.csv_columns = csv_columns.merge(header => block)
    end

    def preloads(*associations)
      self.preload_associations = associations
    end
  end

  def index
    respond_to do |format|
      format.html do
        @records = filtered_scope.page(params[:page]).per(PER_PAGE)
      end
      format.csv do
        send_data generate_csv(filtered_scope),
                  filename: "#{controller_name}-#{Time.current.strftime('%Y%m%d-%H%M')}.csv",
                  type: "text/csv"
      end
    end
  end

  protected

  # The ONLY place scoping lives: lender restriction, .real, pipeline
  # defaults. Subclasses must override.
  def base_scope
    raise NotImplementedError, "#{self.class.name} must define base_scope"
  end

  def filtered_scope
    scope = base_scope
    scope = scope.includes(*preload_associations) if preload_associations.any?
    scope = apply_search(scope)
    scope = apply_filters(scope)
    apply_sort(scope).strict_loading
  end

  def apply_search(scope)
    term = params[:search].to_s.strip
    return scope if term.blank? || search_columns.empty?

    scope = scope.joins(search_joins) if search_joins
    clauses = search_columns.map { |column| "#{column} ILIKE :term" }.join(" OR ")
    scope.where(clauses, term: "%#{ActiveRecord::Base.sanitize_sql_like(term)}%")
  end

  def apply_filters(scope)
    filter_lambdas.each do |name, filter|
      value = params[name]
      next if value.blank?

      scope = filter.call(scope, value)
    end
    scope
  end

  # Sort params are whitelisted through the `sortable` mapping — an unknown
  # key falls back to the default, never into SQL.
  def apply_sort(scope)
    key = sortable_columns.key?(params[:sort].to_s) ? params[:sort].to_s : default_sort_key
    return scope if key.nil?

    column = sortable_columns.fetch(key)
    direction = params[:direction].to_s == "desc" ? :desc : :asc
    direction = default_sort_direction if params[:sort].blank? && params[:direction].blank?
    scope.order(Arel.sql("#{column} #{direction.to_s.upcase}"))
  end

  def generate_csv(scope)
    CSV.generate(headers: true) do |csv|
      csv << csv_columns.keys
      scope.find_each do |record|
        csv << csv_columns.values.map { |block| instance_exec(record, &block) }
      end
    end
  end
end
