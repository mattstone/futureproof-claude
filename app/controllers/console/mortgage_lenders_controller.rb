# Which lenders offer a mortgage product — assign, toggle, remove.
class Console::MortgageLendersController < Console::BaseController
  before_action -> { require_capability(:manage_product) }
  before_action :set_mortgage

  def create
    lender = Lender.find(params[:lender_id])
    relationship = @mortgage.mortgage_lenders.build(lender: lender, active: true)
    relationship.current_user = current_user if relationship.respond_to?(:current_user=)

    if relationship.save
      redirect_back fallback_location: console_mortgage_path(@mortgage), notice: "#{lender.name} now offers #{@mortgage.name}."
    else
      redirect_back fallback_location: console_mortgage_path(@mortgage), alert: relationship.errors.full_messages.to_sentence
    end
  end

  def toggle_active
    relationship = @mortgage.mortgage_lenders.find(params[:id])
    relationship.current_user = current_user if relationship.respond_to?(:current_user=)
    relationship.update!(active: !relationship.active)
    redirect_back fallback_location: console_mortgage_path(@mortgage),
                notice: "#{relationship.lender.name} #{relationship.active? ? 'activated' : 'deactivated'} for this product."
  end

  def destroy
    relationship = @mortgage.mortgage_lenders.find(params[:id])
    relationship.current_user = current_user if relationship.respond_to?(:current_user=)
    relationship.destroy
    redirect_back fallback_location: console_mortgage_path(@mortgage), notice: "#{relationship.lender.name} no longer offers this product."
  end

  private

  def set_mortgage
    @mortgage = Mortgage.find(params[:mortgage_id])
  end
end
