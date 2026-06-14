# Users index is the ResourceController DSL reference implementation;
# show adds the security panel (Devise trackable/lockable) and account
# actions, every one of them audit-logged.
class Console::UsersController < Console::ResourceController
  before_action -> { require_capability(:manage_users) }
  before_action :set_user, only: [ :show, :edit, :update, :lock, :unlock, :send_reset_password ]

  resource User
  searches "users.email", "users.first_name", "users.last_name"
  sortable email: "users.email",
           name: "users.last_name",
           created: "users.created_at",
           last_seen: "users.last_sign_in_at"
  default_sort :created, :desc
  filters role: ->(scope, value) { value == "admin" ? scope.where(admin: true) : scope.where(admin: false) },
          country: ->(scope, value) { scope.where(country_of_residence: value) },
          lender_id: ->(scope, value) { scope.where(lender_id: value) },
          status: ->(scope, value) { value == "active" ? scope.where.not(confirmed_at: nil) : scope.where(confirmed_at: nil) }
  preloads :lender

  csv_column("Email") { |user| user.email }
  csv_column("Name") { |user| user.full_name }
  csv_column("Role") { |user| user.admin? ? "Admin" : "Customer" }
  csv_column("Lender") { |user| user.lender&.name }
  csv_column("Country") { |user| user.country_of_residence }
  csv_column("Confirmed") { |user| user.confirmed_at&.iso8601 }
  csv_column("Sign-ins") { |user| user.sign_in_count }
  csv_column("Last sign-in") { |user| user.last_sign_in_at&.iso8601 }
  csv_column("Joined") { |user| user.created_at.to_date.iso8601 }

  def new
    @user = User.new
  end

  # Manual user creation (rare — customers self-register). The account is
  # pre-confirmed and receives a set-password email.
  def create
    @user = User.new(user_params)
    @user.current_admin_user = current_user
    @user.lender = policy.futureproof? ? (Lender.find_by(id: params[:user][:lender_id]) || Lender.lender_type_futureproof.first) : policy.lender
    @user.terms_accepted = true
    @user.confirmed_at = Time.current
    @user.password = SecureRandom.base58(24)

    if @user.save
      @user.send_reset_password_instructions
      AuditLog.log_action(user: current_user, action: "user_created_by_admin", resource: @user)
      redirect_to console_user_path(@user), notice: "User created — set-password email sent to #{@user.email}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @user.log_view_by(current_user)
    @versions = @user.user_versions.includes(:admin_user).recent.limit(20)
    @applications = @user.applications
                         .includes(:contract, :kyc_submission, :aml_check, :broker)
                         .order(created_at: :desc)
    @contracts = Contract.where(application_id: @applications.map(&:id)).includes(:funder_pool)
    @quotes = Quote.where(application_id: @applications.map(&:id)).order(created_at: :desc).limit(10)
    @conversations = ChatConversation.where(user_id: @user.id).includes(:chat_agent).order(updated_at: :desc).limit(10)
    @support_tickets = @user.support_tickets.order(created_at: :desc).limit(10)
    @legal_acceptances = @user.legal_document_acceptances.includes(:legal_document).order(accepted_at: :desc)
  end

  def edit
  end

  def update
    @user.current_admin_user = current_user

    if @user.update(user_params)
      redirect_to console_user_path(@user), notice: "User updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def lock
    @user.lock_access!(send_instructions: false)
    AuditLog.log_action(user: current_user, action: "user_locked", resource: @user)
    redirect_to console_user_path(@user), notice: "Account locked."
  end

  def unlock
    @user.unlock_access!
    AuditLog.log_action(user: current_user, action: "user_unlocked", resource: @user)
    redirect_to console_user_path(@user), notice: "Account unlocked."
  end

  def send_reset_password
    @user.send_reset_password_instructions
    AuditLog.log_action(user: current_user, action: "password_reset_sent", resource: @user)
    redirect_to console_user_path(@user), notice: "Password reset email sent to #{@user.email}."
  end

  protected

  # Futureproof admins see everyone; lender admins see their own book.
  # The region picker further narrows by residence country.
  def base_scope
    scope = policy.futureproof? ? User.all : User.where(lender: policy.lender)
    scope_by_jurisdiction(scope, :country_of_residence)
  end

  private

  def set_user
    @user = base_scope.find(params[:id])
  end

  def user_params
    permitted = [ :email, :first_name, :last_name, :country_of_residence ]
    permitted << :admin if policy.futureproof?
    params.require(:user).permit(*permitted)
  end
end
