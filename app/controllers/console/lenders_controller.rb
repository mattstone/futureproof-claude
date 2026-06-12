class Console::LendersController < Console::ResourceController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_lender, only: [ :show, :edit, :update ]

  resource Lender
  searches "lenders.name", "lenders.contact_email"
  sortable name: "lenders.name",
           country: "lenders.country",
           created: "lenders.created_at"
  default_sort :name, :asc
  filters country: ->(scope, value) { scope.where(country: value) },
          lender_type: ->(scope, value) { scope.where(lender_type: value) }
  preloads :lender_wholesale_funders, :lender_funder_pools

  csv_column("Name") { |l| l.name }
  csv_column("Type") { |l| l.lender_type }
  csv_column("Country") { |l| l.country }
  csv_column("Contact") { |l| l.contact_email }
  csv_column("Created") { |l| l.created_at.to_date.iso8601 }

  def index
    lender_ids = filtered_scope.unscope(:order).pluck(:id)
    @summary_stats = {
      total_lenders: lender_ids.size,
      total_funders: LenderWholesaleFunder.where(lender_id: lender_ids).distinct.count(:wholesale_funder_id),
      total_applications: Application.where(lender_id: lender_ids).count,
      total_capital_deployed: Application.where(lender_id: lender_ids).sum(:equity_investment_amount) || 0
    }
    super
  end

  def show
    @lender.log_view_by(current_user)
    @onboarding = Console::PartnerOnboarding.for(@lender)
    @wholesale_funder_relationships = @lender.lender_wholesale_funders.includes(:wholesale_funder).order("wholesale_funders.name")
    @pool_relationships = @lender.lender_funder_pools.includes(funder_pool: :wholesale_funder)
    @available_wholesale_funders = WholesaleFunder.status_active.where.not(id: @lender.wholesale_funders.select(:id)).order(:name)
    @available_pools = available_pools_for(@lender)
    @commission_rates = @lender.broker_commission_rates.includes(:broker).order(created_at: :desc)
    @versions = collect_all_lender_versions
  end

  def scorecard
    lenders = Lender.includes(:lender_funder_pools, :applications).order(:name)
    @scorecards = lenders.map { |lender| scorecard_for(lender) }
    @herfindahl = herfindahl_index(@scorecards)
    @capital_flow = build_capital_flow
  end

  def new
    @lender = Lender.new
  end

  def create
    @lender = Lender.new(lender_params)
    @lender.current_user = current_user

    if @lender.save
      redirect_to console_lender_path(@lender), notice: "Lender created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @lender.current_user = current_user

    if @lender.update(lender_params)
      redirect_to console_lender_path(@lender), notice: "Lender updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Creates the lender-side admin account and emails a password-reset link —
  # the "their first user" step of onboarding.
  def invite_admin
    @lender = Lender.find(params[:id])
    user = User.new(
      first_name: params[:first_name],
      last_name: params[:last_name],
      email: params[:email],
      country_of_residence: country_for(@lender.country),
      lender: @lender,
      admin: true,
      terms_accepted: true,
      confirmed_at: Time.current,
      password: SecureRandom.base58(24)
    )

    if user.save
      user.send_reset_password_instructions
      AuditLog.log_action(user: current_user, action: "partner_admin_invited", resource: user,
                          reason: "Invited as admin for #{@lender.name}")
      redirect_to console_lender_path(@lender), notice: "#{user.email} invited — they set their own password via email."
    else
      redirect_to console_lender_path(@lender), alert: "Invite failed: #{user.errors.full_messages.to_sentence}"
    end
  end

  def suspend
    @lender = Lender.find(params[:id])
    if @lender.lender_type_futureproof?
      redirect_to console_lender_path(@lender), alert: "The Futureproof house lender cannot be suspended." and return
    end
    change_status(@lender, :suspended, console_lender_path(@lender))
  end

  def reactivate
    @lender = Lender.find(params[:id])
    change_status(@lender, :active, console_lender_path(@lender))
  end

  protected

  def base_scope
    scope_by_jurisdiction(Lender.all, :country)
  end

  # Shared with the wholesale funders controller via duplication kept tiny:
  # one audited status flip with a mandatory reason.
  def change_status(partner, new_status, redirect_path)
    if params[:reason].blank?
      redirect_to redirect_path, alert: "A reason is required — it goes in the audit log." and return
    end

    partner.update!(status: new_status)
    AuditLog.log_action(
      user: current_user,
      action: new_status == :suspended ? "partner_suspended" : "partner_reactivated",
      resource: partner,
      reason: params[:reason]
    )
    redirect_to redirect_path, notice: "#{partner.name} #{new_status == :suspended ? 'suspended' : 'reactivated'}."
  end

  private

  def country_for(code)
    { "AU" => "Australia", "NZ" => "New Zealand", "UK" => "United Kingdom" }.fetch(code, "United States")
  end

  def set_lender
    @lender = Lender.find(params[:id])
  end

  # Pools from wholesale funders this lender has an ACTIVE relationship
  # with, minus those already linked.
  def available_pools_for(lender)
    FunderPool.joins(:wholesale_funder)
              .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
              .where(lender_wholesale_funders: { lender_id: lender.id, active: true })
              .where.not(id: lender.funder_pools.select(:id))
              .includes(:wholesale_funder)
              .order("wholesale_funders.name, funder_pools.name")
  end

  def collect_all_lender_versions
    versions = []
    versions += @lender.lender_versions.includes(:user)
    versions += LenderWholesaleFunderVersion.joins(:lender_wholesale_funder)
                                            .where(lender_wholesale_funders: { lender_id: @lender.id })
                                            .includes(:user, lender_wholesale_funder: :wholesale_funder)
    versions += LenderFunderPoolVersion.joins(:lender_funder_pool)
                                       .where(lender_funder_pools: { lender_id: @lender.id })
                                       .includes(:user, lender_funder_pool: { funder_pool: :wholesale_funder })
    versions.sort_by(&:created_at).reverse
  end

  def scorecard_for(lender)
    pools = lender.lender_funder_pools.includes(:funder_pool)
    capacity = pools.sum { |lfp| lfp.funder_pool&.amount || 0 }
    allocated = pools.sum { |lfp| lfp.funder_pool&.allocated || 0 }
    contracts = Contract.where(lender_id: lender.id)
    funded = contracts.where.not(cost_of_capital_rate: nil).where.not(allocated_amount: 0)
    weighted_cost = if funded.any? && funded.sum(:allocated_amount).positive?
                      (funded.sum("cost_of_capital_rate * allocated_amount") / funded.sum(:allocated_amount)).round(2)
    else
                      0
    end

    {
      lender: lender,
      capacity: capacity,
      allocated: allocated,
      available: capacity - allocated,
      utilisation: capacity.positive? ? (allocated.to_f / capacity * 100).round(1) : 0,
      active_contracts: contracts.where(status: %i[ok in_holiday]).count,
      total_contracts: contracts.count,
      weighted_cost_of_capital: weighted_cost
    }
  end

  def herfindahl_index(scorecards)
    total_allocated = scorecards.sum { |s| s[:allocated] }
    return 0 if total_allocated.zero?

    scorecards.sum do |s|
      share = s[:allocated].to_f / total_allocated
      (share * 100)**2
    end.round(0)
  end

  def build_capital_flow
    funders = WholesaleFunder.includes(funder_pools: { lender_funder_pools: :lender }).all
    return { nodes: [], links: [] } if funders.empty?

    nodes = []
    node_index = {}
    add_node = ->(key, name, kind) {
      return node_index[key] if node_index.key?(key)
      idx = nodes.size
      nodes << { name: name, kind: kind }
      node_index[key] = idx
      idx
    }

    links = []

    funders.each do |funder|
      next if funder.funder_pools.empty?
      funder_idx = add_node.call("f-#{funder.id}", funder.name, "funder")

      funder.funder_pools.each do |pool|
        next if pool.allocated.to_f.zero?
        pool_idx = add_node.call("p-#{pool.id}", pool.name, "pool")
        links << { source: funder_idx, target: pool_idx, value: pool.allocated.to_f, kind: "allocated" }

        pool.lender_funder_pools.each do |lfp|
          next if lfp.lender.nil?
          lender_idx = add_node.call("l-#{lfp.lender_id}", lfp.lender.name, "lender")
          share = pool.allocated.to_f / pool.lender_funder_pools.size
          links << { source: pool_idx, target: lender_idx, value: share, kind: "allocated" }
        end
      end
    end

    Contract.includes(:lender).group_by(&:lender_id).each do |lender_id, contracts|
      next unless lender_id
      lender_key = "l-#{lender_id}"
      next unless node_index.key?(lender_key)
      lender_idx = node_index[lender_key]

      contracts.group_by(&:status).each do |status, group|
        status_idx = add_node.call("s-#{status}", status.to_s.humanize, status.to_s)
        total = group.sum { |c| c.allocated_amount.to_f }
        next if total.zero?
        links << { source: lender_idx, target: status_idx, value: total, kind: status.to_s }
      end
    end

    { nodes: nodes, links: links }
  end

  def lender_params
    params.require(:lender).permit(:lender_type, :name, :address, :postcode, :country,
                                   :contact_email, :contact_telephone, :contact_telephone_country_code)
  end
end
