require "test_helper"

# One test per GET route under /console, generated from the route set.
# A console page that can't render is a CI failure, not a demo surprise —
# this is the institutionalized version of the drill-down lesson.
#
# :id segments resolve to a fixture record inferred from the controller
# name; a route whose model has no fixture FAILS — coverage is forced,
# not skipped. Add explicit entries to PARAM_RESOLVERS for routes whose
# params don't follow the convention.
class Console::SmokeTest < ActionDispatch::IntegrationTest
  PARAM_RESOLVERS = {
    "console/funder_pools" => -> {
      pool = FunderPool.first || flunk("No FunderPool fixture exists")
      { wholesale_funder_id: pool.wholesale_funder_id, id: pool.id }
    },
    "console/lender_clauses" => -> {
      { lender_id: Lender.first.id }
    },
    "console/broker_commission_rates" => -> {
      rate = BrokerCommissionRate.first || flunk("No BrokerCommissionRate fixture exists")
      { lender_id: rate.lender_id, id: rate.id }
    },
    "console/mortgage_contracts" => -> {
      contract = MortgageContract.where.not(mortgage_id: nil).first || flunk("No MortgageContract fixture exists")
      { mortgage_id: contract.mortgage_id, id: contract.id }
    },
    "console/prompts" => -> {
      { key: PromptFiles.slots_for(:runtime).first.key }
    },
    "console/wholesale_funder_contracts" => -> {
      doc = WholesaleFunderContract.first || flunk("No WholesaleFunderContract fixture exists")
      { wholesale_funder_id: doc.wholesale_funder_id, id: doc.id }
    }
  }.freeze

  def self.console_get_routes
    Rails.application.routes.routes.select do |route|
      route.verb == "GET" && route.path.spec.to_s.start_with?("/console")
    end
  end

  console_get_routes.each do |route|
    controller = route.defaults[:controller]
    action = route.defaults[:action]
    path_spec = route.path.spec.to_s.sub("(.:format)", "")

    test "GET #{path_spec} (#{controller}##{action}) renders for futureproof admin" do
      sign_in users(:admin_user)
      get resolve_path(route)
      assert_equal 200, response.status,
        "#{path_spec} returned #{response.status} for a futureproof admin"
    end

    test "GET #{path_spec} (#{controller}##{action}) never 5xxs for lender admin" do
      sign_in users(:lender_admin_user)
      get resolve_path(route)
      # 302 = capability redirect, 404 = record correctly scoped away. 5xx = bug.
      assert_includes [ 200, 302, 404 ], response.status,
        "#{path_spec} returned #{response.status} for a lender admin"
    end
  end

  private

  def resolve_path(route)
    required = route.required_parts - [ :format ]
    params = {}

    if required.any?
      resolver = PARAM_RESOLVERS[route.defaults[:controller]]
      if resolver
        params = instance_exec(&resolver)
      else
        params = conventional_params(route, required)
      end
    end

    route.format(params)
  end

  def conventional_params(route, required)
    flunk "Route #{route.path.spec} needs params #{required.inspect} — add a PARAM_RESOLVERS entry" unless required == [ :id ]

    model_name = route.defaults[:controller].split("/").last.classify
    model = model_name.safe_constantize
    flunk "Cannot infer model for #{route.defaults[:controller]} — add a PARAM_RESOLVERS entry" unless model

    record = model.first
    flunk "No #{model_name} fixture exists — add one so /console#{route.path.spec.to_s.sub('(.:format)', '')} is smoke-testable" unless record

    { id: record.id }
  end
end
