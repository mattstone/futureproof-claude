Recaptcha.configure do |config|
  config.site_key = ENV['RECAPTCHA_SITE_KEY'] || Rails.application.credentials.recaptcha&.site_key
  config.secret_key = ENV['RECAPTCHA_SECRET_KEY'] || Rails.application.credentials.recaptcha&.secret_key
  
  # Uncomment the following line if you are using a proxy server:
  # config.proxy = 'http://myproxy.com.au:8080'
  
  # Uncomment the following lines if you are using the Enterprise API:
  # config.enterprise = true
  # config.enterprise_api_key = ENV['RECAPTCHA_ENTERPRISE_API_KEY']
  # config.enterprise_project_id = ENV['RECAPTCHA_ENTERPRISE_PROJECT_ID']
end