require "test_helper"

class ApplicationChecklistTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin_user)
    @application = applications(:processing_application)
  end

  test "should be valid with required attributes" do
    checklist_item = ApplicationChecklist.new(
      application: @application,
      name: "Test checklist item",
      position: 0,
      completed: false
    )
    assert checklist_item.valid?
  end

  test "should require application" do
    checklist_item = ApplicationChecklist.new(
      name: "Test checklist item",
      position: 0,
      completed: false
    )
    assert_not checklist_item.valid?
    assert_includes checklist_item.errors[:application], "must exist"
  end

  test "should require name" do
    checklist_item = ApplicationChecklist.new(
      application: @application,
      position: 0,
      completed: false
    )
    assert_not checklist_item.valid?
    assert_includes checklist_item.errors[:name], "can't be blank"
  end

  test "should require position" do
    checklist_item = ApplicationChecklist.new(
      application: @application,
      name: "Test checklist item",
      completed: false
    )
    assert_not checklist_item.valid?
    assert_includes checklist_item.errors[:position], "can't be blank"
  end

  test "position should be non-negative" do
    checklist_item = ApplicationChecklist.new(
      application: @application,
      name: "Test checklist item",
      position: -1,
      completed: false
    )
    assert_not checklist_item.valid?
    assert_includes checklist_item.errors[:position], "must be greater than or equal to 0"
  end

  test "mark_completed! should set completed fields" do
    checklist_item = application_checklists(:identity_check)
    
    assert_not checklist_item.completed?
    assert_nil checklist_item.completed_at
    assert_nil checklist_item.completed_by
    
    checklist_item.mark_completed!(@user)
    checklist_item.reload
    
    assert checklist_item.completed?
    assert_not_nil checklist_item.completed_at
    assert_equal @user, checklist_item.completed_by
    assert checklist_item.completed_at <= Time.current
  end

  test "mark_incomplete! should clear completed fields" do
    checklist_item = application_checklists(:completed_identity_check)
    
    assert checklist_item.completed?
    assert_not_nil checklist_item.completed_at
    assert_not_nil checklist_item.completed_by
    
    checklist_item.mark_incomplete!
    checklist_item.reload
    
    assert_not checklist_item.completed?
    assert_nil checklist_item.completed_at
    assert_nil checklist_item.completed_by
  end

  test "completed_by_name returns user display name when completed_by exists" do
    checklist_item = application_checklists(:completed_identity_check)
    expected_name = checklist_item.completed_by.display_name
    
    assert_equal expected_name, checklist_item.completed_by_name
  end

  test "completed_by_name returns Unknown when completed_by is nil" do
    checklist_item = application_checklists(:identity_check)
    assert_nil checklist_item.completed_by
    
    assert_equal "Unknown", checklist_item.completed_by_name
  end

  test "ordered scope returns items in position order" do
    # Create items out of order
    item3 = ApplicationChecklist.create!(
      application: @application,
      name: "Third item", 
      position: 3
    )
    item1 = ApplicationChecklist.create!(
      application: @application,
      name: "First item",
      position: 1
    )
    item2 = ApplicationChecklist.create!(
      application: @application,
      name: "Second item",
      position: 2  
    )

    ordered_items = @application.application_checklists.ordered
    
    assert_equal item1.id, ordered_items[0].id
    assert_equal item2.id, ordered_items[1].id
    assert_equal item3.id, ordered_items[2].id
  end

  test "completed scope returns only completed items" do
    completed_item = application_checklists(:completed_identity_check)
    incomplete_item = application_checklists(:identity_check)
    
    completed_items = ApplicationChecklist.completed
    
    assert_includes completed_items, completed_item
    assert_not_includes completed_items, incomplete_item
  end

  test "pending scope returns only incomplete items" do
    completed_item = application_checklists(:completed_identity_check)
    incomplete_item = application_checklists(:identity_check)
    
    pending_items = ApplicationChecklist.pending
    
    assert_includes pending_items, incomplete_item
    assert_not_includes pending_items, completed_item
  end

  test "STANDARD_CHECKLIST_ITEMS constant contains expected items" do
    expected_items = [
      "Verification of identity check",
      "Property ownership verified", 
      "Existing mortgage status verified",
      "Signed contract"
    ]
    
    assert_equal expected_items, ApplicationChecklist::STANDARD_CHECKLIST_ITEMS
    assert ApplicationChecklist::STANDARD_CHECKLIST_ITEMS.frozen?
  end
end