class WorkflowTemplateService
  def self.available_templates
    [
      {
        name: "New Customer Onboarding",
        category: "onboarding",
        description: "Welcome new customers and guide them through the initial setup process",
        trigger_type: "user_registered",
        steps: [
          {
            step_type: "send_email",
            name: "Welcome Email",
            description: "Send immediate welcome message with account activation link",
            position: 0,
            configuration: {
              email_template_id: 1  # Email Verification template
            }
          },
          {
            step_type: "delay",
            name: "Initial Wait",
            description: "Give user time to activate account",
            position: 1,
            configuration: {
              duration: 24,
              unit: "hours"
            }
          },
          {
            step_type: "condition",
            name: "Check Activation",
            description: "Check if user has activated their account",
            position: 2,
            configuration: {
              condition_type: "user_property",
              field: "confirmed_at",
              operator: "present"
            }
          },
          {
            step_type: "send_email",
            name: "Getting Started Guide",
            description: "Send comprehensive getting started guide",
            position: 3,
            configuration: {
              email_template_id: 2  # Application Submitted template (repurposed for onboarding)
            }
          }
        ]
      },
      {
        name: "Application Journey - Standard",
        category: "operational",
        description: "Guide customers through the mortgage application process",
        trigger_type: "application_created",
        steps: [
          {
            step_type: "send_email",
            name: "Application Confirmation",
            description: "Confirm application creation and next steps",
            position: 0,
            configuration: {
              email_template_id: 2  # Application Submitted template
            }
          },
          {
            step_type: "delay",
            name: "24 Hour Follow-up",
            description: "Wait 24 hours for user to complete details",
            position: 1,
            configuration: {
              duration: 24,
              unit: "hours"
            }
          },
          {
            step_type: "condition",
            name: "Check Completion",
            description: "Check if user has completed application details",
            position: 2,
            configuration: {
              condition_type: "application_status",
              expected_status: "submitted"
            }
          },
          {
            step_type: "send_email",
            name: "Completion Reminder",
            description: "Remind user to complete application if not done",
            position: 3,
            configuration: {
              email_template_id: 3  # Security Notification template (repurposed for reminders)
            }
          }
        ]
      },
      {
        name: "Application Status Updates",
        category: "operational", 
        description: "Notify customers of application status changes",
        trigger_type: "application_status_changed",
        trigger_conditions: {
          from_status: "submitted",
          to_status: "processing"
        },
        steps: [
          {
            step_type: "send_email",
            name: "Processing Notification",
            description: "Notify customer application is being processed",
            position: 0,
            configuration: {
              email_template_id: 2  # Application Submitted template
            }
          },
          {
            step_type: "delay",
            name: "Processing Time",
            description: "Allow time for processing",
            position: 1,
            configuration: {
              duration: 3,
              unit: "days"
            }
          },
          {
            step_type: "send_email",
            name: "Status Update",
            description: "Provide processing status update",
            position: 2,
            configuration: {
              email_template_id: 3  # Security Notification template
            }
          }
        ]
      },
      {
        name: "Contract Execution Workflow",
        category: "end_of_contract",
        description: "Handle contract signing and completion processes",
        trigger_type: "contract_signed", 
        steps: [
          {
            step_type: "send_email",
            name: "Contract Confirmation",
            description: "Confirm contract has been signed",
            position: 0,
            configuration: {
              email_template_id: 2  # Application Submitted template
            }
          },
          {
            step_type: "update_status",
            name: "Update Application Status",
            description: "Mark application as accepted",
            position: 1,
            configuration: {
              field: "status",
              value: "accepted"
            }
          },
          {
            step_type: "send_email",
            name: "Welcome to Services",
            description: "Welcome customer to ongoing services",
            position: 2,
            configuration: {
              email_template_id: 1  # Email Verification template
            }
          }
        ]
      },
      {
        name: "Inactive Customer Re-engagement",
        category: "operational",
        description: "Re-engage customers who have become inactive",
        trigger_type: "inactivity",
        trigger_conditions: {
          inactivity_duration: 7,
          inactivity_unit: "days"
        },
        steps: [
          {
            step_type: "send_email",
            name: "Re-engagement Email",
            description: "Gentle reminder to complete their application",
            position: 0,
            configuration: {
              email_template_id: 3  # Security Notification template
            }
          },
          {
            step_type: "delay",
            name: "Wait for Response",
            description: "Give customer time to respond",
            position: 1,
            configuration: {
              duration: 3,
              unit: "days"
            }
          },
          {
            step_type: "condition",
            name: "Check Activity",
            description: "Check if customer has become active again",
            position: 2,
            configuration: {
              condition_type: "user_property",
              field: "last_sign_in_at",
              operator: "recent"
            }
          },
          {
            step_type: "send_email",
            name: "Final Reminder",
            description: "Final reminder before marking inactive",
            position: 3,
            configuration: {
              email_template_id: 3  # Security Notification template
            }
          }
        ]
      },
      {
        name: "Document Upload Follow-up",
        category: "operational",
        description: "Follow up on required document uploads",
        trigger_type: "document_uploaded",
        steps: [
          {
            step_type: "send_email",
            name: "Document Received",
            description: "Acknowledge document receipt",
            position: 0,
            configuration: {
              email_template_id: 2  # Application Submitted template
            }
          },
          {
            step_type: "condition",
            name: "Check All Documents",
            description: "Verify all required documents are uploaded",
            position: 1,
            configuration: {
              condition_type: "application_status",
              field: "documents_complete",
              expected_status: "true"
            }
          },
          {
            step_type: "send_email",
            name: "Documents Complete",
            description: "Notify when all documents are received",
            position: 2,
            configuration: {
              email_template_id: 2  # Application Submitted template
            }
          }
        ]
      },
      {
        name: "End of Contract Notification",
        category: "end_of_contract",
        description: "Notify customers approaching contract end dates",
        trigger_type: "time_delay",
        trigger_conditions: {
          delay_after: "contract_signed",
          duration: 11,
          unit: "weeks"
        },
        steps: [
          {
            step_type: "send_email",
            name: "Contract Ending Soon",
            description: "Notify customer contract is ending in 1 week",
            position: 0,
            configuration: {
              email_template_id: 3  # Security Notification template
            }
          },
          {
            step_type: "delay",
            name: "Final Week",
            description: "Wait until contract end",
            position: 1,
            configuration: {
              duration: 7,
              unit: "days"
            }
          },
          {
            step_type: "send_email",
            name: "Contract Completed", 
            description: "Contract completion and next steps",
            position: 2,
            configuration: {
              email_template_id: 2  # Application Submitted template
            }
          }
        ]
      }
    ]
  end
  
  def self.create_from_template(template_name, admin_user)
    template = available_templates.find { |t| t[:name] == template_name }
    return nil unless template
    
    workflow = EmailWorkflow.new(
      name: template[:name],
      description: template[:description],
      trigger_type: template[:trigger_type],
      trigger_conditions: template[:trigger_conditions] || { "event" => template[:trigger_type] },
      active: false, # Start inactive so admin can review
      created_by: admin_user
    )
    
    if workflow.save
      template[:steps].each do |step_template|
        step = workflow.workflow_steps.build(
          step_type: step_template[:step_type],
          name: step_template[:name],
          description: step_template[:description],
          position: step_template[:position],
          configuration: step_template[:configuration]
        )
        step.save!
      end
      
      workflow
    else
      nil
    end
  end
  
  def self.templates_by_category
    available_templates.group_by { |template| template[:category] }
  end
  
  def self.onboarding_templates
    available_templates.select { |template| template[:category] == "onboarding" }
  end
  
  def self.operational_templates
    available_templates.select { |template| template[:category] == "operational" }
  end
  
  def self.end_of_contract_templates
    available_templates.select { |template| template[:category] == "end_of_contract" }
  end
  
  def self.customer_lifecycle_flow
    # Returns a complete customer lifecycle with all templates in order
    {
      onboarding: onboarding_templates,
      operational: operational_templates,
      end_of_contract: end_of_contract_templates
    }
  end
end