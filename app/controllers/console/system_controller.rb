# Security overview: account lockouts, failed sign-ins, and the audited
# security-relevant actions — one page to answer "is anything odd going on?".
class Console::SystemController < Console::BaseController
  before_action -> { require_capability(:view_system) }

  SECURITY_ACTIONS = %w[user_locked user_unlocked password_reset_sent agent_action_overridden].freeze

  def security
    @locked_accounts = User.where.not(locked_at: nil).order(locked_at: :desc).limit(25)
    @failed_attempts = User.where("failed_attempts > 0").order(failed_attempts: :desc).limit(25)
    @recent_security_events = AuditLog.where(action: SECURITY_ACTIONS)
                                      .includes(:user).recent.limit(50)
    @admin_count = User.where(admin: true).count
    @sso_admin_count = User.where(admin: true).where.not(sso_provider: nil).count
  end
end
