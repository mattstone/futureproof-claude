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

## 🚨 CRITICAL: MANDATORY INTEGRATION TESTING 🚨
**EXPERT INTEGRATION TESTER PROTOCOL - NO EXCEPTIONS:**

### MANDATORY 7-STEP TESTING PROCESS:
1. **WRITE CODE** - Complete the implementation
2. **WRITE INTEGRATION TEST** - Create test with actual HTTP requests
3. **RUN INTEGRATION TEST** - Execute and verify it passes
4. **TEST ACTUAL URLS** - Use curl or browser to test real routes
5. **VERIFY HTML RENDERS** - Confirm no template/method errors
6. **TEST USER INTERACTIONS** - Forms, links, buttons work
7. **ONLY THEN CLAIM SUCCESS** - Never skip steps 1-6

### FORBIDDEN FAKE TESTING:
- ❌ Testing only data availability without page rendering
- ❌ Testing only helper methods without full request cycle
- ❌ Claiming "it should work" without URL verification
- ❌ Assuming templates work without rendering them

**Integration tests must use actual HTTP requests and verify HTML output.**

## 🚨 CRITICAL: CSS FRAMEWORK RESTRICTIONS 🚨
**THIS PROJECT USES 100% CUSTOM CSS - NO EXTERNAL FRAMEWORKS:**

### FORBIDDEN CSS CLASSES:
- ❌ **Tailwind**: `text-*`, `bg-*`, `flex`, `grid`, `space-*`, `gap-*`, `mb-*`, `px-*`, etc.
- ❌ **Bootstrap**: `btn-primary`, `container`, `row`, `col-*`, `d-flex`, etc.
- ❌ **ANY external CSS framework classes**

### REQUIRED CUSTOM CSS CLASSES:
- ✅ **Tables**: `admin-table`
- ✅ **Buttons**: `admin-btn`, `admin-btn-primary`, `admin-btn-secondary`, etc.
- ✅ **Status**: `status-badge`, `status-ok`, `status-complete`, etc.
- ✅ **Layout**: `admin-actions-bar`, `admin-search`, `admin-actions`
- ✅ **Forms**: `admin-form-*` classes

**Check `/app/assets/stylesheets/admin.css` for available classes. Never assume external frameworks exist.**

## 🚨 CRITICAL: JavaScript/Hotwire Architectural Rule 🚨
**MANDATORY SEPARATION OF CONCERNS - THIS RULE MUST ALWAYS BE ENFORCED:**

### JavaScript (Stimulus Controllers)
JavaScript should ONLY handle UI interactions and visual elements:
- ✅ Drag & drop functionality
- ✅ Drawing connection lines
- ✅ Zoom and pan controls
- ✅ Panel visibility toggles
- ✅ Animations and visual feedback
- ✅ Canvas interactions
- ✅ Keyboard shortcuts for UI actions

### Rails/Hotwire (Server-Side)
All business logic must be handled server-side with Hotwire/Turbo:
- ✅ Dropdown option generation based on data
- ✅ Form validation and processing
- ✅ Database operations
- ✅ Workflow step processing
- ✅ Trigger condition logic
- ✅ Email template selection
- ✅ Data filtering and searching
- ✅ State management and persistence

### FORBIDDEN JavaScript Patterns
- ❌ No AJAX requests for business logic
- ❌ No client-side data validation (beyond basic HTML5)
- ❌ No workflow processing in JavaScript
- ❌ No template selection logic in JavaScript
- ❌ No database queries or updates from JavaScript
- ❌ No business rule implementation in JavaScript

**Use Hotwire/Turbo Frames for all server communication. Use Stimulus only for UI interactions.**

## 🚨 CRITICAL: CSP COMPLIANCE 🚨
**NEVER use inline styles, scripts, or event handlers. This project has strict CSP requirements.**
- NO `<style>` tags or `style=""` attributes
- NO `<script>` tags with inline code or `onclick=""` handlers
- ALL CSS must be in external files under `/app/assets/stylesheets/`
- ALL JavaScript must be in external files under `/app/javascript/`
- See `.claude-on-rails/csp-compliance.md` for full guidelines