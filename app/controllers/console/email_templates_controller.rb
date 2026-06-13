class Console::EmailTemplatesController < Console::ResourceController
  before_action -> { require_capability(:manage_product) }
  before_action :set_email_template, only: [ :show, :edit, :update, :activate, :deactivate, :preview, :send_test ]

  resource EmailTemplate
  searches "email_templates.name", "email_templates.subject"
  sortable name: "email_templates.name",
           type: "email_templates.template_type",
           updated: "email_templates.updated_at"
  default_sort :type, :asc
  filters template_type: ->(scope, value) { scope.where(template_type: value) },
          email_category: ->(scope, value) { scope.where(email_category: value) }

  csv_column("Name") { |t| t.name }
  csv_column("Type") { |t| t.template_type }
  csv_column("Category") { |t| t.email_category }
  csv_column("Active") { |t| t.is_active? ? "yes" : "no" }

  def show
    @available_fields = EmailTemplate.available_fields[@email_template.template_type] || {}
    @referencing_workflows = @email_template.referencing_workflows
  end

  def new
    @email_template = EmailTemplate.new
    @email_template.template_type = params[:template_type] if params[:template_type].present?
  end

  def create
    @email_template = EmailTemplate.new(email_template_params)
    @email_template.current_user = current_user

    if @email_template.save
      redirect_to console_email_template_path(@email_template), notice: "Template created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_fields = EmailTemplate.available_fields[@email_template.template_type] || {}
  end

  def update
    @email_template.current_user = current_user

    if @email_template.update(email_template_params)
      redirect_to console_email_template_path(@email_template), notice: "Template updated."
    else
      @available_fields = EmailTemplate.available_fields[@email_template.template_type] || {}
      render :edit, status: :unprocessable_entity
    end
  end

  # Only one template per type is active — activating swaps the live one.
  def activate
    @email_template.current_user = current_user
    EmailTemplate.where(template_type: @email_template.template_type).update_all(is_active: false)
    @email_template.update!(is_active: true)
    redirect_to console_email_templates_path, notice: "Template activated — it is now the live #{@email_template.template_type.humanize} email."
  end

  def deactivate
    active_dependents = @email_template.referencing_workflows.select(&:active?)
    if active_dependents.any?
      redirect_to console_email_template_path(@email_template),
                  alert: "Cannot deactivate — active workflows depend on this template: #{active_dependents.map(&:name).to_sentence}. Deactivate them first." and return
    end

    @email_template.current_user = current_user
    @email_template.update!(is_active: false)
    redirect_to console_email_templates_path, notice: "Template deactivated."
  end

  def preview
    rendered = @email_template.render_content(
      Console::EmailTemplateSampleData.preview_for(@email_template, current_user),
      include_header_footer: false
    )

    @email_content = rendered[:content].html_safe
    @email_title = rendered[:subject]
    render layout: "mailer"
  end

  def send_test
    rendered = @email_template.render_content(Console::EmailTemplateSampleData.test_for(@email_template, current_user))
    AdminMailer.test_email(to: current_user.email, subject: rendered[:subject], content: rendered[:content]).deliver_now
    redirect_to console_email_template_path(@email_template), notice: "Test email sent to #{current_user.email}."
  rescue => e
    redirect_to console_email_template_path(@email_template), alert: "Failed to send test email: #{e.message}"
  end

  protected

  def base_scope
    EmailTemplate.all
  end

  private

  def set_email_template
    @email_template = EmailTemplate.find(params[:id])
  end

  def email_template_params
    params.require(:email_template).permit(:name, :subject, :content, :content_body, :email_category, :template_type, :description)
  end
end
