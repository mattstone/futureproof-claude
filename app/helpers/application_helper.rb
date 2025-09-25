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

  # Helper method to format large currency amounts with abbreviations
  # Examples: $50,000,000,000 -> "$50.0B", $1,500,000 -> "$1.5M", $500,000 -> "$500K"
  def abbreviated_currency(amount)
    return "$0" if amount.nil? || amount == 0

    abs_amount = amount.abs

    if abs_amount >= 1_000_000_000
      # Billions
      formatted = (abs_amount / 1_000_000_000.0).round(1)
      suffix = "B"
    elsif abs_amount >= 1_000_000
      # Millions
      formatted = (abs_amount / 1_000_000.0).round(1)
      suffix = "M"
    elsif abs_amount >= 1_000
      # Thousands
      formatted = (abs_amount / 1_000.0).round(1)
      suffix = "K"
    else
      # Less than 1000, show full amount
      return ActionController::Base.helpers.number_to_currency(amount, precision: 0)
    end

    # Format the number (remove .0 if it's a whole number)
    display_number = formatted == formatted.to_i ? formatted.to_i : formatted
    prefix = amount < 0 ? "-$" : "$"

    "#{prefix}#{display_number}#{suffix}"
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
