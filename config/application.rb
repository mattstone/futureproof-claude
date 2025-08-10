require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Futureproof
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    
    # Enable Rack::Attack for rate limiting and security
    config.middleware.use Rack::Attack
    
    # Force SSL in production
    config.force_ssl = Rails.env.production?
    
    # Session security
    config.session_store :cookie_store, 
      key: '_futureproof_session',
      secure: Rails.env.production?,
      httponly: true,
      expire_after: 4.hours,
      same_site: :strict
  end
end
