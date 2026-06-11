module Admin
  # Change proposals from business users. Two kinds:
  #   direct_edit    — edited prompt text  -> GithubBridge opens a PR
  #   change_request — plain-language ask  -> GithubBridge opens an issue,
  #                    which the Claude Code GitHub Action implements as a draft PR
  #
  # Proposing is open to every admin: nothing reaches production without the
  # CTO merging on GitHub (merge = deploy). The local record immutably keeps
  # who asked for what, and the impact question + answer, verbatim.
  class PromptChangeRequestsController < Admin::BaseController
    def index
      @requests = PromptChangeRequest.includes(:user).recent_first.page(params[:page]).per(25)
    end

    def show
      @request = PromptChangeRequest.includes(:user).find(params[:id])
    end

    def new
      @request = PromptChangeRequest.new(
        kind: params[:kind] == "direct_edit" ? :direct_edit : :change_request,
        target_slot: params[:slot]
      )
      prefill_content if @request.kind_direct_edit?
    end

    def create
      @request = PromptChangeRequest.new(request_params)
      @request.user = current_user

      unless @request.save
        flash.now[:alert] = "Please fix the highlighted fields."
        render :new, status: :unprocessable_entity
        return
      end

      submit_to_github(@request)
    rescue GithubBridge::NotConfiguredError
      @request.destroy
      flash.now[:alert] = "GitHub bridge is not configured yet. Ask the CTO to set github_bridge credentials."
      render :new, status: :unprocessable_entity
    rescue GithubBridge::BridgeError => e
      @request.destroy
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    def refresh
      @request = PromptChangeRequest.find(params[:id])
      if @request.github_number
        state = GithubBridge.new.fetch_state(github_type: @request.github_type,
                                             github_number: @request.github_number)
        @request.update_state!(state)
      end
      redirect_to admin_prompt_change_request_path(@request), notice: "Status refreshed."
    rescue GithubBridge::BridgeError => e
      redirect_to admin_prompt_change_request_path(@request), alert: e.message
    end

    private

    def submit_to_github(request)
      bridge = GithubBridge.new
      impact = { answer: request.impact_answer, details: request.impact_details }

      result =
        if request.kind_direct_edit?
          bridge.propose_prompt_edit(
            user: current_user,
            slot: request.slot,
            new_content: request.description,
            title: request.title,
            impact: impact
          )
        else
          bridge.propose_change_request(
            user: current_user,
            title: request.title,
            description: request.description,
            impact: impact
          )
        end

      request.update_github_ref!(number: result[:number], type: result[:type], url: result[:url])
      redirect_to admin_prompt_change_request_path(request),
                  notice: "Submitted — #{request.github_ref} is awaiting the CTO's review. Nothing changes until it is merged and deployed."
    end

    def prefill_content
      slot = @request.slot
      @request.description ||= slot && PromptFiles.read(slot.layer, slot.key)
    end

    def request_params
      params.require(:prompt_change_request).permit(
        :kind, :target_slot, :title, :description, :impact_answer, :impact_details
      )
    end
  end
end
