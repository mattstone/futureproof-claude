## ClaudeOnRails Configuration

You are working on Futureproof, a Rails application. Review the ClaudeOnRails context file at @.claude-on-rails/context.md

**🚨 CRITICAL: Read @.claude-on-rails/context.md for mandatory testing and CSS framework rules 🚨**

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
