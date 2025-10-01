# Quick Reference - Critical Rules

## Before ANY code change, verify:

### ❌ CSP VIOLATIONS
- No `<style>` tags
- No `style=""` attributes
- No `<script>` inline code
- No `onclick=""` handlers

### ❌ WRONG CSS FRAMEWORKS
- No Tailwind classes (`text-*`, `bg-*`, `flex`, etc.)
- No Bootstrap classes (`btn-primary`, `container`, etc.)

### ❌ WRONG ARCHITECTURE
- No business logic in JavaScript
- No AJAX for data operations
- No Turbo Frames/partial rendering

### ✅ CORRECT APPROACH
- CSS → External `.css` files only
- JavaScript → Stimulus controllers only (UI interactions)
- Business logic → Rails/Hotwire only
- Always write integration tests
- Never touch deployment files

## Read full checklist: `.claude/pre-action-checklist.md`
