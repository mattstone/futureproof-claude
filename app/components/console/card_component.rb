class Console::CardComponent < Console::BaseComponent
  renders_one :header_action

  def initialize(title: nil)
    @title = title
  end
end
