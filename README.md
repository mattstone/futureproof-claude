# Futureproof Financial - Rails Application

A Rails 8.0.2 application for managing financial workflows and applications.

## Requirements

* Ruby version: 3.3.6
* Rails version: 8.0.2
* PostgreSQL database
* Redis (for background jobs)

## Setup

1. Clone the repository
2. Install dependencies: `bundle install`
3. Setup database: `rails db:create db:migrate db:seed`
4. Start the server: `rails server`

## Email Workflow System

This application includes a comprehensive email workflow system with the following features:

### Visual Workflow Builder
- Drag-and-drop interface for creating complex workflows
- Node-based system with triggers, conditions, actions, and delays
- Real-time visual flowchart representation
- Support for both Application and Contract status changes

### Trigger Types
- **Application Status Changed**: Triggers when an application status changes
- **Application Created**: Triggers when a new application is created
- **Application Stuck at Status**: Triggers when an application remains at a status for a specified duration
- **Contract Status Changed**: Triggers when a contract status changes
- **Contract Stuck at Status**: Triggers when a contract remains at a status for a specified duration
- **User Registered**: Triggers when a new user registers
- **Time Delay**: Triggers after a specified time period
- **Document Uploaded**: Triggers when documents are uploaded
- **Inactivity**: Triggers after periods of user inactivity
- **Contract Signed**: Triggers when contracts are signed

### Workflow Node Types
- **Trigger Nodes**: Define when the workflow should start
- **Email Nodes**: Send templated emails to users
- **Delay Nodes**: Add time delays between actions
- **Condition Nodes**: Add conditional logic with true/false branches
- **Update Nodes**: Update application/contract status or other attributes

### Run-Once Logic
The system includes sophisticated execution tracking to prevent duplicate workflow runs:
- Workflows can be configured to run only once per target (application/contract)
- Execution tracking prevents infinite loops and duplicate notifications
- Automatic cleanup of old execution records

## Deployment Considerations

### Database Migrations
After deploying, ensure all migrations are run:
```bash
rails db:migrate
```

### Background Jobs
The workflow system relies on background jobs for processing:

1. **Configure Job Queue**: Ensure a job queue system is configured (Sidekiq recommended)
2. **Setup Recurring Jobs**: Configure the stuck status job to run periodically:
   ```ruby
   # In schedule.rb or cron jobs
   StuckStatusWorkflowJob.perform_later
   ```

### Required Background Jobs
- `StuckStatusWorkflowJob`: Processes stuck status workflows (should run every hour or as needed)
- `EmailWorkflowExecutorJob`: Executes individual email sending
- `DelayedWorkflowContinuationJob`: Handles workflow delays

### Email Configuration
Ensure SMTP settings are properly configured for email delivery:
```ruby
# In production.rb or environment-specific config
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  # Your SMTP configuration
}
```

### Environment Variables
Set the following environment variables:
- Database connection settings
- SMTP configuration for email delivery
- Redis URL for background jobs
- Any API keys for external services

### Performance Considerations
- The workflow execution tracking table will grow over time
- Automatic cleanup removes records older than 90 days
- Consider database indexing on frequently queried fields
- Monitor background job queue performance

### Monitoring
- Monitor workflow execution success rates
- Track email delivery rates
- Set up alerts for failed workflow executions
- Monitor database growth of execution tracking tables

### Security
- Ensure workflow builder is only accessible to authorized admin users
- Validate all workflow configurations before execution
- Sanitize email content to prevent XSS attacks
- Implement proper authorization checks for workflow management

## Testing

Run the test suite with:
```bash
rails test
```

## Services

- **Background Jobs**: ActiveJob with async processing
- **Email System**: ActionMailer with template support
- **Workflow Engine**: Custom workflow execution system
- **Status Tracking**: Comprehensive audit trail for all changes

## Development

Start the development server:
```bash
rails server
```

Access the visual workflow builder at:
```
http://localhost:3000/admin/email_workflows/new
```
