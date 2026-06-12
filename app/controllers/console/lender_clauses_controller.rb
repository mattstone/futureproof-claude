# Singleton custom clause per lender (injected into mortgage contracts).
class Console::LenderClausesController < Console::BaseController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_lender

  def edit
    @clause_content = @lender.clause_content
  end

  def update
    had_clause = @lender.has_clause?
    @lender.clause_content = clause_params[:content]

    if @lender.save
      redirect_to console_lender_path(@lender), notice: "Clause #{had_clause ? 'updated' : 'created'}."
    else
      @clause_content = clause_params[:content]
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_lender
    @lender = Lender.find(params[:lender_id])
  end

  def clause_params
    params.require(:clause).permit(:content)
  end
end
