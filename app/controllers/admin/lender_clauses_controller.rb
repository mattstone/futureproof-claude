class Admin::LenderClausesController < Admin::BaseController
  before_action :set_lender

  def new
    # For singleton, we redirect to edit if clause already exists
    if @lender.has_clause?
      redirect_to edit_admin_lender_clause_path(@lender)
      return
    end
    
    @clause_content = @lender.clause_content
  end

  def create
    @lender.clause_content = clause_params[:content]
    
    if @lender.save
      redirect_back_or_fallback(notice: 'Clause was successfully created.')
    else
      @clause_content = clause_params[:content]
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # For singleton, handle the case where no clause exists yet
    @clause_content = @lender.clause_content
  end

  def update
    had_clause = @lender.has_clause?
    @lender.clause_content = clause_params[:content]
    
    if @lender.save
      action_word = had_clause ? 'updated' : 'created'
      redirect_back_or_fallback(notice: "Clause was successfully #{action_word}.")
    else
      @clause_content = clause_params[:content]
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @lender.clause_content = ""
    @lender.save!
    redirect_back_or_fallback(notice: 'Clause was successfully deleted.')
  end

  private

  def set_lender
    @lender = Lender.find(params[:lender_id])
  end

  def clause_params
    params.require(:clause).permit(:content)
  end

  def redirect_back_or_fallback(options = {})
    if request.referer && request.referer.include?('mortgages')
      redirect_back(fallback_location: admin_lenders_path, **options)
    else
      redirect_to admin_lender_path(@lender), **options
    end
  end
end