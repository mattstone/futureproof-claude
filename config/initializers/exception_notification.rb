# Only configure exception notification when not in build process
if Rails.application.initialized? || !defined?(Rails::Server)
  Rails.application.configure do
    # Exception notification configuration for production error emails
    config.middleware.use ExceptionNotification::Rack,
      ignore_exceptions: [
        'ActionController::RoutingError',
        'ActionController::InvalidAuthenticityToken',
        'CGI::Session::CookieStore::TamperedWithCookie',
        'ActionController::InvalidCrossOriginRequest',
        'ActionDispatch::Http::MimeNegotiation::InvalidType',
        'Rack::QueryParser::ParameterTypeError',
        'Rack::QueryParser::InvalidParameterError',
        'ActionController::BadRequest',
        'ActionController::UnknownHttpMethod',
        'ActionDispatch::Http::Parameters::ParseError'
      ],
      
      email: {
        # Email details
        email_prefix: "[Futureproof ERROR] ",
        sender_address: %("Futureproof Error Monitor" <errors@futureprooffinancial.co>),
        exception_recipients: %w[matt.stone@futureprooffinancial.co],
        
        # Email format options
        deliver_with: :deliver_now,
        email_format: :html,
        
        # Include additional information
        sections: %w[request session environment backtrace],
        background_sections: %w[backtrace data],
        
        # Email template customization
        email_headers: {
          'X-Priority' => '1',
          'X-MSMail-Priority' => 'High',
          'X-Mailer' => 'Futureproof Error Notification System'
        },
        
        # Normalize subject line
        normalize_subject: true,
        
        # Use Rails default mailer settings (safely access config)
        delivery_method: (Rails.application.config.action_mailer.delivery_method rescue :smtp),
        
        # Verbose subject line
        verbose_subject: true
      }
  end
end