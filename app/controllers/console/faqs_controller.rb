class Console::FaqsController < Console::BaseController
  before_action -> { require_capability(:manage_product) }
  before_action :set_faq, only: [ :edit, :update ]

  def index
    @faqs = Faq.all
    @faqs = @faqs.where(jurisdiction: current_jurisdiction) unless current_jurisdiction == "Summary"
    @faqs = @faqs.ordered

    @total_faqs = @faqs.count
    @published_faqs = @faqs.where(published: true).count
    @draft_faqs = @total_faqs - @published_faqs
  end

  def new
    @faq = Faq.new
    @faq.jurisdiction = current_jurisdiction unless current_jurisdiction == "Summary"
  end

  def create
    @faq = Faq.new(faq_params)

    if @faq.save
      redirect_to console_faqs_path, notice: "FAQ created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @faq.update(faq_params)
      redirect_to console_faqs_path, notice: "FAQ updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_faq
    @faq = Faq.find(params[:id])
  end

  def faq_params
    params.require(:faq).permit(:jurisdiction, :question, :answer, :published)
  end
end
