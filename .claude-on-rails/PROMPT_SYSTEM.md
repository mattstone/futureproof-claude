# Claude-on-Rails Prompt System

This Rails application uses a DRY (Don't Repeat Yourself) approach for claude-on-rails prompts.

## Architecture

### Shared Patterns (`_shared/`)
Common patterns used across multiple specialists:
- **CSP Compliance**: Critical security rules for all frontend code
- **Rails Conventions**: Core Rails principles and patterns  
- **Testing Patterns**: CSP compliance testing and common test approaches

### Specialist Prompts
Each specialist includes relevant shared patterns:
- **Architect**: Coordinates all specialists, enforces standards
- **Views**: Frontend templates, assets (CSP-compliant only)
- **Stimulus**: JavaScript controllers (CSP-compliant only)
- **Controllers**: Request handling, routing, responses
- **Models**: Database, ActiveRecord, migrations
- **Services**: Business logic, service objects
- **Tests**: Test coverage, CSP compliance testing

## Template System

Prompts use a simple include syntax:
```markdown
<!-- Include shared CSP compliance rules -->
{{> _shared/csp_compliance.md}}
```

This would be processed to include the contents of `_shared/csp_compliance.md`.

## Key Principles

1. **CSP Compliance First**: All frontend code must be CSP-compliant
2. **DRY**: Shared patterns prevent duplication
3. **Consistency**: All agents follow the same standards
4. **Maintainability**: Update patterns in one place
5. **Security**: CSP compliance enforced at the prompt level

## Benefits

- **No Inline Code**: Prevents CSP violations that cause browser errors
- **Stimulus-Only JavaScript**: Consistent interactive patterns
- **External CSS**: Maintainable styling approach
- **Testing Standards**: CSP compliance verification built into testing
- **Rails Conventions**: Proper Rails patterns enforced

This system ensures that all claude-on-rails generated code follows the project's strict CSP compliance requirements while maintaining Rails best practices.