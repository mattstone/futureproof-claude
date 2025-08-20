class Admin::ContractClausesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_user!
  before_action :set_mortgage_and_contract
  before_action :set_clause_position, only: [:create]

  def create
    @lender_clause = LenderClause.find(params[:lender_clause_id])
    
    begin
      @contract.add_lender_clause(@lender_clause, @clause_position, current_user)
      
      respond_to do |format|
        format.turbo_stream { 
          flash.now[:notice] = "Clause '#{@lender_clause.title}' was successfully added to the contract."
          render :create 
        }
        format.html { 
          redirect_to admin_mortgage_path(@mortgage), notice: "Clause '#{@lender_clause.title}' was successfully added to the contract."
        }
      end
    rescue => e
      respond_to do |format|
        format.turbo_stream { 
          flash.now[:alert] = "Failed to add clause: #{e.message}"
          render :create_error 
        }
        format.html { 
          redirect_to admin_mortgage_path(@mortgage), alert: "Failed to add clause: #{e.message}"
        }
      end
    end
  end

  def destroy
    @clause_position = ClausePosition.find(params[:clause_position_id])
    
    begin
      @contract.remove_lender_clause(@clause_position, current_user)
      
      respond_to do |format|
        format.turbo_stream { 
          flash.now[:notice] = "Clause was successfully removed from the contract."
          render :destroy 
        }
        format.html { 
          redirect_to admin_mortgage_path(@mortgage), notice: "Clause was successfully removed from the contract."
        }
      end
    rescue => e
      respond_to do |format|
        format.turbo_stream { 
          flash.now[:alert] = "Failed to remove clause: #{e.message}"
          render :destroy_error 
        }
        format.html { 
          redirect_to admin_mortgage_path(@mortgage), alert: "Failed to remove clause: #{e.message}"
        }
      end
    end
  end

  def available_clauses
    @lender = Lender.find(params[:lender_id])
    @clause_position = ClausePosition.find(params[:clause_position_id])
    
    # Get active clauses for this lender that aren't already in use at this position
    existing_usage = @contract.active_contract_clause_usages.find_by(clause_position: @clause_position)
    @available_clauses = @lender.active_lender_clauses.published
    
    respond_to do |format|
      format.turbo_stream { render :available_clauses }
    end
  end

  private

  def set_mortgage_and_contract
    @mortgage = Mortgage.find(params[:mortgage_id])
    @contract = @mortgage.mortgage_contracts.find(params[:mortgage_contract_id])
  end

  def set_clause_position
    @clause_position = ClausePosition.find(params[:clause_position_id])
  end

  def ensure_admin_user!
    redirect_to root_path, alert: 'Access denied.' unless current_user&.admin?
  end
end