module Console
  # Static rules that keep Console views structurally consistent.
  # Run via the console_views_lint_test (CI-gating) or `rails console:lint`.
  class ViewLinter
    RULES = [
      [ /<style/i,                "inline <style> block — styles belong in console.css" ],
      [ /\sstyle="/,              "inline style attribute — use a console-* class" ],
      [ /\bclass="[^"]*\badmin-/, "legacy admin-* class — use console-* classes" ],
      [ /\badmin_[a-z_]*_path\b/, "admin_*_path helper — console views must not link into the legacy admin (except the nav escape hatch)" ]
    ].freeze

    TABLE_RULE = [ /<table\b/i, "raw <table> — use Console::DataTableComponent" ].freeze
    # data_table: the component's own template. calculators: the Monte Carlo
    # Stimulus controller injects rows client-side, which DataTable can't host.
    TABLE_EXEMPT = %w[
      app/components/console/data_table_component.html.erb
      app/views/console/calculators/index.html.erb
    ].freeze

    # The single sanctioned link back to /admin during the parallel run.
    ADMIN_PATH_EXEMPT = %w[_nav.html.erb].freeze

    def self.offenses
      files.flat_map { |file| check(file) }
    end

    def self.files
      Dir["app/views/console/**/*.erb"] +
        Dir["app/components/console/**/*.erb"] +
        Dir["app/views/kaminari/console/*.erb"] +
        [ "app/views/layouts/console.html.erb" ]
    end

    def self.check(file)
      content = File.read(file)
      basename = File.basename(file)
      found = []

      RULES.each do |pattern, message|
        next if message.include?("admin_*_path") && ADMIN_PATH_EXEMPT.include?(basename)

        found << "#{file}: #{message}" if content.match?(pattern)
      end

      unless TABLE_EXEMPT.include?(file)
        found << "#{file}: #{TABLE_RULE.last}" if content.match?(TABLE_RULE.first)
      end

      found
    end
  end
end
