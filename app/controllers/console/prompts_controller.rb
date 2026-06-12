# Read-only browser over the prompt files in docs/prompts/.
#
# What is shown here is exactly what is deployed — the files in this
# container ARE the single source of truth. Changes are proposed via
# PromptChangeRequests (GitHub PRs/issues) and arrive here only after the
# CTO merges and the merge deploys.
class Console::PromptsController < Console::BaseController
  before_action -> { require_capability(:publish_prompts) }

  def index
    @layers = PromptFiles::LAYERS.index_with { |layer| PromptFiles.slots_for(layer) }
    @open_request_counts = PromptChangeRequest
                           .where.not(target_slot: nil)
                           .where.not(state_cache: %w[merged closed])
                           .group(:target_slot).count
  end

  def show
    @slot = PromptFiles.find_by_key(params[:key])
    unless @slot
      redirect_to console_prompts_path, alert: "Unknown prompt slot."
      return
    end

    @content = PromptFiles.read(@slot.layer, @slot.key)
    @sha = PromptFiles.sha(@slot.layer, @slot.key)
    @requests = PromptChangeRequest.where(target_slot: @slot.key).recent_first.limit(20)
  end
end
