# Production Error Notifications

This document describes the error notification system configured for the Futureproof application.

## Overview

When errors or crashes occur in production, the system automatically sends detailed email notifications to designated recipients. This ensures critical issues are immediately visible and can be addressed promptly.

## Configuration

### Recipient
- **Email**: matt.stone@futureprooffinancial.co
- **Purpose**: Immediate notification of production errors

### Error Notification Gem
- **Gem**: `exception_notification`
- **Configuration**: `config/initializers/exception_notification.rb`
- **Environment**: Production only

## Email Details

### Email Format
- **Subject**: `[Futureproof ERROR] {ExceptionType} in {Controller#Action} ({URL}) [{Timestamp}]`
- **Format**: HTML for better readability
- **Priority**: High (X-Priority: 1)
- **Sender**: "Futureproof Error Monitor" <errors@futureprooffinancial.co>

### Information Included
- **Exception Details**: Type, message, and full backtrace
- **Request Information**: URL, parameters, headers, user agent
- **Session Data**: User session information (if applicable)
- **Environment**: Server environment variables
- **Timestamp**: Exact time of error occurrence
- **Controller/Action**: Where the error occurred

## Filtered Exceptions

The following exceptions are **NOT** sent via email (considered normal traffic):
- `ActionController::RoutingError` - Invalid routes
- `ActionController::InvalidAuthenticityToken` - CSRF token issues
- `CGI::Session::CookieStore::TamperedWithCookie` - Cookie tampering
- `ActionController::InvalidCrossOriginRequest` - CORS issues
- `ActionDispatch::Http::MimeNegotiation::InvalidType` - Invalid content types
- `Rack::QueryParser::ParameterTypeError` - Invalid parameters
- `Rack::QueryParser::InvalidParameterError` - Malformed parameters

## Critical Exceptions (WILL Send Emails)

- `StandardError` - General application errors
- `RuntimeError` - Runtime failures
- `NoMethodError` - Method not found errors
- `ArgumentError` - Invalid arguments
- `ActiveRecord::RecordNotFound` - Database record issues
- `ActionController::UnknownFormat` - Unsupported formats
- `ActionView::Template::Error` - View rendering errors
- `ActiveRecord::StatementInvalid` - Database query errors

## SMTP Configuration

### Production Settings
The system uses SMTP for email delivery with the following configuration:

```ruby
config.action_mailer.smtp_settings = {
  user_name: Rails.application.credentials.dig(:smtp, :user_name),
  password: Rails.application.credentials.dig(:smtp, :password),
  address: "smtp.gmail.com",  # Default, configurable
  port: 587,
  authentication: :plain,
  enable_starttls_auto: true,
  domain: 'futureprooffinancial.co'
}
```

### Credential Configuration
SMTP credentials can be configured via:

1. **Rails Credentials** (Recommended):
   ```bash
   rails credentials:edit
   ```
   Add:
   ```yaml
   smtp:
     user_name: your_smtp_username
     password: your_smtp_password
     address: smtp.your-provider.com
     port: 587
   ```

2. **Environment Variables** (Alternative):
   ```bash
   export SMTP_USERNAME="your_smtp_username"
   export SMTP_PASSWORD="your_smtp_password"
   export SMTP_ADDRESS="smtp.your-provider.com"
   export SMTP_PORT="587"
   ```

## Testing

### Quick Test Script
Run the simple test to verify configuration:
```bash
ruby test/simple_error_notification_test.rb
```

### Comprehensive Test Script  
Run the full error notification test to verify configuration:
```bash
ruby test/error_notification_test.rb
```

### Manual Testing
To test error notifications in production:

1. **Temporary Test Route** (Remove after testing):
   ```ruby
   # Add to routes.rb temporarily
   get '/test_error', to: 'application#test_error' if Rails.env.production?
   
   # Add to ApplicationController temporarily
   def test_error
     raise StandardError, "Test error notification - #{Time.current}"
   end
   ```

2. **Visit the test route**: `https://your-domain.com/test_error`
3. **Check email**: Matt should receive an error notification
4. **Remove test code** immediately after verification

## Monitoring

### What to Monitor
- **Email delivery**: Ensure SMTP credentials remain valid
- **Error frequency**: High error rates may indicate systemic issues
- **Error types**: Recurring specific errors need investigation
- **Response time**: Critical errors should be addressed within 1 hour

### Maintenance
- **Quarterly review**: Check if recipient list needs updates
- **SMTP credentials**: Rotate credentials annually
- **Filter updates**: Adjust ignored exceptions based on experience

## Troubleshooting

### Common Issues

1. **No emails received**:
   - Check SMTP credentials in Rails credentials
   - Verify SMTP server settings
   - Check spam/junk folders
   - Test email delivery with: `rails console` → `ActionMailer::Base.mail(...).deliver_now`

2. **Too many emails**:
   - Review ignored exceptions list
   - Add frequently occurring non-critical errors to ignore list
   - Consider rate limiting for repeated errors

3. **Missing error details**:
   - Check sections configuration in initializer
   - Verify middleware is properly loaded
   - Check Rails log level settings

### Email Delivery Verification
```ruby
# In Rails console
begin
  raise StandardError, "Test error notification"
rescue => e
  ExceptionNotifier.notify_exception(e, env: {})
end
```

## Security Considerations

- **Sensitive Data**: Error emails may contain sensitive information from request parameters
- **Access Control**: Only authorized personnel should have access to error notification emails
- **Retention**: Consider email retention policies for error notifications
- **Credentials**: Keep SMTP credentials secure and rotate regularly

## Support

For issues with error notifications:
1. Check server logs for SMTP delivery errors
2. Verify email server connectivity
3. Test with simplified configuration
4. Contact system administrator if SMTP issues persist

---

**Last Updated**: January 2024  
**Next Review**: April 2024  
**Owner**: Development Team  
**Recipient**: Matt Stone (matt.stone@futureprooffinancial.co)