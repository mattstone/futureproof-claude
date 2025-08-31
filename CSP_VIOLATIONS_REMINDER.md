# ⚠️ CRITICAL DEVELOPMENT REMINDERS ⚠️

## NEVER USE INLINE STYLES OR JAVASCRIPT

This will cause CSP (Content Security Policy) violations and require complete rework.

### ❌ FORBIDDEN:
- `<style>` tags in HTML/ERB files
- `<script>` tags in HTML/ERB files  
- `style="..."` attributes
- `onclick="..."` attributes
- Any inline JavaScript or CSS

## NEVER USE BOOTSTRAP OR TAILWIND CLASSES

Bootstrap and Tailwind CSS are NOT available in this project and will cause rework.

### ❌ FORBIDDEN CSS CLASSES:
- Any Bootstrap classes (btn, container, row, col-, etc.)
- Any Tailwind classes (flex, grid, text-, bg-, etc.)
- Any utility framework classes

### ✅ CORRECT APPROACH:
- Put CSS in separate `.css` files in `app/assets/stylesheets/`
- Put JavaScript in separate `.js` files in `app/javascript/`
- Use Stimulus controllers for interactive behavior
- Write custom CSS classes instead of framework classes
- Use semantic HTML with custom styling

### BEFORE COMMITTING ANY CODE:
1. Search for `<style` - should return 0 results
2. Search for `<script` - should return 0 results  
3. Search for `style="` - should return 0 results
4. Search for `onclick="` - should return 0 results
5. Check for Bootstrap/Tailwind classes - should return 0 results
6. **ALWAYS TEST UI CHANGES IN BROWSER** - View the actual page to confirm changes worked

## CRITICAL: ALWAYS BROWSER TEST UI CHANGES

After making any UI/styling changes, ALWAYS:
- Start the Rails server if needed
- Open the page in browser 
- Verify the changes are actually visible
- Take screenshots or describe what you see
- Don't claim something is "fixed" without browser confirmation

## ⚠️ CRITICAL EMAIL STYLING REMINDER ⚠️

### SECURITY ALERT EMAIL PADDING ISSUE - KEEPS RECURRING

The security alert email (`app/views/user_mailer/security_notification.html.erb`) sign-in details table cells MUST have adequate padding or the email looks unprofessional.

**CURRENT CORRECT PADDING:** `padding: 20px 24px;`
**NEVER REDUCE TO:** `padding: 16px 20px;` (looks unprofessional)

This issue has been reported multiple times and keeps regressing. The padding in the sign-in details table cells must remain at least `20px 24px` to look professional in email clients.

**Location:** Lines 36-151 in `app/views/user_mailer/security_notification.html.erb`
**Critical cells:** Time, Browser, Operating System, Language, Device Type, IP Address, Location

DO NOT REDUCE THE PADDING IN THESE CELLS - it makes the email look unprofessional and has been fixed multiple times.

## These reminders exist because these mistakes have caused multiple complete rewrites.