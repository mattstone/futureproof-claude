module Admin
  class AuditLogsController < Admin::BaseController
    def index
      logs = AuditLog.includes(:user, :application).recent
      logs = logs.by_user(params[:user_id]) if params[:user_id].present?
      logs = logs.by_action(params[:action_filter]) if params[:action_filter].present?
      logs = logs.by_resource(params[:resource_type]) if params[:resource_type].present?
      logs = logs.where("created_at >= ?", params[:from]) if params[:from].present?
      logs = logs.where("created_at <= ?", params[:to]) if params[:to].present?

      @logs = logs.page(params[:page]).per(50)
      @actions = AuditLog.distinct.pluck(:action).compact.sort
      @resource_types = AuditLog.distinct.pluck(:resource_type).compact.sort
    end

    def show
      @log = AuditLog.includes(:user, :application).find(params[:id])
      @parsed_changes = @log.parse_changes
    end
  end
end
