class Admin::LendersController < Admin::BaseController
  include Admin::AdminHelper
  before_action :ensure_futureproof_admin
  before_action :set_lender, only: [:show, :edit, :update, :destroy]

  def index
    # Filter by jurisdiction (map AU/US/NZ/UK to country codes)
    all_lenders = Lender.includes(:lender_wholesale_funders, :lender_funder_pools, :applications)
    @lenders = jurisdiction_filtered_scope(all_lenders, :country).order(:lender_type, :name)
    @current_jurisdiction = current_admin_jurisdiction
    
    # Calculate summary metrics
    lender_ids = @lenders.pluck(:id)
    @summary_stats = {
      total_lenders: @lenders.count,
      total_funders: LenderWholesaleFunder.where(lender_id: lender_ids).distinct.count(:wholesale_funder_id),
      total_applications: Application.where(lender_id: lender_ids).count,
      total_capital_deployed: Application.where(lender_id: lender_ids).sum(:equity_investment_amount) || 0
    }
  end

  def show
    @lender.log_view_by(current_user) if current_user
    @all_versions = collect_all_lender_versions
  end

  def scorecard
    lenders = Lender.includes(:lender_funder_pools, :applications).order(:name)
    @scorecards = lenders.map { |lender| scorecard_for(lender) }
    @herfindahl = herfindahl_index(@scorecards)
    @capital_flow = build_capital_flow
  end

  # AJAX endpoint to get available wholesale funders for selection
  def available_wholesale_funders
    @lender = Lender.find(params[:id])
    @available_wholesale_funders = WholesaleFunder.includes(:funder_pools)
                                                  .where.not(id: @lender.wholesale_funders.select(:id))
                                                  .order(:name)
    
    render json: {
      wholesale_funders: @available_wholesale_funders.map do |wf|
        {
          id: wf.id,
          name: wf.name,
          country: wf.country,
          currency: wf.currency,
          currency_symbol: wf.currency_symbol,
          pools_count: wf.funder_pools.count,
          formatted_total_capital: wf.formatted_total_capital
        }
      end
    }
  end

  def new
    @lender = Lender.new
  end

  def create
    @lender = Lender.new(lender_params)
    @lender.current_user = current_user
    
    if @lender.save
      redirect_to admin_lender_path(@lender), notice: 'Lender was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @lender.current_user = current_user
    if @lender.update(lender_params)
      redirect_to admin_lender_path(@lender), notice: 'Lender was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Prevent deletion of Futureproof lender
    if @lender.lender_type_futureproof?
      redirect_to admin_lenders_path, alert: 'Futureproof lender cannot be deleted.'
      return
    end
    
    @lender.destroy
    redirect_to admin_lenders_path, notice: 'Lender was successfully deleted.'
  end

  private

  def set_lender
    @lender = Lender.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_lenders_path, alert: "Lender not found"
  end

  def collect_all_lender_versions
    # Collect all version records related to this lender
    versions = []
    
    # Lender's own version history
    versions += @lender.lender_versions.includes(:user)
    
    # Wholesale funder relationship versions
    versions += LenderWholesaleFunderVersion.joins(:lender_wholesale_funder)
                                           .where(lender_wholesale_funders: { lender_id: @lender.id })
                                           .includes(:user, lender_wholesale_funder: :wholesale_funder)
    
    # Funder pool relationship versions
    versions += LenderFunderPoolVersion.joins(:lender_funder_pool)
                                      .where(lender_funder_pools: { lender_id: @lender.id })
                                      .includes(:user, lender_funder_pool: { funder_pool: :wholesale_funder })
    
    # Sort by created_at descending
    versions.sort_by(&:created_at).reverse
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
      funder_idx = add_node.call("f-#{funder.id}", funder.name, 'funder')

      funder.funder_pools.each do |pool|
        next if pool.allocated.to_f.zero?
        pool_idx = add_node.call("p-#{pool.id}", pool.name, 'pool')

        # Funder -> Pool: total allocated within the pool
        links << { source: funder_idx, target: pool_idx, value: pool.allocated.to_f, kind: 'allocated' }

        # Pool -> Lender: each lender's allocation within this pool
        pool.lender_funder_pools.each do |lfp|
          next if lfp.lender.nil?
          lender_idx = add_node.call("l-#{lfp.lender_id}", lfp.lender.name, 'lender')
          # Approximate: each lender has equal share of the pool's allocated capital
          share = pool.allocated.to_f / pool.lender_funder_pools.size
          links << { source: pool_idx, target: lender_idx, value: share, kind: 'allocated' }
        end
      end
    end

    # Lender -> Contract status
    Contract.includes(:lender).group_by(&:lender_id).each do |lender_id, contracts|
      next unless lender_id
      lender_key = "l-#{lender_id}"
      next unless node_index.key?(lender_key)
      lender_idx = node_index[lender_key]

      contracts.group_by(&:status).each do |status, group|
        status_label = status.to_s.humanize
        status_idx = add_node.call("s-#{status}", status_label, status.to_s)
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

  def scorecard_for(lender)
    pools = lender.lender_funder_pools.includes(:funder_pool)
    capacity = pools.sum { |lfp| lfp.funder_pool&.amount || 0 }
    allocated = pools.sum { |lfp| lfp.funder_pool&.allocated || 0 }
    contracts = Contract.where(lender_id: lender.id)
    funded = contracts.where.not(cost_of_capital_rate: nil).where.not(allocated_amount: 0)
    weighted_cost = if funded.any? && funded.sum(:allocated_amount).positive?
                      (funded.sum('cost_of_capital_rate * allocated_amount') / funded.sum(:allocated_amount)).round(2)
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
end
