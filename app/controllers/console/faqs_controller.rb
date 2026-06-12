class Console::FaqsController < Console::BaseController
  before_action -> { require_capability(:manage_product) }
  before_action :set_faq, only: [ :edit, :update, :destroy, :move_up, :move_down ]

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

  def destroy
    @faq.destroy
    redirect_to console_faqs_path, notice: "FAQ deleted."
  end

  # CSP-safe ordering without drag-and-drop: swap positions with the
  # neighbour in the same jurisdiction.
  def move_up
    swap_with_neighbour(:up)
  end

  def move_down
    swap_with_neighbour(:down)
  end

  private

  def swap_with_neighbour(direction)
    siblings = Faq.where(jurisdiction: @faq.jurisdiction).ordered.to_a
    index = siblings.index(@faq)
    target = direction == :up ? index - 1 : index + 1

    if index.nil? || target.negative? || target >= siblings.size
      redirect_to console_faqs_path, alert: "Can't move further." and return
    end

    neighbour = siblings[target]
    my_position = @faq.position
    @faq.update!(position: neighbour.position)
    neighbour.update!(position: my_position)
    redirect_to console_faqs_path, notice: "Order updated."
  end

  def set_faq
    @faq = Faq.find(params[:id])
  end

  def faq_params
    params.require(:faq).permit(:jurisdiction, :question, :answer, :published)
  end
end
