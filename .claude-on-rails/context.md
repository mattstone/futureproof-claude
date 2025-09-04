# ClaudeOnRails Context

This project uses ClaudeOnRails with a swarm of specialized agents for Rails development.

## Project Information
- **Rails Version**: 8.0.2
- **Ruby Version**: 3.3.6
- **Project Type**: Full-stack Rails
- **Test Framework**: Minitest
- **Turbo/Stimulus**: Enabled

## Swarm Configuration

The claude-swarm.yml file defines specialized agents for different aspects of Rails development:
- Each agent has specific expertise and works in designated directories
- Agents collaborate to implement features across all layers
- The architect agent coordinates the team

## Development Guidelines

When working on this project:
- Follow Rails conventions and best practices
- Write tests for all new functionality
- Use strong parameters in controllers
- Keep models focused with single responsibilities
- Extract complex business logic to service objects
- Ensure proper database indexing for foreign keys and queries

## 🚨 CRITICAL: CSP COMPLIANCE 🚨
**NEVER use inline styles, scripts, or event handlers. This project has strict CSP requirements.**
- NO `<style>` tags or `style=""` attributes
- NO `<script>` tags with inline code or `onclick=""` handlers
- ALL CSS must be in external files under `/app/assets/stylesheets/`
- ALL JavaScript must be in external files under `/app/javascript/`
- See `.claude-on-rails/csp-compliance.md` for full guidelines