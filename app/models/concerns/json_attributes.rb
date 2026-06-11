# Concern for safe JSON attribute parsing with error handling and defaults
# Usage in model:
#   class Application < ApplicationRecord
#     include JsonAttributes
#     json_attribute :property_images, default: []
#     json_attribute :corelogic_data, default: {}, aliases: [:corelogic_property_data, :corelogic_data_hash]
module JsonAttributes
  extend ActiveSupport::Concern

  included do
    # Helper to safely parse JSON with default value
    # Logs errors and returns default if JSON is invalid
    def self.json_attribute(attr_name, default: nil, aliases: [])
      define_method("#{attr_name}_parsed") do
        value = send(attr_name)
        return default unless value.present?

        begin
          JSON.parse(value)
        rescue JSON::ParserError => e
          Rails.logger.warn("Failed to parse #{attr_name}: #{e.message}")
          default
        end
      end

      # Create main alias (e.g., property_images → property_images_parsed)
      alias_method :"#{attr_name}_array", :"#{attr_name}_parsed"
      
      # Create backward compatibility aliases
      aliases.each do |alias_name|
        alias_method alias_name, :"#{attr_name}_parsed"
      end
    end
  end
end
