# Read-only view of the LEGACY per-funder funding documents
# (wholesale_funder_contracts). New funding agreements go through the
# Agreement system with its signature lifecycle; these remain visible as
# historical record until a migration consolidates or retires them.
class Console::WholesaleFunderContractsController < Console::BaseController
  before_action -> { require_capability(:manage_partners) }

  def show
    @wholesale_funder = WholesaleFunder.find(params[:wholesale_funder_id])
    @document = @wholesale_funder.wholesale_funder_contracts.find(params[:id])
  end
end
