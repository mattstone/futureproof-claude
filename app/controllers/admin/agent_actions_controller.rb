module Admin
  # Human oversight of agent decisions: an admin can override a flagged
  # agent action with a recorded reason (AI_BUILD_SPEC §6 — humans own the
  # consequential call; the reason feeds the audit trail).
  class AgentActionsController < Admin::BaseController
    def override
      action = AgentAction.find(params[:id])

      if params[:reason].blank?
        redirect_back fallback_location: admin_applications_path,
                      alert: "An override reason is required." and return
      end

      action.override!(by: current_user.display_name, reason: params[:reason])
      AuditLog.log_action(
        user: current_user,
        action: "agent_action_overridden",
        resource: action,
        reason: params[:reason]
      )
      redirect_back fallback_location: admin_applications_path,
                    notice: "Agent action overridden."
    end
  end
end
