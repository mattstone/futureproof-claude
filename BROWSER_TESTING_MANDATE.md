# 🚨 CRITICAL: BROWSER TESTING MANDATE 🚨

## NEVER CLAIM ANYTHING IS FIXED WITHOUT BROWSER TESTING

**Date Created**: 2025-09-23
**Lesson Learned**: Spent 2+ hours debugging ownership field visibility that could have been solved in 15 minutes with proper browser testing.

## MANDATORY PROCESS FOR ALL UI CHANGES:

1. **Make code changes**
2. **IMMEDIATELY test in actual browser**
3. **Only then claim it's working**

## NEVER DO THIS AGAIN:
- ❌ Claiming "integration tests pass so it's fixed"
- ❌ Saying "the logic looks correct so it should work"
- ❌ Assuming server-side rendering works without browser verification
- ❌ Debugging complex CSS/JavaScript issues without browser console

## ALWAYS DO THIS:
- ✅ Open browser, test the actual UI
- ✅ Check browser console for errors
- ✅ Test user interactions (clicks, form changes, etc.)
- ✅ Verify visual behavior matches requirements

## THE ROOT CAUSE:
The issue was CSS specificity - `.js-hidden { display: none; }` was being overridden. This could ONLY be discovered by:
1. Seeing fields not hiding in browser
2. Checking browser dev tools CSS panel
3. Adding `!important` to fix specificity

**NO AMOUNT OF SERVER-SIDE TESTING WOULD HAVE FOUND THIS.**

## COMMITMENT:
I will ALWAYS test UI changes in an actual browser before claiming they work.