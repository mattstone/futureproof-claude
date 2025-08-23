# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets for email templates
Rails.application.config.assets.precompile += %w( email.css )

# Precompile game stylesheets
Rails.application.config.assets.precompile += %w( hackman.css honky_pong.css lace_invaders.css arcade.css )

# Configure proper MIME types for JavaScript modules
Rack::Mime::MIME_TYPES['.js'] = 'application/javascript'

# Precompile JavaScript modules for proper serving
Rails.application.config.assets.precompile += %w( honky_pong.js audio_manager.js hackman.js )
