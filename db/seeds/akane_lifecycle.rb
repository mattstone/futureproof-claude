# Configure Akane's lifecycle stages for customer acquisition
puts "🎯 Configuring Akane's Lifecycle Stages..."

akane = AiAgent.find_by(name: 'Akane')

unless akane
  puts "❌ Akane not found. Please run ai_agents seed first."
  return
end

# Configure communication style
akane.update!(
  communication_style: {
    tone: "friendly and encouraging",
    greeting: "Hi there! I'm the FutureProof assistant, and I'm here to help you get started with your application!",
    signature: "Looking forward to helping you,\nThe FutureProof team"
  }
)

# Configure lifecycle stages
akane.update!(
  lifecycle_stages: [
    {
      stage_name: "visitor_inquiry",
      stage_label: "Initial Interest",
      stage_description: "Customer has just registered and is exploring their options",
      entry_trigger: "user_registered",
      stage_color: "blue",
      automated_actions: [
        {
          action_type: "send_email",
          email_template_id: EmailTemplate.find_by(template_type: "welcome")&.id,
          delay: { duration: 0, unit: "minutes" }
        },
        {
          action_type: "send_email",
          email_template_id: EmailTemplate.find_by(template_type: "getting_started")&.id,
          delay: { duration: 2, unit: "hours" }
        }
      ],
      exit_conditions: {
        application_created: true
      }
    },
    {
      stage_name: "application_started",
      stage_label: "Application in Progress",
      stage_description: "Customer has started their application but hasn't submitted yet",
      entry_trigger: "application_created",
      stage_color: "green",
      automated_actions: [
        {
          action_type: "send_email",
          email_template_id: EmailTemplate.find_by(name: "Application Tips")&.id,
          delay: { duration: 1, unit: "days" },
          conditions: {
            status: ["created", "user_details"]
          }
        },
        {
          action_type: "send_email",
          email_template_id: EmailTemplate.find_by(name: "Gentle Reminder")&.id,
          delay: { duration: 3, unit: "days" },
          conditions: {
            status: ["created", "user_details", "property_details"]
          }
        }
      ],
      exit_conditions: {
        status: "submitted"
      }
    },
    {
      stage_name: "application_submitted",
      stage_label: "Under Review",
      stage_description: "Application has been submitted and is awaiting review",
      entry_trigger: "application_submitted",
      stage_color: "purple",
      automated_actions: [
        {
          action_type: "send_email",
          email_template_id: EmailTemplate.find_by(template_type: "submission_confirmation")&.id,
          delay: { duration: 0, unit: "minutes" }
        }
      ],
      handoff_rules: {
        handoff_to: "rie"
      },
      exit_conditions: {
        status: ["processing", "accepted", "rejected"]
      }
    }
  ]
)

puts "✅ Akane configured with #{akane.lifecycle_stages.length} lifecycle stages:"
akane.lifecycle_stages.each do |stage|
  puts "   - #{stage['stage_label']} (#{stage['automated_actions']&.length || 0} actions)"
end
puts ""