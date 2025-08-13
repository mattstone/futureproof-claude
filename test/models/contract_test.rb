require "test_helper"

class ContractTest < ActiveSupport::TestCase
  fixtures :users, :applications, :contracts
  
  def setup
    @application = applications(:mortgage_application)
    @contract = Contract.new(
      application: @application,
      start_date: Date.current,
      end_date: Date.current + 1.year
    )
  end
  
  test "should create valid contract" do
    assert @contract.valid?
    assert @contract.save
  end
  
  test "should require application" do
    @contract.application = nil
    assert_not @contract.valid?
    assert_includes @contract.errors[:application], "must exist"
  end
  
  test "should require start_date" do
    @contract.start_date = nil
    assert_not @contract.valid?
    assert_includes @contract.errors[:start_date], "can't be blank"
  end
  
  test "should require end_date" do
    @contract.end_date = nil
    assert_not @contract.valid?
    assert_includes @contract.errors[:end_date], "can't be blank"
  end
  
  test "should validate end_date is after start_date" do
    @contract.start_date = Date.current
    @contract.end_date = Date.current - 1.day
    assert_not @contract.valid?
    assert_includes @contract.errors[:end_date], "must be after start date"
  end
  
  test "should allow end_date same as start_date" do
    @contract.start_date = Date.current
    @contract.end_date = Date.current
    assert @contract.valid?
  end
  
  test "should have default status of awaiting_funding" do
    contract = Contract.new(application: @application, start_date: Date.current, end_date: Date.current + 1.year)
    assert_equal 'awaiting_funding', contract.status
    assert contract.status_awaiting_funding?
  end
  
  test "should have enum status with prefix" do
    contract = Contract.create!(application: @application, start_date: Date.current, end_date: Date.current + 1.year)
    
    # Test all enum values
    assert contract.status_awaiting_funding?
    
    contract.status_awaiting_investment!
    assert contract.status_awaiting_investment?
    
    contract.status_ok!
    assert contract.status_ok?
    
    contract.status_in_holiday!
    assert contract.status_in_holiday?
    
    contract.status_in_arrears!
    assert contract.status_in_arrears?
    
    contract.status_complete!
    assert contract.status_complete?
  end
  
  test "should belong to application" do
    contract = Contract.create!(application: @application, start_date: Date.current, end_date: Date.current + 1.year)
    assert_equal @application, contract.application
  end
  
  test "application should have one contract" do
    contract = Contract.create!(application: @application, start_date: Date.current, end_date: Date.current + 1.year)
    assert_equal contract, @application.contract
  end
  
  test "should enforce unique application constraint" do
    # Create first contract
    Contract.create!(application: @application, start_date: Date.current, end_date: Date.current + 1.year)
    
    # Try to create second contract for same application
    duplicate_contract = Contract.new(application: @application, start_date: Date.current, end_date: Date.current + 1.year)
    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate_contract.save!
    end
  end
end
