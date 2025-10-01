# Pre-Action Checklist for Claude Code

## MANDATORY: Read Before EVERY Code Change

This checklist MUST be consulted before making ANY code changes to this project.

---

## 🚨 CRITICAL CSP COMPLIANCE 🚨

**NEVER use inline styles, scripts, or event handlers**

❌ **FORBIDDEN:**
- `<style>` tags anywhere in views
- `style=""` attributes on HTML elements
- `<script>` tags with inline code
- `onclick=""` or any inline event handlers

✅ **REQUIRED:**
- ALL CSS must be in `/app/assets/stylesheets/` external files
- ALL JavaScript must be in `/app/javascript/` external files
- Use Stimulus data attributes for event handlers

**If adding CSS:** Extract to appropriate stylesheet file FIRST, never inline.

---

## 🎨 CSS Framework Rules

**This project uses 100% CUSTOM CSS - NO external frameworks**

❌ **FORBIDDEN Classes:**
- Tailwind: `text-*`, `bg-*`, `flex`, `grid`, `space-*`, `gap-*`, `mb-*`, `px-*`
- Bootstrap: `btn-primary`, `container`, `row`, `col-*`, `d-flex`
- ANY external CSS framework classes

✅ **REQUIRED:**
- Use existing custom classes from `/app/assets/stylesheets/`
- Check `admin.css` for available admin classes
- Check `homepage.css` for homepage classes
- Check `custom_framework.css` for site-wide classes

---

## 🏗️ Architecture Rules

### JavaScript/Hotwire Separation

**JavaScript (Stimulus):** UI interactions ONLY
- ✅ Drag & drop, animations, visual feedback
- ✅ Canvas interactions, keyboard shortcuts
- ✅ Panel toggles, zoom/pan controls

**Rails/Hotwire:** ALL business logic
- ✅ Form validation & processing
- ✅ Database operations
- ✅ Workflow processing
- ✅ Data filtering & searching

❌ **FORBIDDEN in JavaScript:**
- AJAX requests for business logic
- Client-side data validation (beyond HTML5)
- Workflow/template processing
- Database queries or updates

### Stimulus Only Rule

**Use Stimulus only, no AJAX/Turbo for dynamic UI**
- ✅ Prefer client-side JavaScript solutions
- ✅ Keep UI interactions simple and predictable
- ✅ Sacrifice functionality for reliability/simplicity
- ❌ Avoid Turbo Frames, AJAX requests, server-side partial rendering

---

## 🧪 Testing Requirements

**MANDATORY 7-STEP TESTING PROCESS:**

1. ✅ Write code
2. ✅ Write integration test with actual HTTP requests
3. ✅ Run integration test and verify it passes
4. ✅ Test actual URLs with curl or browser
5. ✅ Verify HTML renders without errors
6. ✅ Test user interactions (forms, links, buttons)
7. ✅ ONLY THEN claim success

❌ **FORBIDDEN:**
- Testing only data availability without page rendering
- Testing only helper methods without full request cycle
- Assuming templates work without rendering them
- Claiming "it should work" without URL verification

---

## 🚀 Deployment Rules

**NEVER touch Fly deployment config unless explicitly asked**

Protected files:
- `fly.toml`
- `Dockerfile`
- `bin/docker-entrypoint`

Backups exist in `.backups/fly/` - use these to restore if needed.

---

## 📋 Before Making ANY Change - Ask Yourself:

1. ⚠️ Am I adding inline styles/scripts? → STOP, use external files
2. ⚠️ Am I using Tailwind/Bootstrap classes? → STOP, use custom CSS
3. ⚠️ Am I putting business logic in JavaScript? → STOP, use Rails/Hotwire
4. ⚠️ Have I written integration tests? → STOP, write tests first
5. ⚠️ Am I changing deployment files? → STOP, unless explicitly requested

---

## ✅ Action Plan

**Every time I'm about to make a code change:**

1. **PAUSE** - Read this checklist
2. **CHECK** - Verify compliance with ALL rules
3. **PLAN** - Ensure approach follows guidelines
4. **EXECUTE** - Make the change
5. **VERIFY** - Test according to requirements

---

## 📝 Commitment

I will read this checklist before EVERY code change. No exceptions.
Breaking these rules is not acceptable and causes deployment issues,
wasted time, and frustration.

**These are not suggestions - they are REQUIREMENTS.**
