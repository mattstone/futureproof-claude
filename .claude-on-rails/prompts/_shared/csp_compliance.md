# 🚨 CRITICAL: CSP (Content Security Policy) Compliance

**This project enforces strict CSP compliance. ALL code must be CSP-compliant.**

## ❌ FORBIDDEN - These will cause browser errors:
- `style="..."` - NO inline CSS styles
- `onclick="..."` - NO inline event handlers  
- `onchange="..."` - NO inline JavaScript
- `oninput="..."` - NO inline JavaScript
- `<script>...</script>` - NO inline JavaScript blocks
- `javascript:` URLs - NO JavaScript in href attributes

## ✅ REQUIRED - Use these instead:
- External CSS classes: `class="form-control"`
- Stimulus controllers: `data-controller="form"`
- Stimulus actions: `data-action="click->form#submit"`
- External stylesheets: `app/assets/stylesheets/*.css`
- Stimulus JavaScript: `app/javascript/controllers/*_controller.js`

## CSP-Compliant Examples
```erb
<!-- ❌ WRONG - CSP violation -->
<button onclick="alert('Hello')" style="color: red;">Click</button>

<!-- ✅ CORRECT - CSP compliant -->
<button data-controller="alert" 
        data-action="click->alert#show" 
        class="text-red">Click</button>
```

```ruby
# ✅ CORRECT - CSP compliant Turbo Stream
format.turbo_stream { render turbo_stream: turbo_stream.replace(@user) }

# ❌ WRONG - Would violate CSP if used inline JavaScript
# Never generate script tags with inline JavaScript in responses
```