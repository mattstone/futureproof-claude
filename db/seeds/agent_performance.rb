# Seed Agent Performance Data (Mock)
puts "Seeding Agent Performance data..."

agents_data = [
  { agent_name: "Ava (AI)", agent_type: "ai", status: "processing", current_task: "Reviewing application #1042", tasks_today: 23, tasks_week: 156, tasks_month: 612, avg_res: 2.3, satisfaction: 96.2, quality: 98.1 },
  { agent_name: "Marcus (AI)", agent_type: "ai", status: "processing", current_task: "Generating monthly income report", tasks_today: 18, tasks_week: 134, tasks_month: 521, avg_res: 3.1, satisfaction: 94.8, quality: 97.5 },
  { agent_name: "Claire (AI)", agent_type: "ai", status: "idle", current_task: nil, tasks_today: 12, tasks_week: 89, tasks_month: 345, avg_res: 4.2, satisfaction: 97.1, quality: 99.2 },
  { agent_name: "Sam (AI)", agent_type: "ai", status: "processing", current_task: "Resolving login issue for user #8821", tasks_today: 31, tasks_week: 198, tasks_month: 742, avg_res: 1.8, satisfaction: 93.5, quality: 96.8 },
  { agent_name: "Diana (AI)", agent_type: "ai", status: "idle", current_task: nil, tasks_today: 15, tasks_week: 112, tasks_month: 423, avg_res: 5.6, satisfaction: 95.3, quality: 98.4 },
  { agent_name: "James T.", agent_type: "human", status: "processing", current_task: "Reviewing high-value application #1038", tasks_today: 8, tasks_week: 42, tasks_month: 168, avg_res: 12.5, satisfaction: 98.0, quality: 99.5 },
  { agent_name: "Sarah L.", agent_type: "human", status: "on_break", current_task: nil, tasks_today: 6, tasks_week: 35, tasks_month: 142, avg_res: 15.2, satisfaction: 97.8, quality: 99.1 },
  { agent_name: "Michael R.", agent_type: "human", status: "processing", current_task: "Compliance audit - AU region Q1", tasks_today: 4, tasks_week: 22, tasks_month: 89, avg_res: 25.0, satisfaction: 96.5, quality: 99.8 },
]

task_types = AgentTask::TASK_TYPES
task_descriptions = {
  "application_review" => ["Reviewing application #%d", "Processing application for %s property", "Verifying eligibility for EPM application"],
  "document_verify" => ["Verifying ID document for applicant", "Checking property valuation report", "Validating income documentation"],
  "customer_query" => ["Answering query about monthly income", "Explaining EPM structure to prospect", "Addressing contract question"],
  "compliance_check" => ["Running AML check for new applicant", "Quarterly compliance audit - %s region", "Verifying lender licensing status"],
  "report_generation" => ["Generating monthly performance report", "Creating funder allocation summary", "Building quarterly investor report"],
  "onboarding_assist" => ["Guiding new customer through application", "Setting up lender account", "Configuring broker portal access"],
  "loan_setup" => ["Processing loan settlement documents", "Coordinating with investment manager", "Setting up monthly income payments"],
  "status_update" => ["Updating application status to 'In Review'", "Notifying customer of approval", "Sending contract for e-signature"]
}

agents_data.each do |data|
  agent = AgentPerformance.find_or_create_by!(agent_name: data[:agent_name]) do |a|
    a.agent_type = data[:agent_type]
  end

  agent.update!(
    status: data[:status],
    current_task: data[:current_task],
    tasks_completed_today: data[:tasks_today],
    tasks_completed_week: data[:tasks_week],
    tasks_completed_month: data[:tasks_month],
    avg_resolution_minutes: data[:avg_res],
    satisfaction_score: data[:satisfaction],
    quality_score: data[:quality],
    last_active_at: Time.current - rand(0..30).minutes
  )

  # Create 50 completed tasks per agent (spread over last 30 days)
  50.times do |i|
    task_type = task_types.sample
    descriptions = task_descriptions[task_type] || ["Processing task"]
    desc = descriptions.sample % [rand(1000..9999), %w[AU NZ UK US].sample]
    completed_at = Time.current - rand(0..30).days - rand(0..23).hours
    resolution = data[:agent_type] == "ai" ? rand(1.0..8.0).round(1) : rand(5.0..30.0).round(1)

    agent.agent_tasks.create!(
      task_type: task_type,
      status: "completed",
      description: desc,
      priority: %w[low normal normal normal high urgent].sample,
      resolution_minutes: resolution,
      outcome: "Resolved successfully",
      started_at: completed_at - resolution.minutes,
      completed_at: completed_at
    )
  end

  # Create 2-3 pending/in-progress tasks
  rand(2..3).times do
    task_type = task_types.sample
    descriptions = task_descriptions[task_type] || ["Processing task"]
    desc = descriptions.sample % [rand(1000..9999), %w[AU NZ UK US].sample]

    agent.agent_tasks.create!(
      task_type: task_type,
      status: %w[pending in_progress].sample,
      description: desc,
      priority: %w[normal high].sample,
      started_at: Time.current - rand(1..15).minutes
    )
  end
end

puts "  ✅ #{AgentPerformance.count} agents, #{AgentTask.count} tasks seeded"
