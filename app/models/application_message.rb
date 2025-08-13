class ApplicationMessage < ApplicationRecord
  # include InputSanitization  # Temporarily disabled for testing
  include Messageable
  
  belongs_to :application
  # Send the message
  def send_message!
    return false unless draft?
    
    # Send email notification if it's from admin to customer
    if from_admin?
      ApplicationMailer.message_notification(self).deliver_now
    end
    
    # Only mark as sent if email sending succeeded
    update!(status: 'sent', sent_at: Time.current)
    true
  rescue => e
    Rails.logger.error "Failed to send message #{id}: #{e.message}"
    # Keep status as draft if sending failed
    false
  end
  # Get count of unread customer messages for this application
  def self.unread_customer_messages_count(application)
    customer_messages.where(application: application).unread.count
  end
  
  private
  
  # Get the user for template variable processing
  def get_user
    application.user
  end
  
  # Process application-specific template variables
  def process_resource_template_variables(text)
    processed_text = text.dup
    
    # Replace application template variables
    if application
      processed_text.gsub!(/\{\{application\.id\}\}/i, application.id.to_s)
      processed_text.gsub!(/\{\{application\.reference_number\}\}/i, application.id.to_s.rjust(6, '0'))
      processed_text.gsub!(/\{\{application\.address\}\}/i, application.address.to_s)
      processed_text.gsub!(/\{\{application\.home_value\}\}/i, application.home_value.to_s)
      processed_text.gsub!(/\{\{application\.formatted_home_value\}\}/i, application.formatted_home_value.to_s) if application.respond_to?(:formatted_home_value)
      processed_text.gsub!(/\{\{application\.existing_mortgage_amount\}\}/i, application.existing_mortgage_amount.to_s) if application.existing_mortgage_amount.present?
      processed_text.gsub!(/\{\{application\.formatted_existing_mortgage_amount\}\}/i, application.formatted_existing_mortgage_amount.to_s) if application.respond_to?(:formatted_existing_mortgage_amount)
      processed_text.gsub!(/\{\{application\.borrower_age\}\}/i, application.borrower_age.to_s) if application.borrower_age.present?
      processed_text.gsub!(/\{\{application\.status\}\}/i, application.status.to_s)
      processed_text.gsub!(/\{\{application\.status_display\}\}/i, application.status.humanize)
      
      # Add loan-related fields if they exist
      if application.respond_to?(:loan_value) && application.loan_value.present?
        processed_text.gsub!(/\{\{application\.loan_value\}\}/i, application.loan_value.to_s)
        processed_text.gsub!(/\{\{application\.formatted_loan_value\}\}/i, application.formatted_loan_value.to_s) if application.respond_to?(:formatted_loan_value)
      end
      
      if application.respond_to?(:loan_term) && application.loan_term.present?
        processed_text.gsub!(/\{\{application\.loan_term\}\}/i, application.loan_term.to_s)
      end
      
      if application.respond_to?(:growth_rate) && application.growth_rate.present?
        processed_text.gsub!(/\{\{application\.growth_rate\}\}/i, application.growth_rate.to_s)
        processed_text.gsub!(/\{\{application\.formatted_growth_rate\}\}/i, application.formatted_growth_rate.to_s) if application.respond_to?(:formatted_growth_rate)
      end
    end
    
    # Replace mortgage template variables if mortgage is associated
    if application&.mortgage
      mortgage = application.mortgage
      processed_text.gsub!(/\{\{mortgage\.name\}\}/i, mortgage.name.to_s)
      processed_text.gsub!(/\{\{mortgage\.lvr\}\}/i, mortgage.lvr.to_s) if mortgage.respond_to?(:lvr)
      processed_text.gsub!(/\{\{mortgage\.interest_rate\}\}/i, '7.45') # Static for now, same as email template
      processed_text.gsub!(/\{\{mortgage\.mortgage_type_display\}\}/i, mortgage.mortgage_type_display.to_s) if mortgage.respond_to?(:mortgage_type_display)
    end
    
    processed_text
  end
end