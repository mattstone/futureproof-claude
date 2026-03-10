module AccessibilityHelper
  # Status badge with ARIA label
  def status_badge(status, options = {})
    label = status.humanize
    classes = "status-badge status-#{status} #{options[:class]}"
    content_tag(:span, label, {
      class: classes,
      role: 'status',
      'aria-label' => "Application status: #{label}"
    })
  end

  # Form input with associated label
  def labeled_input(form, field, label_text = nil, options = {})
    label_text ||= field.to_s.humanize
    id = "#{form.object_name}_#{field}"
    
    content_tag(:div, class: 'form-group') do
      form.label(field, label_text, for: id, class: 'form-label') +
      form.send(options[:input_type] || :text_field, field, {
        id: id,
        class: 'form-control',
        'aria-describedby' => options[:error] ? "#{id}-error" : nil,
        **options.except(:input_type, :error)
      }) +
      (options[:error] ? error_message(id, options[:error]) : '')
    end
  end

  # Error message with ARIA alert
  def error_message(field_id, message)
    content_tag(:span, message, {
      id: "#{field_id}-error",
      class: 'error-message',
      role: 'alert'
    })
  end

  # Icon with accessible label
  def icon_button(icon_class, label, options = {})
    content_tag(:button, {
      type: options[:type] || 'button',
      class: "btn-icon #{options[:class]}",
      'aria-label' => label,
      title: label,
      **options.except(:class, :type)
    }) do
      content_tag(:i, '', class: icon_class)
    end
  end

  # Metric card with semantic structure
  def metric_card(label, value, detail = nil)
    content_tag(:div, class: 'metric-card') do
      content_tag(:div, label, class: 'metric-label') +
      content_tag(:div, value, {
        class: 'metric-value',
        role: 'status',
        'aria-label' => "#{label}: #{value}"
      }) +
      (detail ? content_tag(:div, detail, class: 'metric-detail') : '')
    end
  end

  # Table with ARIA attributes
  def accessible_table(collection, &block)
    content_tag(:table, class: 'table') do
      content_tag(:thead) { block_given? && block.call(:thead) } +
      content_tag(:tbody) do
        collection.map { |item| yield(item) if block_given? }.join.html_safe
      end
    end
  end

  # Live region for dynamic updates
  def live_region(content, politeness = 'polite', atomic = true)
    content_tag(:div, content, {
      class: 'live-region sr-only',
      'aria-live' => politeness,
      'aria-atomic' => atomic.to_s
    })
  end

  # Skip to main content link
  def skip_to_main_link
    link_to 'Skip to main content', '#main-content', {
      class: 'skip-link',
      'aria-label' => 'Skip to main content'
    }
  end
end
