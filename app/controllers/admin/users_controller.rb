class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show, :edit, :update]
  before_action :set_current_admin_user, only: [:create, :update]

  def index
    @users = scoped_users.includes(:lender).order(:email)
    
    # Search filter
    @users = @users.where("email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?", 
                         "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    
    # Lender filter (only show to Futureproof admins)
    if futureproof_admin? && params[:lender_id].present?
      @users = @users.where(lender_id: params[:lender_id])
    end
    
    # Role filter
    case params[:role]
    when 'admin'
      @users = @users.where(admin: true)
    when 'user'
      @users = @users.where(admin: false)
    end
    
    # Status filter
    case params[:status]
    when 'active'
      @users = @users.where.not(confirmed_at: nil)
    when 'inactive'
      @users = @users.where(confirmed_at: nil)
    end
    
    @users = @users.page(params[:page]).per(10)
    
    # For the filter dropdowns
    @role_options = [
      ['Admin', 'admin'],
      ['User', 'user']
    ]
    
    @status_options = [
      ['Active', 'active'],
      ['Inactive', 'inactive']
    ]
    
    # Lender filter options (only for Futureproof admins)
    if futureproof_admin?
      @lender_options = Lender.order(:name).pluck(:name, :id)
    end
  end

  def show
    # Log that admin viewed this user
    @user.log_view_by(current_user)
    
    # Get change history for display
    @user_versions = @user.user_versions.includes(:admin_user).recent.limit(20)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.current_admin_user = current_user
    @user.confirmed_at = Time.current if @user.valid?
    
    # Assign lender based on admin type
    if lender_admin?
      @user.lender = admin_lender
    elsif futureproof_admin? && params[:user][:lender_id].present?
      @user.lender_id = params[:user][:lender_id]
    else
      @user.lender = Lender.lender_type_futureproof.first
    end
    
    if @user.save
      redirect_to admin_user_path(@user), notice: 'User was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Remove password parameters if they're blank
    if user_params[:password].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end

    if @user.update(user_params.except(:password, :password_confirmation).merge(password_params))
      redirect_to admin_user_path(@user), notice: 'User was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end


  private

  def set_user
    @user = scoped_users.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :first_name, :last_name, :country_of_residence, :admin, :password, :password_confirmation, :terms_accepted)
  end

  def password_params
    if params[:user][:password].present?
      { password: params[:user][:password], password_confirmation: params[:user][:password_confirmation] }
    else
      {}
    end
  end
  
  def set_current_admin_user
    @user&.current_admin_user = current_user if @user
  end
end