# Versioned mortgage contract documents: drafts are editable, publishing
# freezes a version, editing a published version forks a new draft.
class Console::MortgageContractsController < Console::BaseController
  before_action -> { require_capability(:manage_product) }
  before_action :set_mortgage
  before_action :set_mortgage_contract, only: [ :show, :edit, :update, :activate, :publish ]

  def show
    @audit_history = @mortgage_contract.mortgage_contract_versions.includes(:user).recent_first.limit(20)
    @active_usages = @mortgage_contract.active_contract_clause_usages.includes(:clause_position, lender_clause: :lender)
    @clause_positions = ClausePosition.order(:name)
    @available_clauses = LenderClause.published.includes(:lender).order("lenders.name").references(:lender)
  end

  def new
    @mortgage_contract = @mortgage.mortgage_contracts.build
    latest_contract = @mortgage.mortgage_contracts.latest
    if latest_contract
      @mortgage_contract.title = latest_contract.title
      @mortgage_contract.content = latest_contract.content
    else
      @mortgage_contract.title = "Mortgage Contract"
      @mortgage_contract.content = "## 1. Introduction\n\nEnter your mortgage contract content here...\n"
    end
  end

  def create
    @mortgage_contract = @mortgage.mortgage_contracts.build(mortgage_contract_params)
    @mortgage_contract.is_active = false
    @mortgage_contract.is_draft = true
    @mortgage_contract.current_user = current_user
    @mortgage_contract.created_by = current_user

    if @mortgage_contract.save
      redirect_to console_mortgage_path(@mortgage), notice: "Contract draft created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @mortgage_contract.current_user = current_user

    # Editing a published version forks a fresh draft instead — published
    # versions stay immutable. (The legacy model helper for this never fired
    # because it checked content_changed? before any assignment, and dropped
    # the mortgage association when it did; we fork explicitly.)
    if @mortgage_contract.published? && mortgage_contract_params[:content] != @mortgage_contract.content
      new_version = @mortgage.mortgage_contracts.build(
        title: mortgage_contract_params[:title],
        content: mortgage_contract_params[:content],
        is_draft: true,
        is_active: false
      )
      new_version.current_user = current_user
      new_version.created_by = current_user
      new_version.save!
      redirect_to console_mortgage_path(@mortgage), notice: "New draft version created — the published version is unchanged."
      return
    end

    if @mortgage_contract.update(mortgage_contract_params)
      redirect_to console_mortgage_path(@mortgage), notice: "Contract updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def publish
    @mortgage_contract.current_user = current_user
    @mortgage_contract.update!(is_draft: false)
    redirect_to console_mortgage_path(@mortgage), notice: "Contract published."
  end

  def activate
    @mortgage_contract.current_user = current_user
    @mortgage_contract.update!(is_active: true, is_draft: false)
    redirect_to console_mortgage_path(@mortgage), notice: "Contract activated."
  end

  private

  def set_mortgage
    @mortgage = Mortgage.find(params[:mortgage_id])
  end

  def set_mortgage_contract
    @mortgage_contract = @mortgage.mortgage_contracts.find(params[:id])
  end

  def mortgage_contract_params
    params.require(:mortgage_contract).permit(:title, :content)
  end
end
