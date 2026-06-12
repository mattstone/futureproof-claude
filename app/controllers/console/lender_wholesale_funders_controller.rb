# Lender ↔ wholesale-funder relationships. Plain form posts with redirects
# back to the lender page — the legacy turbo-stream plumbing isn't carried.
class Console::LenderWholesaleFundersController < Console::BaseController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_lender

  def create
    wholesale_funder = WholesaleFunder.find(params[:wholesale_funder_id])
    relationship = @lender.lender_wholesale_funders.build(wholesale_funder: wholesale_funder, active: true)
    relationship.current_user = current_user if relationship.respond_to?(:current_user=)

    if relationship.save
      redirect_to console_lender_path(@lender), notice: "#{wholesale_funder.name} added."
    else
      redirect_to console_lender_path(@lender), alert: relationship.errors.full_messages.to_sentence
    end
  end

  # Removing a funder also removes that funder's pool relationships.
  def destroy
    relationship = @lender.lender_wholesale_funders.find(params[:id])
    wholesale_funder = relationship.wholesale_funder

    associated_pools = @lender.lender_funder_pools.joins(:funder_pool)
                              .where(funder_pools: { wholesale_funder: wholesale_funder })
    pools_count = associated_pools.count
    associated_pools.each { |pool_rel| pool_rel.current_user = current_user if pool_rel.respond_to?(:current_user=) }
    associated_pools.destroy_all

    relationship.current_user = current_user if relationship.respond_to?(:current_user=)
    relationship.destroy

    message = "#{wholesale_funder.name} removed."
    message += " #{pools_count} associated pool relationship#{'s' unless pools_count == 1} also removed." if pools_count.positive?
    redirect_to console_lender_path(@lender), notice: message
  end

  def toggle_active
    relationship = @lender.lender_wholesale_funders.find(params[:id])
    relationship.current_user = current_user if relationship.respond_to?(:current_user=)
    relationship.toggle_active!

    status = relationship.reload.active? ? "activated" : "deactivated"
    redirect_to console_lender_path(@lender), notice: "#{relationship.wholesale_funder.name} #{status}."
  end

  private

  def set_lender
    @lender = Lender.find(params[:lender_id])
  end
end
