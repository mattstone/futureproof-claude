## 🚀 SESSION STARTUP - MANDATORY

**Before starting any work, spend 10-15 minutes familiarizing yourself with this application.**

Context matters more than speed. Many mistakes come from making "sensible" changes that don't fit the application's specific patterns, architecture, or business logic.

### Startup Checklist:
1. **Read project configuration**: Review `@.claude-on-rails/context.md` and this file thoroughly
2. **Understand the domain**: This is Futureproof - understand what the app does and its business context
3. **Review recent changes**: Check `git log --oneline -20` and `git status` to understand current state
4. **Explore key areas**: Before touching any area of the codebase, read the relevant models, controllers, and views first
5. **Ask clarifying questions**: If something is unclear about the app's purpose or patterns, ask before assuming

### Key Principle:
**Never make changes that "look sensible in general" but don't fit THIS application's specific context.** When in doubt, explore first, ask questions, and understand before acting.

---

## ClaudeOnRails Configuration

You are working on Futureproof, a Rails application. Review the ClaudeOnRails context file at @.claude-on-rails/context.md

**🚨 CRITICAL: Read @.claude-on-rails/context.md for mandatory testing and CSS framework rules 🚨**

## 📐 DESIGN PRINCIPLES

**Visual Consistency Guidelines**: See @DESIGN_PRINCIPLES.md for established design patterns and styling principles.

- Component spacing and width constraints
- Color palette and typography standards
- Alert/notice component best practices
- Integration testing for visual changes

## 🚨 UPDATED ARCHITECTURAL RULE 🚨

**Stimulus Only, No AJAX/Turbo (PERMANENT & ENFORCEABLE)**

**NEW RULE**: Use Stimulus only, no AJAX/Turbo for dynamic UI updates. It's okay to sacrifice some functionality as a tradeoff for code simplicity.

Guidelines:
- Prefer client-side JavaScript solutions using Stimulus controllers
- Avoid Turbo Frames, AJAX requests, or server-side partial rendering for dynamic content
- Keep UI interactions simple and predictable
- Sacrifice complex functionality in favor of reliability and simplicity
- Document any departures from this principle with clear justification

**This overrides the previous Hotwire rule based on real-world complexity issues.**
