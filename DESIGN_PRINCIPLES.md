# Futureproof Design Principles

This document captures the design principles and styling guidelines for maintaining visual consistency across the Futureproof application.

## Demo Notice Component Design Principles

### Visual Hierarchy and Spacing

**Problem Solved**: The original demo notice had excessive spacing and took up 100% width, creating visual clash with the rest of the application.

**Solution Applied**:
- **Reduced vertical spacing**: Changed from 24px bottom margin to 12px for tighter integration with content flow
- **Added horizontal constraints**: 24px left/right margins prevent full-width spanning
- **Optimized internal padding**: Reduced from 20px to 16px vertical, maintaining 20px horizontal

### Core Design Principles

#### 1. **Proportional Spacing**
- Components should not dominate their containers with excessive whitespace
- Vertical spacing should create natural reading flow without jarring gaps
- Horizontal margins should provide breathing room while maintaining content relationships

#### 2. **Width Constraints for Harmony**
- Alert/notice components should not span 100% of their parent container
- Use side margins (typically 24px) to create visual boundaries
- This prevents components from visually "shouting" over other content

#### 3. **Consistent Padding Philosophy**
- Reduce vertical padding when component margins handle spacing
- Maintain horizontal padding for internal content breathing room
- Formula: `padding: [reduced-vertical]px [standard-horizontal]px`

#### 4. **Visual Integration**
- New components should complement, not clash with existing design
- Maintain consistent border radius (8px) and color schemes
- Alert styling: `#fef2f2` background with `#dc2626` border for demo notices

### Implementation Pattern

```css
.site-demo-notice {
  background: #fef2f2;
  border: 2px solid #dc2626;
  border-radius: 8px;
  padding: 16px 20px;           /* Reduced vertical, maintained horizontal */
  margin: 0 24px 12px 24px;     /* Side margins prevent full-width, reduced bottom */
  text-align: center;
}
```

### When to Apply These Principles

1. **Alert/Notice Components**: Always apply width constraints and proportional spacing
2. **Form Enhancements**: Any new form-related messaging or helpers
3. **Status Indicators**: System messages, validation feedback, progress indicators
4. **Overlay Content**: Modals, tooltips, or any content that sits "on top" of main content

### Testing Philosophy

- Always test visual changes with integration tests
- Verify components render without errors
- Check that content relationships remain visually logical
- Ensure consistent behavior across different page contexts

### Future Component Guidelines

When adding new UI components:

1. **Start with constraints**: Don't default to full-width spanning
2. **Consider context**: How does this component relate to surrounding content?
3. **Use proportional spacing**: Smaller gaps for related content, larger gaps for section breaks
4. **Maintain color consistency**: Use established color palette
5. **Test integration**: Verify the component enhances rather than disrupts the user experience

## Color Palette Reference

### Alert/Notice Colors
- **Demo/Warning**: Background `#fef2f2`, Border `#dc2626`, Text `#dc2626`
- **Success**: Background `#f0fdf4`, Border `#059669`, Text `#059669`
- **Error**: Background `#fef2f2`, Border `#dc2626`, Text `#dc2626`
- **Info**: Background `#f0f9ff`, Border `#0284c7`, Text `#0284c7`

### Typography
- **Title**: 18px, bold, colored to match border
- **Body text**: 16px, `#666` color, 1.4 line-height for readability

---

*This document should be updated whenever design decisions are made to ensure consistency across the application.*