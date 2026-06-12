# Attach/detach lender clauses to a mortgage contract at a named position.
class Console::ContractClausesController < Console::BaseController
  before_action -> { require_capability(:manage_product) }
  before_action :set_mortgage_and_contract

  def create
    lender_clause = LenderClause.find(params[:lender_clause_id])
    clause_position = ClausePosition.find(params[:clause_position_id])

    @contract.add_lender_clause(lender_clause, clause_position, current_user)
    redirect_to console_mortgage_mortgage_contract_path(@mortgage, @contract),
                notice: "Clause '#{lender_clause.title}' added."
  rescue => e
    redirect_to console_mortgage_mortgage_contract_path(@mortgage, @contract),
                alert: "Failed to add clause: #{e.message}"
  end

  def destroy
    clause_position = ClausePosition.find(params[:clause_position_id])
    @contract.remove_lender_clause(clause_position, current_user)
    redirect_to console_mortgage_mortgage_contract_path(@mortgage, @contract), notice: "Clause removed."
  rescue => e
    redirect_to console_mortgage_mortgage_contract_path(@mortgage, @contract), alert: "Failed to remove clause: #{e.message}"
  end

  private

  def set_mortgage_and_contract
    @mortgage = Mortgage.find(params[:mortgage_id])
    @contract = @mortgage.mortgage_contracts.find(params[:mortgage_contract_id])
  end
end
