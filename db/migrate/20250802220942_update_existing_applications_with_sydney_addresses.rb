class UpdateExistingApplicationsWithSydneyAddresses < ActiveRecord::Migration[8.0]
  def up
    # Random Sydney addresses for demonstration purposes
    sydney_addresses = [
      "15 Circular Quay West, Sydney NSW 2000",
      "42 Kent Street, Sydney NSW 2000", 
      "128 George Street, The Rocks NSW 2000",
      "73 Miller Street, North Sydney NSW 2060",
      "91 Pittwater Road, Manly NSW 2095",
      "156 Oxford Street, Paddington NSW 2021",
      "234 Crown Street, Surry Hills NSW 2010",
      "67 Victoria Road, Drummoyne NSW 2047",
      "445 Pacific Highway, Crows Nest NSW 2065",
      "182 Blues Point Road, McMahons Point NSW 2060",
      "298 Military Road, Neutral Bay NSW 2089",
      "76 Anzac Parade, Kensington NSW 2033",
      "523 King Street, Newtown NSW 2042",
      "145 Glebe Point Road, Glebe NSW 2037",
      "287 Darling Street, Balmain NSW 2041",
      "94 Norton Street, Leichhardt NSW 2040",
      "367 Cleveland Street, Redfern NSW 2016",
      "189 Bondi Road, Bondi NSW 2026",
      "256 Campbell Parade, Bondi Beach NSW 2026",
      "412 Bourke Street, Darlinghurst NSW 2010",
      "78 Liverpool Street, Sydney NSW 2000",
      "345 Pitt Street, Sydney NSW 2000",
      "123 Macquarie Street, Sydney NSW 2000",
      "567 Elizabeth Street, Surry Hills NSW 2010",
      "89 King Street, Sydney NSW 2000"
    ]
    
    # Update existing applications with random Sydney addresses
    Application.find_each do |application|
      if application.address.blank? || application.address == "Placeholder - to be updated by user"
        application.update_column(:address, sydney_addresses.sample)
      end
    end
  end

  def down
    # This migration is not reversible since we're updating demo data
    # but we can set them back to placeholder if needed
    Application.update_all(address: "Placeholder - to be updated by user")
  end
end
