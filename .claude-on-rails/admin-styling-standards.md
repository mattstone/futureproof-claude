# Admin Styling Standards

**🚨 MANDATORY: All admin forms and pages MUST use these standard CSS classes 🚨**

This document defines the required styling standards for the admin section to ensure consistent look and feel across all admin pages.

## Core Principle

**Every admin page, form, and component must use the standardized CSS classes defined in `/app/assets/stylesheets/admin.css`**

## Standard Form Classes

### Form Inputs

Use **one of these classes** for all text inputs:
- `.admin-form-input` (preferred for new admin forms)
- `.form-input` (legacy, also acceptable)

```erb
<%= text_field_tag :stage_name, @stage['stage_name'],
    class: 'admin-form-input',
    placeholder: 'e.g., visitor_inquiry' %>
```

**Styling:**
- Width: 100%
- Padding: 10px 12px
- Border: 1px solid #d1d5db
- Border radius: 6px
- Focus: Blue border (#3b82f6) with subtle glow

### Form Selects

Use **one of these classes** for all select dropdowns:
- `.admin-form-select` (preferred for new admin forms)
- `.form-select` (legacy, also acceptable)

```erb
<%= select_tag :entry_trigger,
    options_for_select([...]),
    class: 'admin-form-select' %>
```

**Same styling as inputs**

### Form Textareas

Use `.admin-form-textarea` for all textarea fields:

```erb
<%= text_area_tag :stage_description, @stage['stage_description'],
    class: 'admin-form-textarea',
    rows: 3 %>
```

### Form Groups

Wrap each form field in `.admin-form-group`:

```erb
<div class="admin-form-group">
  <label>Stage Name (Technical ID)</label>
  <%= text_field_tag :stage_name, @stage['stage_name'],
      class: 'admin-form-input' %>
  <small>Lowercase, no spaces (use underscores)</small>
</div>
```

**Structure:**
- Labels: Bold (#374151), 14px, 8px bottom margin
- Inputs: Full width with standard styling
- Help text (`<small>`): Gray (#6b7280), 12px, 6px top margin

### Form Rows

For multiple inputs side-by-side, use `.admin-form-row`:

```erb
<div class="admin-form-row">
  <div class="admin-form-group">
    <label>Entry Trigger</label>
    <%= select_tag :entry_trigger, ..., class: 'admin-form-select' %>
  </div>

  <div class="admin-form-group">
    <label>Stage Color</label>
    <%= select_tag :stage_color, ..., class: 'admin-form-select' %>
  </div>
</div>
```

**Layout:** CSS Grid with auto-fit columns (minimum 200px)

## Standard Button Classes

### Primary Buttons

Use `.admin-btn.admin-btn-primary`:

```erb
<%= link_to 'Save', path, class: 'admin-btn admin-btn-primary' %>
<%= submit_tag 'Save Stage', class: 'admin-btn admin-btn-primary' %>
```

### Secondary Buttons

Use `.admin-btn.admin-btn-secondary`:

```erb
<%= link_to 'Cancel', path, class: 'admin-btn admin-btn-secondary' %>
```

### Danger Buttons

Use `.admin-btn.admin-btn-danger`:

```erb
<%= link_to 'Delete', path, class: 'admin-btn admin-btn-danger' %>
```

### Small Buttons

Add `.admin-btn-small` for compact buttons:

```erb
<button class="admin-btn-small admin-btn-danger" type="button">
  🗑️ Remove
</button>
```

## Standard Container Classes

### Form Container

Wrap admin forms in `.admin-form-container`:

```erb
<div class="admin-form-container">
  <h2>Edit Stage</h2>
  <%= form_with ... %>
</div>
```

**Styling:**
- White background
- 8px border radius
- Subtle shadow
- 32px padding

### Form Sections

Group related fields in `.admin-form-section`:

```erb
<div class="admin-form-section">
  <h3>Stage Information</h3>
  <!-- form groups here -->
</div>
```

**Styling:**
- Light gray background (#f8fafc)
- Rounded corners (12px)
- Colored accent bar before h3
- 24px padding

### Form Actions Bar

Place submit/cancel buttons in `.admin-form-actions`:

```erb
<div class="admin-form-actions">
  <%= link_to 'Cancel', path, class: 'admin-btn admin-btn-secondary' %>
  <%= submit_tag 'Save', class: 'admin-btn admin-btn-primary' %>
</div>
```

**Styling:**
- Flexbox layout, right-aligned
- Light background
- Top border separator
- Negative margins to extend to container edges

## Standard Table Classes

### Admin Tables

Use `.admin-table` for all data tables:

```erb
<table class="admin-table">
  <thead>
    <tr>
      <th>Name</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Value</td>
      <td>Active</td>
    </tr>
  </tbody>
</table>
```

### Status Badges

Use `.status-badge` with modifiers:

```erb
<span class="status-badge status-ok">Active</span>
<span class="status-badge status-error">Inactive</span>
<span class="status-badge status-pending">Pending</span>
```

## CSS Compliance Rules

### ❌ FORBIDDEN

1. **NO inline styles** - Violates CSP
   ```erb
   <!-- WRONG -->
   <div style="display: flex; gap: 8px;">
   ```

2. **NO Tailwind classes** - Not installed
   ```erb
   <!-- WRONG -->
   <div class="flex gap-2 bg-blue-500">
   ```

3. **NO Bootstrap classes** - Not installed
   ```erb
   <!-- WRONG -->
   <div class="btn btn-primary">
   ```

4. **NO inconsistent custom classes** - Use standards
   ```erb
   <!-- WRONG -->
   <input class="my-custom-input">
   ```

### ✅ REQUIRED

1. **Always use standard admin classes**
2. **Always wrap forms in containers**
3. **Always use form groups for fields**
4. **Always include proper labels**
5. **Always use admin button classes**

## Quick Reference

### Basic Form Structure

```erb
<div class="admin-form-container">
  <h2>Page Title</h2>

  <%= form_with url: path, method: :post, local: true do |f| %>
    <div class="admin-form-section">
      <h3>Section Title</h3>

      <div class="admin-form-group">
        <label>Field Label</label>
        <%= text_field_tag :field_name, @value,
            class: 'admin-form-input',
            placeholder: 'Enter value' %>
        <small>Help text explaining the field</small>
      </div>

      <div class="admin-form-row">
        <div class="admin-form-group">
          <label>First Field</label>
          <%= select_tag :field1, options, class: 'admin-form-select' %>
        </div>

        <div class="admin-form-group">
          <label>Second Field</label>
          <%= select_tag :field2, options, class: 'admin-form-select' %>
        </div>
      </div>
    </div>

    <div class="admin-form-actions">
      <%= link_to 'Cancel', back_path, class: 'admin-btn admin-btn-secondary' %>
      <%= submit_tag 'Save', class: 'admin-btn admin-btn-primary' %>
    </div>
  <% end %>
</div>
```

## Color Palette Reference

- **Primary Blue:** #3b82f6
- **Text Dark:** #1f2937
- **Text Medium:** #374151
- **Text Light:** #6b7280
- **Border:** #d1d5db
- **Border Light:** #e2e8f0
- **Background Light:** #f8fafc
- **Placeholder:** #9ca3af
- **Danger Red:** #dc2626

## Enforcement

**This standard is MANDATORY for all admin development. Any admin form or page that doesn't use these classes should be refactored to comply.**

When reviewing admin pages, check:
1. ✅ Uses `.admin-form-container` wrapper
2. ✅ Uses `.admin-form-section` for grouping
3. ✅ Uses `.admin-form-input` / `.admin-form-select` for controls
4. ✅ Uses `.admin-btn` classes for buttons
5. ✅ No inline styles
6. ✅ No framework classes (Tailwind/Bootstrap)
7. ✅ Consistent spacing and layout

---

**Last Updated:** 2025-10-02
**Reference Implementation:** `/app/views/admin/agent_lifecycle/stage_form.html.erb`
