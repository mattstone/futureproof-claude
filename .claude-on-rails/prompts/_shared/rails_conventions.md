# Rails Conventions & Best Practices

## Core Principles
- **RESTful design** - Follow standard resource patterns
- **DRY (Don't Repeat Yourself)** - Extract common patterns  
- **Convention over configuration** - Use Rails defaults
- **Single Responsibility** - Each class/method does one thing
- **Security by default** - Always consider security implications

## Code Organization
- Keep controllers thin - delegate to services/models
- Extract complex logic to service objects
- Use partials for reusable view components
- Follow Rails naming conventions
- Organize assets logically

## Common Patterns

### Strong Parameters
```ruby
def resource_params
  params.expect(resource: [:name, :email, :status])
end
```

### Service Objects
```ruby
class ProcessOrder
  def initialize(order, payment_method)
    @order = order
    @payment_method = payment_method
  end
  
  def call
    # Single responsibility: process one order
  end
end
```

### View Helpers
```ruby
def format_date(date)
  date.strftime("%B %d, %Y") if date.present?
end
```

## Error Handling
- Use rescue_from for common exceptions
- Provide meaningful error messages
- Handle edge cases gracefully
- Always validate user input