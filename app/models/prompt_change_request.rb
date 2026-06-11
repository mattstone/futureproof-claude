# PromptChangeRequest — provenance pointer for a change proposed from the admin.
#
# The change itself lives on GitHub (a PR for direct prompt edits, an issue for
# plain-language change requests that Claude implements). Git is the single
# source of truth; this record exists so the admin can (a) attribute the
# proposal to a logged-in user and (b) keep the impact question and the
# answer the user gave, verbatim and permanently.
class PromptChangeRequest < ApplicationRecord
  # The canonical question shown to the proposer. Copied into impact_question
  # at creation so the record preserves exactly what was asked, even if this
  # wording changes later.
  IMPACT_QUESTION = "Does this change affect data or functionality, or only prompt wording/guidance?".freeze

  MUTABLE_AFTER_CREATE = %w[state_cache state_checked_at github_number github_type github_url updated_at].freeze

  belongs_to :user

  enum :kind, { direct_edit: 0, change_request: 1 }, prefix: true
  enum :impact_answer, {
    wording_only: 0,
    affects_functionality: 1,
    affects_data: 2,
    affects_both: 3
  }, prefix: :impact

  validates :title, presence: true, length: { maximum: 200 }
  validates :description, presence: true
  validates :impact_question, presence: true
  validates :impact_answer, presence: true
  validates :impact_details, presence: true, unless: :impact_wording_only?
  validates :target_slot, presence: true, if: :kind_direct_edit?
  validate :target_slot_is_registered, if: -> { target_slot.present? }
  validate :immutable_after_create, on: :update

  before_validation :record_impact_question, on: :create

  scope :recent_first, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :open_for_slot, ->(slot_key) { where(target_slot: slot_key).where.not(state_cache: %w[merged closed]) }

  def slot
    target_slot && PromptFiles.find_by_key(target_slot)
  end

  def github_ref
    return nil unless github_number

    "#{github_type == 'pr' ? 'PR' : 'Issue'} ##{github_number}"
  end

  def update_github_ref!(number:, type:, url:)
    update!(github_number: number, github_type: type, github_url: url,
            state_cache: "open", state_checked_at: Time.current)
  end

  def update_state!(state)
    update!(state_cache: state, state_checked_at: Time.current)
  end

  def impact_answer_label
    impact_answer.humanize
  end

  private

  def record_impact_question
    self.impact_question ||= IMPACT_QUESTION
  end

  def target_slot_is_registered
    errors.add(:target_slot, "is not a known prompt slot") unless PromptFiles.find_by_key(target_slot)
  end

  # The proposal record is an immutable account of what was asked and answered.
  # Only the GitHub linkage and cached state may change after creation.
  def immutable_after_create
    illegal = changed - MUTABLE_AFTER_CREATE
    illegal.each { |attr| errors.add(attr.to_sym, "cannot be changed after the request is recorded") }
  end
end
