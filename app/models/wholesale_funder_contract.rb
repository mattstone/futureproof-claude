class WholesaleFunderContract < ApplicationRecord
  belongs_to :wholesale_funder
  
  validates :jurisdiction, presence: true, inclusion: { in: %w[AU US NZ UK] }
  validates :html_content, presence: true
  validates :party_type, presence: true
  validates :wholesale_funder_id, uniqueness: { scope: [:jurisdiction, :party_type] }
  
  scope :by_jurisdiction, ->(jurisdiction) { where(jurisdiction: jurisdiction) }
  scope :by_party_type, ->(party_type) { where(party_type: party_type) }
end
