# Single decision point for who may do what in the Console.
#
# Wraps today's two admin flavours (Futureproof admins see everything,
# lender admins see their own book). When real roles arrive they land
# here and nowhere else — controllers and views only ever ask the policy.
class Console::Policy
  CAPABILITIES = %i[
    view_pipeline
    manage_users
    manage_partners
    manage_product
    publish_prompts
    view_system
    run_diagnostics
  ].freeze

  attr_reader :user

  def initialize(user)
    @user = user
  end

  # Gate for the whole namespace.
  def access?
    admin?
  end

  def admin?
    user&.admin? == true
  end

  def futureproof?
    admin? && user.lender&.lender_type_futureproof? == true
  end

  def lender?
    admin? && user.lender&.lender_type_lender? == true
  end

  def lender
    user&.lender
  end

  # --- Capabilities -------------------------------------------------------
  # Lender admins work their own pipeline and customers; everything that
  # shapes the platform itself (partners, product, prompts, system) is
  # Futureproof-only.

  def view_pipeline?
    admin?
  end

  def manage_users?
    admin?
  end

  def manage_partners?
    futureproof?
  end

  def manage_product?
    futureproof?
  end

  def publish_prompts?
    futureproof?
  end

  def view_system?
    futureproof?
  end

  def run_diagnostics?
    futureproof?
  end

  def can?(capability)
    capability = capability.to_sym
    unless CAPABILITIES.include?(capability)
      raise ArgumentError, "unknown console capability: #{capability}"
    end
    public_send("#{capability}?")
  end
end
