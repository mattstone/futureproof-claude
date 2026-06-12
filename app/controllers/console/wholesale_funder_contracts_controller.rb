# The funder's contract document library — per-jurisdiction master
# agreements and terms, versioned by hand. Executed instruments with
# signatures go through Agreements; these are the document texts on file.
class Console::WholesaleFunderContractsController < Console::BaseController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_wholesale_funder
  before_action :set_document, only: [ :show, :edit, :update, :destroy ]

  PARTY_TYPES = [
    "Master Agreement", "Lender Agreement", "Broker Agreement",
    "Terms of Service", "Investment Agreement"
  ].freeze

  def show
  end

  def new
    @document = @wholesale_funder.wholesale_funder_contracts.new(jurisdiction: "AU", version: 1)
  end

  def create
    @document = @wholesale_funder.wholesale_funder_contracts.new(document_params)

    if @document.save
      redirect_to console_wholesale_funder_path(@wholesale_funder), notice: "Contract document added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @document.update(document_params)
      redirect_to console_wholesale_funder_funding_document_path(@wholesale_funder, @document), notice: "Contract document updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document.destroy
    redirect_to console_wholesale_funder_path(@wholesale_funder), notice: "Contract document deleted."
  end

  private

  def set_wholesale_funder
    @wholesale_funder = WholesaleFunder.find(params[:wholesale_funder_id])
  end

  def set_document
    @document = @wholesale_funder.wholesale_funder_contracts.find(params[:id])
  end

  def document_params
    params.require(:wholesale_funder_contract).permit(:jurisdiction, :party_type, :version, :html_content)
  end
end
