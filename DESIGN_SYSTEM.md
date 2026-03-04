# FutureProof Design System

**Based on:** Apple Human Interface Guidelines  
**File:** `/app/assets/stylesheets/design_system.css`

## Colors

| Variable | Value | Use |
|----------|-------|-----|
| `--fp-primary` | #007AFF | Primary actions, links |
| `--fp-secondary` | #5856D6 | Secondary accents |
| `--fp-success` | #34C759 | Success states, confirmations |
| `--fp-warning` | #FF9500 | Warnings, attention needed |
| `--fp-error` | #FF3B30 | Errors, destructive actions |
| `--fp-text-primary` | #1D1D1F | Body text |
| `--fp-text-secondary` | #636366 | Descriptions, labels |
| `--fp-bg-primary` | #FFFFFF | Card backgrounds |
| `--fp-bg-secondary` | #F5F5F7 | Page background |

## Typography

- **Display:** SF Pro Display (-apple-system)
- **Body:** SF Pro Text (-apple-system)
- **Mono:** SF Mono (code blocks)
- **Sizes:** xs(11), sm(13), base(16), lg(20), xl(24), 2xl(28), 3xl(34), 4xl(40)

## Spacing

8px grid: 4, 8, 16, 24, 32, 48px

## Components

### Buttons
```html
<button class="fp-btn fp-btn-primary">Primary</button>
<button class="fp-btn fp-btn-secondary">Secondary</button>
<button class="fp-btn fp-btn-success">Success</button>
<button class="fp-btn fp-btn-danger">Danger</button>
<button class="fp-btn fp-btn-outline">Outline</button>
<button class="fp-btn fp-btn-sm">Small</button>
<button class="fp-btn fp-btn-lg">Large</button>
```

### Cards
```html
<div class="fp-card">
  <div class="fp-card-header">
    <h3 class="fp-card-title">Title</h3>
  </div>
  Content here
</div>
```

### Forms
```html
<div class="fp-form-group">
  <label class="fp-label">Field Name</label>
  <input class="fp-input" type="text">
  <span class="fp-form-hint">Helper text</span>
</div>
```

### Badges
```html
<span class="fp-badge fp-badge-success">Active</span>
<span class="fp-badge fp-badge-warning">Pending</span>
<span class="fp-badge fp-badge-error">Rejected</span>
<span class="fp-badge fp-badge-info">Info</span>
```

### Alerts
```html
<div class="fp-alert fp-alert-success">
  <span class="fp-alert-icon">✅</span>
  <div>Success message</div>
</div>
```

### Layout
```html
<div class="fp-container">
  <div class="fp-grid fp-grid-3">
    <div class="fp-card">...</div>
    <div class="fp-card">...</div>
    <div class="fp-card">...</div>
  </div>
</div>
```

## Accessibility

- Focus visible: 3px blue outline
- Skip-to-content link
- Reduced motion support
- High contrast mode support
- Minimum touch targets: 44px
- WCAG 2.1 AA colour contrast ratios
