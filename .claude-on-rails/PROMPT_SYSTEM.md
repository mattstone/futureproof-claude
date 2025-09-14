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

1. **Integration Testing First**: All code must be tested with real HTTP requests
2. **Custom CSS Only**: No Tailwind, Bootstrap, or external CSS frameworks
3. **CSP Compliance**: All frontend code must be CSP-compliant
4. **DRY**: Shared patterns prevent duplication
5. **Consistency**: All agents follow the same standards
6. **Maintainability**: Update patterns in one place
7. **Security**: CSP compliance enforced at the prompt level

## Benefits

- **Real Testing**: Integration tests prevent broken functionality reaching users
- **Custom CSS**: Consistent styling using project's admin.css classes only
- **No Framework Conflicts**: Eliminates CSS framework confusion and broken UI
- **No Inline Code**: Prevents CSP violations that cause browser errors
- **Stimulus-Only JavaScript**: Consistent interactive patterns
- **External CSS**: Maintainable styling approach
- **Testing Standards**: Mandatory integration testing with URL verification
- **Rails Conventions**: Proper Rails patterns enforced

This system ensures that all claude-on-rails generated code follows the project's strict CSP compliance requirements while maintaining Rails best practices.