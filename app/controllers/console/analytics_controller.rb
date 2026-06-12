class Console::AnalyticsController < Console::BaseController
  before_action -> { require_capability(:view_pipeline) }

  def show
    apps = scope_by_jurisdiction(scoped_applications, :region)
    contracts = contracts_for(apps)
    users = policy.futureproof? ? User.all : User.where(lender: policy.lender)

    @data = Console::AnalyticsPresenter.new(
      applications_scope: apps,
      contracts_scope: contracts,
      users_scope: users
    ).call
  end

  private

  def contracts_for(apps)
    app_ids = apps.pluck(:id)
    return Contract.none if app_ids.empty?

    Contract.real.where(application_id: app_ids)
  end
end
