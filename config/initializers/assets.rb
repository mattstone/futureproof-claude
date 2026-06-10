# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Ensure Lexxy gem assets are in the asset load path
if defined?(Lexxy::Engine)
  Rails.application.config.assets.paths << Lexxy::Engine.root.join("app/assets/stylesheets")
  Rails.application.config.assets.paths << Lexxy::Engine.root.join("app/assets/javascript")
end
