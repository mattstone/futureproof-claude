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
end
