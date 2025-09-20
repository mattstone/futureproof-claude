class CoreLogicService
  BASE_URL = 'https://api.corelogic.asia'.freeze

  def initialize
    @client_key = Rails.application.credentials.corelogic.client_key
    @client_secret = Rails.application.credentials.corelogic.client_secret
  end

  # Get OAuth2 access token
  def get_access_token
    response = HTTParty.post(
      "#{BASE_URL}/access/as/token.oauth2?grant_type=client_credentials",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/x-www-form-urlencoded'
      },
      body: {
        client_id: @client_key,
        client_secret: @client_secret
      }
    )

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "CoreLogic Auth Error: #{response.code} - #{response.message}"
      raise "Failed to authenticate with CoreLogic API"
    end
  end

  # Search for property suggestions based on query
  def get_property_suggestions(query)
    token_data = get_access_token

    response = HTTParty.get(
      "#{BASE_URL}/property/au/v2/suggest.json",
      headers: auth_headers(token_data['access_token']),
      query: { q: query }
    )

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "CoreLogic Suggestions Error: #{response.code} - #{response.message}"

      # For testing purposes, return mock data if API access is restricted
      if response.code == 401 && (Rails.env.development? || Rails.env.test?)
        return get_mock_suggestions(query)
      end

      { error: "Failed to fetch property suggestions (HTTP #{response.code})" }
    end
  end

  # Get property address details by property ID
  def get_property_address(property_id)
    token_data = get_access_token

    response = HTTParty.get(
      "#{BASE_URL}/property-details/au/properties/#{property_id}/location",
      headers: auth_headers(token_data['access_token']),
      query: { includeHistoric: false }
    )

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "CoreLogic Address Error: #{response.code} - #{response.message}"

      # For testing purposes, return mock data if API access is restricted
      if response.code == 401 && (Rails.env.development? || Rails.env.test?)
        return get_mock_address(property_id)
      end

      { error: "Failed to fetch property address (HTTP #{response.code})" }
    end
  end

  # Get property attributes by property ID
  def get_property_attributes(property_id)
    token_data = get_access_token

    response = HTTParty.get(
      "#{BASE_URL}/property-details/au/properties/#{property_id}/attributes/core",
      headers: auth_headers(token_data['access_token'])
    )

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "CoreLogic Attributes Error: #{response.code} - #{response.message}"

      # For testing purposes, return mock data if API access is restricted
      if response.code == 401 && (Rails.env.development? || Rails.env.test?)
        return get_mock_attributes(property_id)
      end

      { error: "Failed to fetch property attributes (HTTP #{response.code})" }
    end
  end

  # Get property valuation by property ID
  def get_property_valuation(property_id)
    token_data = get_access_token

    response = HTTParty.get(
      "#{BASE_URL}/avm/au/properties/#{property_id}/avm/intellival/consumer/current",
      headers: auth_headers(token_data['access_token'])
    )

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "CoreLogic Valuation Error: #{response.code} - #{response.message}"

      # For testing purposes, return mock data if API access is restricted
      if response.code == 401 && (Rails.env.development? || Rails.env.test?)
        return get_mock_valuation(property_id)
      end

      { error: "Failed to fetch property valuation (HTTP #{response.code})" }
    end
  end

  # Get property images by property ID
  def get_property_images(property_id)
    token_data = get_access_token

    response = HTTParty.get(
      "#{BASE_URL}/property-details/au/properties/#{property_id}/images/default",
      headers: auth_headers(token_data['access_token'])
    )

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "CoreLogic Images Error: #{response.code} - #{response.message}"

      # For testing purposes, return mock data if API access is restricted
      if response.code == 401 && (Rails.env.development? || Rails.env.test?)
        return get_mock_images(property_id)
      end

      { error: "Failed to fetch property images (HTTP #{response.code})" }
    end
  end

  # Get complete property details (address, attributes, valuation, images)
  def get_complete_property_details(property_id)
    {
      address: get_property_address(property_id),
      attributes: get_property_attributes(property_id),
      valuation: get_property_valuation(property_id),
      images: get_property_images(property_id)
    }
  rescue => e
    Rails.logger.error "CoreLogic Complete Details Error: #{e.message}"
    { error: 'Failed to fetch complete property details' }
  end

  private

  def auth_headers(token)
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  end

  # Mock data for testing when API access is restricted
  def get_mock_suggestions(query)
    return [] if query.blank?

    [
      {
        'suggestion' => "#{query.split.first} Collins Street, Melbourne VIC 3000",
        'property_id' => '12345678',
        'suggestion_type' => 'Property',
        'is_active_property' => true,
        'is_unit' => false,
        'is_body_corporate' => false
      },
      {
        'suggestion' => "Unit 1/#{query.split.first} Collins Street, Melbourne VIC 3000",
        'property_id' => '12345679',
        'suggestion_type' => 'Unit',
        'is_active_property' => true,
        'is_unit' => true,
        'is_body_corporate' => true
      },
      {
        'suggestion' => "#{query.split.first} #{query.split[1] || 'Street'} Street, Melbourne VIC 3001",
        'property_id' => '12345680',
        'suggestion_type' => 'Property',
        'is_active_property' => false,
        'is_unit' => false,
        'is_body_corporate' => false
      }
    ]
  end

  def get_mock_address(property_id)
    {
      'single_line' => '123 Collins Street, Melbourne VIC 3000',
      'street' => {
        'name_and_number' => '123 Collins Street',
        'name' => 'Collins Street'
      },
      'locality' => {
        'name' => 'Melbourne'
      },
      'postcode' => {
        'name' => '3000'
      },
      'state' => 'VIC',
      'council_area' => 'Melbourne',
      'latitude' => -37.8136,
      'longitude' => 144.9631,
      'is_active_property' => true
    }
  end

  def get_mock_attributes(property_id)
    {
      'property_type' => 'Apartment',
      'property_sub_type' => 'Unit',
      'beds' => 2,
      'baths' => 1,
      'car_spaces' => 1,
      'lock_up_garages' => 0,
      'land_area' => 85,
      'is_calculated_land_area' => false,
      'is_active_property' => true
    }
  end

  def get_mock_valuation(property_id)
    {
      'estimate' => 750000,
      'low_estimate' => 675000,
      'high_estimate' => 825000,
      'confidence' => 'Medium',
      'fsd' => 50000,
      'valuation_date' => Date.current.to_s
    }
  end

  def get_mock_images(property_id)
    [
      {
        'digital_asset_type' => 'Image',
        'base_photo_url' => 'https://via.placeholder.com/400x300/0066CC/FFFFFF?text=Property+Image+1',
        'medium_photo_url' => 'https://via.placeholder.com/400x300/0066CC/FFFFFF?text=Property+Image+1',
        'large_photo_url' => 'https://via.placeholder.com/800x600/0066CC/FFFFFF?text=Property+Image+1',
        'thumbnail_photo_url' => 'https://via.placeholder.com/150x150/0066CC/FFFFFF?text=Thumb+1',
        'scan_date' => Date.current.to_s,
        'is_active_property' => true
      },
      {
        'digital_asset_type' => 'Image',
        'base_photo_url' => 'https://via.placeholder.com/400x300/006633/FFFFFF?text=Property+Image+2',
        'medium_photo_url' => 'https://via.placeholder.com/400x300/006633/FFFFFF?text=Property+Image+2',
        'large_photo_url' => 'https://via.placeholder.com/800x600/006633/FFFFFF?text=Property+Image+2',
        'thumbnail_photo_url' => 'https://via.placeholder.com/150x150/006633/FFFFFF?text=Thumb+2',
        'scan_date' => Date.current.to_s,
        'is_active_property' => true
      }
    ]
  end
end