module ApplicationHelper
  # Format percentage to hide .0 decimals but show non-zero decimals
  # Examples: 50.0 -> "50", 50.1 -> "50.1", 50.25 -> "50.3"
  def format_percentage(value)
    rounded = value.round(1)
    if rounded == rounded.to_i
      rounded.to_i.to_s
    else
      rounded.to_s
    end
  end

  # Helper method to render template fields with sample data for email workflow previews
  def render_template_field(template_string, sample_data)
    return template_string unless template_string.present?
    
    result = template_string.dup
    sample_data.each do |category, data|
      data.each do |key, value|
        placeholder = "{{#{category}.#{key}}}"
        result = result.gsub(placeholder, value.to_s)
      end
    end
    result
  end
end
