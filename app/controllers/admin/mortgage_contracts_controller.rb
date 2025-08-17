class Admin::MortgageContractsController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_mortgage_contract, only: [:show, :edit, :update, :activate, :publish, :destroy]

  def index
    @published_contracts = MortgageContract.published.order(version: :desc).page(params[:published_page]).per(10)
    @draft_contracts = MortgageContract.drafts.order(version: :desc).page(params[:draft_page]).per(10)
  end

  def show
    @audit_history = @mortgage_contract.mortgage_contract_versions
                                      .includes(:user)
                                      .recent_first
                                      .page(params[:page])
                                      .per(10)
  end

  def new
    @mortgage_contract = MortgageContract.new
    # Copy content from the latest existing contract
    latest_contract = MortgageContract.latest
    if latest_contract
      @mortgage_contract.title = latest_contract.title
      @mortgage_contract.content = latest_contract.content
    else
      # Fallback to basic template if no existing contracts
      @mortgage_contract.title = "Mortgage Contract"
      @mortgage_contract.content = <<~MARKUP
        ## 1. Introduction

        Enter your mortgage contract content here...

        ## 2. Loan Terms

        Add your loan terms using simple markup:
        - Use ## for main headings
        - Use ### for sub-headings  
        - Use - for bullet points
        - Use **text** for bold text

        ### Sub-section Example

        This is how you create sub-sections.

        **Field:** Value
        **Another Field:** Another Value

        ## Contact Information

        Lender: Your Lender Name
        Email: contact@yourlender.com
        Address: Your Address
      MARKUP
    end
  end

  def create
    @mortgage_contract = MortgageContract.new(mortgage_contract_params)
    @mortgage_contract.is_active = false # New versions start as inactive
    @mortgage_contract.is_draft = true # New versions start as draft
    @mortgage_contract.current_user = current_user # Track who created it
    @mortgage_contract.created_by = current_user
    
    if @mortgage_contract.save
      redirect_to admin_mortgage_contracts_path, notice: 'Mortgage Contract created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # If this is a published contract and user is trying to edit content,
    # create a new draft version instead
    if @mortgage_contract.published? && params[:create_new_version]
      latest_version = MortgageContract.latest
      @mortgage_contract = MortgageContract.new(
        title: latest_version.title,
        content: latest_version.content,
        is_draft: true,
        is_active: false
      )
      flash.now[:info] = "Editing a published contract will create a new version."
    end
  end

  def update
    @mortgage_contract.current_user = current_user # Track who updated it
    
    # If this is a published contract being updated, create new version
    if @mortgage_contract.published? && mortgage_contract_params[:content] != @mortgage_contract.content
      new_version = @mortgage_contract.create_new_version_if_published
      if new_version
        new_version.update!(mortgage_contract_params)
        redirect_to admin_mortgage_contracts_path, notice: 'New draft version created successfully.'
        return
      end
    end
    
    if @mortgage_contract.update(mortgage_contract_params)
      redirect_to admin_mortgage_contracts_path, notice: 'Mortgage Contract updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def publish
    @mortgage_contract.current_user = current_user # Track who published it
    if @mortgage_contract.update!(is_draft: false)
      redirect_to admin_mortgage_contracts_path, notice: 'Mortgage Contract published successfully.'
    else
      redirect_to admin_mortgage_contracts_path, alert: 'Failed to publish contract.'
    end
  end

  def activate
    @mortgage_contract.current_user = current_user # Track who activated it
    @mortgage_contract.update!(is_active: true, is_draft: false)
    redirect_to admin_mortgage_contracts_path, notice: 'Mortgage Contract activated successfully.'
  end

  def destroy
    @mortgage_contract.current_user = current_user
    @mortgage_contract.destroy!
    redirect_to admin_mortgage_contracts_path, notice: 'Mortgage Contract deleted successfully.'
  end

  def preview
    @mortgage_contract = MortgageContract.new(mortgage_contract_params)
    @mortgage_contract.last_updated = Time.current
    render layout: false
  end

  private

  def set_mortgage_contract
    @mortgage_contract = MortgageContract.find(params[:id])
  end

  def mortgage_contract_params
    params.require(:mortgage_contract).permit(:title, :content, :is_draft, :is_active)
  end
end