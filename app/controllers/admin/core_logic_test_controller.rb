class Admin::CoreLogicTestController < Admin::BaseController
  def index
    # Show the search form
  end

  def search
    query = params[:query]

    if query.blank?
      redirect_to admin_core_logic_test_index_path, alert: 'Please enter a search query'
      return
    end

    begin
      @core_logic = CoreLogicService.new
      @suggestions = @core_logic.get_property_suggestions(query)

      if @suggestions.is_a?(Hash) && @suggestions['error']
        flash.now[:alert] = @suggestions['error']
        @suggestions = nil
      end
    rescue => e
      Rails.logger.error "CoreLogic Search Error: #{e.message}"
      flash.now[:alert] = "Error searching properties: #{e.message}"
      @suggestions = nil
    end
  end

  # JSON endpoint for dynamic autocomplete
  def autocomplete
    query = params[:query]

    if query.blank? || query.length < 3
      render json: []
      return
    end

    begin
      @core_logic = CoreLogicService.new
      suggestions = @core_logic.get_property_suggestions(query)

      if suggestions.is_a?(Array)
        # Format suggestions for autocomplete
        formatted_suggestions = suggestions.map do |suggestion|
          {
            id: suggestion['property_id'] || suggestion['propertyId'],
            text: suggestion['suggestion'],
            property_type: suggestion['suggestion_type'] || suggestion['suggestionType'],
            is_active: suggestion['is_active_property'] || suggestion['isActiveProperty'],
            is_unit: suggestion['is_unit'] || suggestion['isUnit']
          }
        end
        render json: formatted_suggestions
      else
        render json: []
      end
    rescue => e
      Rails.logger.error "CoreLogic Autocomplete Error: #{e.message}"
      render json: { error: e.message }, status: 500
    end
  end

  def property_details
    property_id = params[:property_id]

    if property_id.blank?
      redirect_to admin_core_logic_test_index_path, alert: 'Property ID is required'
      return
    end

    begin
      @core_logic = CoreLogicService.new
      @property_details = @core_logic.get_complete_property_details(property_id)
      @property_id = property_id

      if @property_details.is_a?(Hash) && @property_details['error']
        flash.now[:alert] = @property_details['error']
        @property_details = nil
      end
    rescue => e
      Rails.logger.error "CoreLogic Property Details Error: #{e.message}"
      flash.now[:alert] = "Error fetching property details: #{e.message}"
      @property_details = nil
    end
  end

  private

  def core_logic_test_params
    params.permit(:query, :property_id)
  end
end