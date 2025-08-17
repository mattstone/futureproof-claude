class Admin::ErrorTestController < Admin::BaseController
  before_action :ensure_futureproof_admin
  
  # SECURITY: This controller should only be available to futureproof admins
  # and only used for testing error notifications in production
  
  def show
    render plain: "Error notification test page. Click 'Test Error' to trigger a test error notification."
  end
  
  def test_error
    # Only allow in production and only for futureproof admins
    unless Rails.env.production?
      redirect_to admin_root_path, alert: "Error testing only available in production"
      return
    end
    
    # Log the test for audit purposes
    Rails.logger.info "Error notification test triggered by admin: #{current_user&.email || 'unknown'}"
    
    # Raise a test error that will trigger email notification
    raise StandardError, "TEST ERROR NOTIFICATION - #{Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')} - Triggered by admin: #{current_user&.email || 'unknown'}"
  end
  
  def test_database_error
    unless Rails.env.production?
      redirect_to admin_root_path, alert: "Error testing only available in production"
      return
    end
    
    Rails.logger.info "Database error notification test triggered by admin: #{current_user&.email || 'unknown'}"
    
    # Trigger a database error for testing
    ActiveRecord::Base.connection.execute("SELECT * FROM non_existent_table_for_testing")
  end
  
  def test_view_error
    unless Rails.env.production?
      redirect_to admin_root_path, alert: "Error testing only available in production"  
      return
    end
    
    Rails.logger.info "View error notification test triggered by admin: #{current_user&.email || 'unknown'}"
    
    # This will cause a view error
    render template: 'non_existent_template'
  end
end