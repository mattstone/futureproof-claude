# Email Template Style Guidelines

## Critical Rules

### Security Notification Templates
- **NEVER** use `padding: 0;` in sign-in details table cells
- **ALWAYS** use minimum `padding: 20px 24px;` for sign-in details boxes
- Reason: Zero padding makes text appear right against the border, looking unprofessional

### General Email Formatting
- Always use `border-collapse: collapse;` on tables
- Quote all style attribute values
- Test templates in multiple email clients

## Validation
Run `bin/rails email_templates:lint` to check for style regressions

## Generated on: 2025-09-03 05:39:42 UTC
