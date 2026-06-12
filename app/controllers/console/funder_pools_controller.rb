# Top-level index across all pools; CRUD nested under a wholesale funder.
class Console::FunderPoolsController < Console::BaseController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_wholesale_funder, except: [ :index ]
  before_action :set_funder_pool, only: [ :show, :edit, :update ]

  def index
    scope = FunderPool.includes(:wholesale_funder).recent

    if params[:search].present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search].to_s.strip)}%"
      scope = scope.joins(:wholesale_funder)
                   .where("funder_pools.name ILIKE :like OR wholesale_funders.name ILIKE :like", like: like)
    end
    scope = scope.where(wholesale_funder_id: params[:wholesale_funder_id]) if params[:wholesale_funder_id].present?

    @records = scope.strict_loading.page(params[:page]).per(25)
    @wholesale_funders_for_filter = WholesaleFunder.order(:name)
  end

  def show
    @funder_pool = @wholesale_funder.funder_pools.includes(contracts: { application: :user }).find(params[:id])
    @funder_pool.log_view_by(current_user)
  end

  def new
    @funder_pool = @wholesale_funder.funder_pools.build
  end

  def create
    @funder_pool = @wholesale_funder.funder_pools.build(funder_pool_params)
    @funder_pool.current_user = current_user

    if @funder_pool.save
      redirect_to console_wholesale_funder_path(@wholesale_funder), notice: "Funder pool created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  # Audited capacity change — the routine "the funder added more money to
  # this pool" operation, recorded with a reason.
  def top_up
    @funder_pool = @wholesale_funder.funder_pools.find(params[:id])
    delta = params[:amount_delta].to_f

    if delta.zero?
      redirect_to console_wholesale_funder_funder_pool_path(@wholesale_funder, @funder_pool),
                  alert: "Enter a non-zero amount." and return
    end

    old_amount = @funder_pool.amount
    new_amount = old_amount + delta

    if new_amount < @funder_pool.allocated.to_f
      redirect_to console_wholesale_funder_funder_pool_path(@wholesale_funder, @funder_pool),
                  alert: "Capacity can't drop below the #{@funder_pool.formatted_allocated} already allocated." and return
    end

    @funder_pool.current_user = current_user
    @funder_pool.update!(amount: new_amount)
    AuditLog.log_action(
      user: current_user, action: "pool_capacity_changed", resource: @funder_pool,
      reason: params[:reason].presence || "No reason given",
      notes: "#{helpers.number_to_currency(old_amount, precision: 0)} -> #{helpers.number_to_currency(new_amount, precision: 0)}"
    )
    redirect_to console_wholesale_funder_funder_pool_path(@wholesale_funder, @funder_pool),
                notice: "Pool capacity #{delta.positive? ? 'increased' : 'reduced'} to #{@funder_pool.reload.formatted_amount}."
  end

  def update
    @funder_pool.current_user = current_user

    if @funder_pool.update(funder_pool_params)
      redirect_to console_wholesale_funder_funder_pool_path(@wholesale_funder, @funder_pool), notice: "Funder pool updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_wholesale_funder
    @wholesale_funder = WholesaleFunder.find(params[:wholesale_funder_id])
  end

  def set_funder_pool
    @funder_pool = @wholesale_funder.funder_pools.find(params[:id])
  end

  def funder_pool_params
    params.require(:funder_pool).permit(:name, :amount, :allocated, :benchmark_rate, :margin_rate)
  end
end
