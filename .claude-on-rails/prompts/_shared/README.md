# Shared Claude-on-Rails Patterns

This directory contains shared patterns that are included in multiple specialist prompts to follow the DRY (Don't Repeat Yourself) principle.

## Files

### `csp_compliance.md`
- CSP (Content Security Policy) compliance rules
- Forbidden patterns that cause browser errors
- Required CSP-compliant alternatives
- Code examples

### `rails_conventions.md`  
- Core Rails principles (RESTful design, DRY, convention over configuration)
- Common patterns for strong parameters, service objects, view helpers
- Error handling guidelines
- Code organization best practices

### `testing_patterns.md`
- CSP compliance testing patterns (required for all browser tests)
- Common testing approaches (Arrange-Act-Assert)
- Browser test priorities
- Async content testing patterns

## Usage in Prompts

These shared files are included in specialist prompts using comment syntax:

```markdown
<!-- Include shared CSP compliance rules -->
{{> _shared/csp_compliance.md}}

<!-- Include shared Rails conventions -->
{{> _shared/rails_conventions.md}}

<!-- Include shared testing patterns -->
{{> _shared/testing_patterns.md}}
```

## Benefits

1. **DRY Principle**: No duplication of common patterns across prompts
2. **Consistency**: All agents follow the same standards
3. **Maintainability**: Update patterns in one place, affects all agents
4. **Clarity**: Specialist prompts focus on their specific expertise
5. **CSP Enforcement**: Consistent CSP compliance across all agents