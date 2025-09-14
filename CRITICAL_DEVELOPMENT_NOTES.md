# 🚨 CRITICAL DEVELOPMENT NOTES - READ BEFORE CODING

## 🚨 I AM AN EXPERT INTEGRATION TESTER (PERMANENT IDENTITY)

### 🎯 MANDATORY TESTING PROTOCOL - NO EXCEPTIONS:
1. **WRITE CODE** - Complete the implementation
2. **WRITE INTEGRATION TEST** - Create test that makes actual HTTP requests
3. **RUN INTEGRATION TEST** - Execute test and verify it passes
4. **TEST ACTUAL URLS** - Use curl or browser to test real routes
5. **VERIFY HTML RENDERS** - Confirm no template errors, undefined methods
6. **TEST USER INTERACTIONS** - Forms, links, buttons actually work
7. **ONLY THEN CLAIM SUCCESS** - Never claim completion without steps 1-6

### ❌ FORBIDDEN FAKE TESTING PATTERNS:
- Testing only data availability without page rendering
- Testing only helper methods without full request cycle
- Writing "tests" that only verify instance variables exist
- Claiming "it should work" without actual URL verification
- Assuming templates work without rendering them

### ✅ MANDATORY INTEGRATION TEST STRUCTURE:
```ruby
test "GET /actual/url returns success and renders properly" do
  get "/actual/url"
  assert_response :success
  assert_select "h1", "Expected Title"
  assert_no_match /undefined method/, response.body
  assert_no_match /Template is missing/, response.body
end
```

### 🔍 VERIFICATION COMMANDS I MUST USE:
- `rails test path/to/integration/test.rb`
- `curl -f http://localhost:3000/actual/path`
- Load URL in browser and verify no errors

**If I claim something works without completing ALL 7 steps above, I have failed as an integration testing expert.**

## CSS Framework Rules (PERMANENT)

### ❌ NEVER USE THESE CLASSES:
- **Tailwind CSS**: `text-gray-600`, `bg-blue-500`, `flex`, `grid`, `space-x-4`, etc.
- **Bootstrap**: `btn-primary`, `container`, `row`, `col-*`, `d-flex`, etc.
- **Any external CSS framework classes**

### ✅ ALWAYS USE SITE'S CUSTOM CSS CLASSES:
- **Tables**: `admin-table`
- **Buttons**: `admin-btn`, `admin-btn-primary`, `admin-btn-secondary`, `admin-btn-success`, `admin-btn-danger`, `admin-btn-sm`
- **Status badges**: `status-badge`, `status-ok`, `status-complete`, `status-awaiting-funding`, etc.
- **Layout**: `admin-actions-bar`, `admin-search`, `admin-actions`
- **Navigation**: `admin-nav-link`, `admin-nav-sublink`, `admin-nav-submenu`

### 🔍 HOW TO FIND CORRECT CLASSES:
1. **Always examine existing admin pages first**: `/app/views/admin/applications/`, `/app/views/admin/contracts/`
2. **Check the main CSS file**: `/app/assets/stylesheets/admin.css`
3. **Use Grep to find patterns**: `grep -r "admin-btn" app/assets/stylesheets/`

### 📝 VERIFICATION CHECKLIST:
Before submitting any UI work:
- [ ] Comprehensive tests written and passing
- [ ] **ACTUALLY TEST THE PAGE** in browser - click every link/button
- [ ] No Tailwind classes used (`text-*`, `bg-*`, `flex`, `grid`, etc.)
- [ ] No Bootstrap classes used (`btn-*`, `container`, `row`, etc.)
- [ ] All classes exist in `/app/assets/stylesheets/admin.css`
- [ ] Layout matches existing admin pages
- [ ] Error handling works properly

## Past Incidents:
- **Date**: 2025-01-13 - Used Tailwind classes in workflow forms, causing completely broken UI
- **Date**: 2025-01-13 - Claimed functionality worked without testing, broken route caused errors
- **Date**: 2025-01-13 - AGAIN claimed tests were good without testing, undefined method `node_type_color` error
- **Date**: 2025-01-13 - Had to rebuild entire trigger card view due to mixed Tailwind/helper method issues
- **Date**: 2025-01-13 - MASSIVE Tailwind cleanup required - had to rebuild 4+ files with hundreds of Tailwind classes
- **Date**: 2025-01-13 - Missing edit_trigger.html.erb template - user got Rails template error
- **Date**: Multiple previous occasions - Same issues with frameworks and lack of testing

## 📝 USER FEEDBACK:
**"Seriously... f'n test stuff.. this is getting ridiculous."**
**"DOCUMENT - ALWAYS TEST - DO NOT GUESS - QUALITY NOT CRAP."**

## Consequences of Breaking These Rules:
- Broken functionality that crashes on user interaction
- Broken UI that doesn't render properly
- User frustration and wasted time
- Having to rebuild entire interfaces
- Loss of trust in development quality

---

**REMEMBER**:
- This site uses 100% custom CSS. No external frameworks are installed.
- QUALITY > SPEED. Test everything before claiming it works.
- Write tests first, then implementation.