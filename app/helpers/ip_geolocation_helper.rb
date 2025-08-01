require 'net/http'
require 'json'

module IpGeolocationHelper
  def get_location_for_ip(ip_address)
    return nil if ip_address.blank?
    
    # Skip for localhost/development IPs
    return nil if ip_address.in?(['127.0.0.1', '::1', '0.0.0.0'])
    
    # Skip for private IP ranges
    return nil if private_ip?(ip_address)
    
    begin
      # Use a free IP geolocation service (ip-api.com)
      # Note: This has rate limits, consider upgrading for production use
      uri = URI("http://ip-api.com/json/#{ip_address}")
      response = Net::HTTP.get_response(uri)
      
      return nil unless response.code == '200'
      
      data = JSON.parse(response.body)
      
      if data['status'] == 'success'
        location_parts = []
        location_parts << data['city'] if data['city'].present?
        location_parts << data['regionName'] if data['regionName'].present?
        location_parts << data['country'] if data['country'].present?
        
        return location_parts.join(', ') if location_parts.any?
      end
      
      nil
    rescue => e
      Rails.logger.warn "Failed to get location for IP #{ip_address}: #{e.message}"
      nil
    end
  end

  private

  def private_ip?(ip_address)
    # Check if IP is in private ranges
    private_ranges = [
      /^10\./,                    # 10.0.0.0/8
      /^172\.(1[6-9]|2\d|3[01])\./, # 172.16.0.0/12
      /^192\.168\./,              # 192.168.0.0/16
      /^169\.254\./,              # 169.254.0.0/16 (link-local)
      /^fe80:/i,                  # IPv6 link-local
      /^::1$/,                    # IPv6 loopback
      /^fc[0-9a-f]{2}:/i,         # IPv6 unique local
      /^fd[0-9a-f]{2}:/i          # IPv6 unique local
    ]
    
    private_ranges.any? { |range| ip_address.match?(range) }
  end
end