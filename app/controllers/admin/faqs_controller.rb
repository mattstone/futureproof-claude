module Admin
  class FaqsController < BaseController
    before_action :set_faq, only: [:edit, :update, :destroy]

    def index
      current_jurisdiction = session[:admin_jurisdiction] || "Summary"

      @faqs = Faq.all
      unless current_jurisdiction == "Summary"
        @faqs = @faqs.where(jurisdiction: current_jurisdiction)
      end

      @faqs = @faqs.ordered
      @is_summary = current_jurisdiction == "Summary"

      @total_faqs = @faqs.count
      @published_faqs = @faqs.where(published: true).count
      @draft_faqs = @total_faqs - @published_faqs
    end

    def new
      @faq = Faq.new
      @faq.jurisdiction = session[:admin_jurisdiction] unless session[:admin_jurisdiction] == "Summary"
    end

    def create
      @faq = Faq.new(faq_params)

      if @faq.save
        redirect_to admin_faqs_path, notice: "FAQ created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @faq.update(faq_params)
        redirect_to admin_faqs_path, notice: "FAQ updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @faq.destroy
      redirect_to admin_faqs_path, notice: "FAQ deleted."
    end

    def reorder
      raw_ids = params[:faq_ids]
      if raw_ids.present?
        ids = raw_ids.is_a?(String) ? raw_ids.split(",") : Array(raw_ids)
        ids.each_with_index do |id, index|
          Faq.where(id: id).update_all(position: index)
        end
      end
      head :ok
    end

    private

    def set_faq
      @faq = Faq.find(params[:id])
    end

    def faq_params
      params.require(:faq).permit(:jurisdiction, :question, :answer, :published)
    end
  end
end
