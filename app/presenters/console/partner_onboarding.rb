# Derived onboarding state for the three partner types. No stored status —
# each step is computed from what actually exists (an executed agreement, an
# invited admin, configured terms), so the checklist can never drift from
# reality. The view maps step keys to the links that complete them.
class Console::PartnerOnboarding
  Step = Struct.new(:key, :label, :done, :hint, keyword_init: true)

  attr_reader :partner, :steps

  def self.for(partner)
    new(partner)
  end

  def initialize(partner)
    @partner = partner
    @steps =
      case partner
      when Lender then lender_steps
      when WholesaleFunder then wholesale_funder_steps
      when Broker then broker_steps
      else []
      end
  end

  def suspended?
    partner.respond_to?(:status_suspended?) && partner.status_suspended?
  end

  def complete?
    steps.any? && steps.all?(&:done)
  end

  def done_count
    steps.count(&:done)
  end

  def progress_label
    return "Suspended" if suspended?

    complete? ? "Active" : "Onboarding #{done_count}/#{steps.size}"
  end

  private

  def agreement_executed_step
    Step.new(
      key: :agreement,
      label: "Agreement executed",
      done: partner.agreements.where(status: :fully_executed).exists?,
      hint: "Generate the agreement from a legal template and collect both signatures."
    )
  end

  def lender_steps
    [
      agreement_executed_step,
      Step.new(
        key: :admin_user,
        label: "Admin user invited",
        done: partner.users.where(admin: true).exists?,
        hint: "Invite someone at the lender to run their book in the Console."
      ),
      Step.new(
        key: :funding,
        label: "Funding configured",
        done: partner.lender_wholesale_funders.where(active: true).exists? &&
              partner.lender_funder_pools.where(active: true).exists?,
        hint: "Link an active wholesale funder and at least one active pool."
      ),
      Step.new(
        key: :product,
        label: "Product offered",
        done: partner.mortgage_lenders.where(active: true).exists?,
        hint: "Attach the lender to at least one mortgage product."
      )
    ]
  end

  def wholesale_funder_steps
    [
      agreement_executed_step,
      Step.new(
        key: :capital,
        label: "Capital committed",
        done: partner.total_allocated_amount.to_f.positive?,
        hint: "Record the facility size on the funder."
      ),
      Step.new(
        key: :pools,
        label: "Pool created",
        done: partner.funder_pools.exists?,
        hint: "Create at least one priced pool to allocate from."
      ),
      Step.new(
        key: :lender_access,
        label: "Lender access granted",
        done: LenderWholesaleFunder.where(wholesale_funder: partner, active: true).exists?,
        hint: "Link the funder to at least one lender."
      )
    ]
  end

  def broker_steps
    [
      agreement_executed_step,
      Step.new(
        key: :login,
        label: "Login active",
        done: partner.active?,
        hint: "The broker account must be active to sign in."
      ),
      Step.new(
        key: :lender_access,
        label: "Lender assigned",
        done: partner.broker_lenders.where(active: true).exists?,
        hint: "Assign the broker to at least one lender."
      ),
      Step.new(
        key: :commission,
        label: "Commission rate set",
        done: BrokerCommissionRate.where(broker: partner, active: true).exists?,
        hint: "Configure an active commission rate on the lender."
      )
    ]
  end
end
