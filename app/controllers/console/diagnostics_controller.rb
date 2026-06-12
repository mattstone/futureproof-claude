# One diagnostics page absorbing the legacy core_logic_test and error_test
# pages: CoreLogic property-search probe + production error-notification
# triggers.
class Console::DiagnosticsController < Console::BaseController
  before_action -> { require_capability(:run_diagnostics) }

  def show
  end

  def core_logic_search
    query = params[:query]

    if query.blank?
      redirect_to console_diagnostics_path, alert: "Enter a search query first." and return
    end

    begin
      @query = query
      @suggestions = CoreLogicService.new.get_property_suggestions(query)

      if @suggestions.is_a?(Hash) && @suggestions["error"]
        flash.now[:alert] = @suggestions["error"]
        @suggestions = nil
      end
    rescue => e
      Rails.logger.error "CoreLogic Search Error: #{e.message}"
      flash.now[:alert] = "Error searching properties: #{e.message}"
      @suggestions = nil
    end

    render :show
  end

  def property_details
    property_id = params[:property_id]

    if property_id.blank?
      redirect_to console_diagnostics_path, alert: "Enter a property ID first." and return
    end

    begin
      @property_id = property_id
      @property_details = CoreLogicService.new.get_complete_property_details(property_id)

      if @property_details.is_a?(Hash) && @property_details["error"]
        flash.now[:alert] = @property_details["error"]
        @property_details = nil
      end
    rescue => e
      Rails.logger.error "CoreLogic Property Details Error: #{e.message}"
      flash.now[:alert] = "Error fetching property details: #{e.message}"
      @property_details = nil
    end

    render :show
  end

  # Raises a real error so the exception-notification pipeline can be
  # verified end-to-end. Production-only, audit-logged, like the legacy page.
  def test_error
    unless Rails.env.production?
      redirect_to console_diagnostics_path, alert: "Error testing is only available in production." and return
    end

    Rails.logger.info "Error notification test triggered by admin: #{current_user.email}"
    raise StandardError, "TEST ERROR NOTIFICATION - #{Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')} - Triggered by admin: #{current_user.email}"
  end
end
