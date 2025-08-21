# Testing Patterns & CSP Compliance

## CSP Compliance Testing (Required for all browser tests)

```ruby
# Minitest pattern
test "page loads without CSP violations" do
  visit path_under_test
  
  # Verify no CSP violations
  assert_no_selector '[style]'
  assert_no_selector '[onclick]'
  assert_no_selector '[onchange]'
  assert_no_selector '[oninput]'
  assert_no_selector 'script:not([src])'
  
  # Verify Stimulus controllers are present
  assert_selector '[data-controller]'
  assert_selector '[data-action]'
end

# RSpec pattern  
it 'loads without CSP violations' do
  visit path_under_test
  
  expect(page).to have_no_selector('[style]')
  expect(page).to have_no_selector('[onclick]')
  expect(page).to have_selector('[data-controller]')
end
```

## Common Testing Patterns

### Arrange-Act-Assert
1. **Arrange**: Set up test data
2. **Act**: Execute the code being tested  
3. **Assert**: Verify expected outcome

### Browser Test Priorities
1. **High**: User workflows, JavaScript interactions, CSP compliance
2. **Medium**: Admin interfaces, error handling, responsive design
3. **Low**: Static pages, simple CRUD (covered by integration tests)

### Async Content Testing
```ruby
# Wait for dynamic content
expect(page).to have_selector('.results', wait: 10)
expect(page).to have_no_selector('.loading', wait: 5)
```