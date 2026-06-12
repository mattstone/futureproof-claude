class Console::LenderFunderPoolsController < Console::BaseController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_lender

  def create
    funder_pool = FunderPool.find(params[:funder_pool_id])
    relationship = @lender.lender_funder_pools.build(funder_pool: funder_pool, active: true)
    relationship.current_user = current_user if relationship.respond_to?(:current_user=)

    if relationship.save
      redirect_to console_lender_path(@lender), notice: "#{funder_pool.name} added."
    else
      redirect_to console_lender_path(@lender), alert: relationship.errors.full_messages.to_sentence
    end
  end

  def destroy
    relationship = @lender.lender_funder_pools.find(params[:id])
    relationship.current_user = current_user if relationship.respond_to?(:current_user=)
    relationship.destroy
    redirect_to console_lender_path(@lender), notice: "#{relationship.funder_pool.name} removed."
  end

  def toggle_active
    relationship = @lender.lender_funder_pools.find(params[:id])
    relationship.current_user = current_user if relationship.respond_to?(:current_user=)

    begin
      relationship.toggle_active!
      status = relationship.active? ? "activated" : "deactivated"
      redirect_to console_lender_path(@lender), notice: "#{relationship.funder_pool.name} #{status}."
    rescue StandardError => e
      redirect_to console_lender_path(@lender), alert: e.message
    end
  end

  private

  def set_lender
    @lender = Lender.find(params[:lender_id])
  end
end
