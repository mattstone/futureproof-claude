# CRITICAL: Content Security Policy (CSP) Compliance

## 🚨 NEVER FORGET: NO INLINE CODE EVER 🚨

**This is a HARD REQUIREMENT for this project. Violating CSP causes issues for internet users.**

### BANNED - NEVER USE:
- `<style>` tags in HTML/ERB files
- `style="..."` attributes on HTML elements  
- `<script>` tags with inline JavaScript in HTML/ERB files
- `onclick="..."` or any inline event handlers
- Any inline CSS or JavaScript whatsoever

### REQUIRED APPROACH:
1. **CSS**: Always use external stylesheets in `/app/assets/stylesheets/`
   - Add imports to `application.css` 
   - Use classes, never inline styles

2. **JavaScript**: Always use external modules in `/app/javascript/`
   - Add pins to `config/importmap.rb`
   - Import modules with `javascript_import_module_tag`
   - Use data attributes and event listeners, never inline handlers

### VIOLATION CONSEQUENCES:
- Breaks for users with strict CSP policies
- Creates security vulnerabilities
- User explicitly stated "no inline stuff ever again"

### COMPLIANCE CHECKLIST:
- [ ] No `<style>` tags anywhere
- [ ] No `style=""` attributes
- [ ] No `<script>` tags with inline code
- [ ] No `onclick=""` or similar attributes
- [ ] All CSS in external files under `/app/assets/stylesheets/`
- [ ] All JS in external files under `/app/javascript/`
- [ ] Proper asset pipeline configuration

**REMEMBER: When in doubt, use external files. CSP compliance is NON-NEGOTIABLE.**