class Faq < ApplicationRecord
  JURISDICTIONS = %w[AU NZ UK US].freeze

  validates :jurisdiction, presence: true, inclusion: { in: JURISDICTIONS }
  validates :question, presence: true
  validates :answer, presence: true

  scope :ordered, -> { order(position: :asc) }
  scope :published, -> { where(published: true) }
  scope :for_jurisdiction, ->(j) { where(jurisdiction: j) }

  before_create :set_position

  private

  def set_position
    self.position = (Faq.where(jurisdiction: jurisdiction).maximum(:position) || -1) + 1
  end
end
