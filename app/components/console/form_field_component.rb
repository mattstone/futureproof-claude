# Wraps one form input with its label, hint, and inline errors.
# The input itself is the content block, so any field type works:
#
#   <%= render Console::FormFieldComponent.new(form: f, attribute: :email) do %>
#     <%= f.email_field :email, class: "console-input" %>
#   <% end %>
class Console::FormFieldComponent < Console::BaseComponent
  def initialize(form:, attribute:, label: nil, hint: nil, required: false)
    @form = form
    @attribute = attribute
    @label = label
    @hint = hint
    @required = required
  end

  attr_reader :form, :attribute, :label, :hint, :required

  def errors
    return [] unless form.object.respond_to?(:errors)

    form.object.errors[attribute]
  end
end
