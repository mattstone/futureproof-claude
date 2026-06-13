class Admin::WholesaleFunderContractsController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_wholesale_funder
  before_action :set_contract, only: [ :edit, :update, :destroy ]

  def index
    @contracts = @wholesale_funder.wholesale_funder_contracts.all
  end

  def new
    @contract = @wholesale_funder.wholesale_funder_contracts.new
  end

  def create
    @contract = @wholesale_funder.wholesale_funder_contracts.new(contract_params)

    if @contract.save
      redirect_to admin_wholesale_funder_contracts_path(@wholesale_funder),
                  notice: "Contract was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @contract.update(contract_params)
      redirect_to admin_wholesale_funder_contracts_path(@wholesale_funder),
                  notice: "Contract was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @contract.destroy
    redirect_to admin_wholesale_funder_contracts_path(@wholesale_funder),
                notice: "Contract was successfully deleted."
  end

  private

  def set_wholesale_funder
    @wholesale_funder = WholesaleFunder.find(params[:wholesale_funder_id])
  end

  def set_contract
    @contract = @wholesale_funder.wholesale_funder_contracts.find(params[:id])
  end

  def contract_params
    params.require(:wholesale_funder_contract).permit(:jurisdiction, :html_content, :party_type, :version)
  end
end
