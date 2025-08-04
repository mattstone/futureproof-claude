if Rails.env.development?
  # Add custom logging methods to all controllers
  module LoggingEnhancements
    extend ActiveSupport::Concern
    
    def log_action_info(message, **payload)
      logger.info("🎯 #{self.class.name}##{action_name}: #{message}", payload)
    end
    
    def log_user_action(user, action, **payload)
      logger.info("👤 User #{user&.email || 'Anonymous'}: #{action}", payload)
    end
    
    def log_database_action(model, action, **payload) 
      logger.info("💾 #{model}: #{action}", payload)
    end
    
    def log_email_action(to, subject, **payload)
      logger.info("📧 Email to #{to}: #{subject}", payload)
    end
  end
  
  # Include in ApplicationController
  ApplicationController.include(LoggingEnhancements) if defined?(ApplicationController)
  
  # Enhanced SQL logging
  ActiveSupport::Notifications.subscribe 'sql.active_record' do |name, started, finished, unique_id, payload|
    if Rails.env.development? && payload[:name] != 'SCHEMA'
      duration = ((finished - started) * 1000).round(2)
      
      # Color code based on query duration
      color = case duration
              when 0..10 then "\e[32m" # Green for fast queries
              when 10..100 then "\e[33m" # Yellow for medium queries  
              else "\e[31m" # Red for slow queries
              end
      
      puts "#{color}  📊 SQL (#{duration}ms): #{payload[:sql].squish}\e[0m"
    end
  end
end