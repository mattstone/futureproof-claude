# Parent of every Console component. Shared conveniences live here so
# individual components stay declarative.
class Console::BaseComponent < ViewComponent::Base
  private

  # Renders a stored ERB/Ruby block in the caller's view context.
  # Used by table columns, description-list items, tabs — anywhere a slot
  # needs to be re-evaluated with per-row arguments.
  def capture_block(block, *args)
    return if block.nil?

    helpers.capture(*args, &block)
  end
end
