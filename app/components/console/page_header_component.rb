class Console::PageHeaderComponent < Console::BaseComponent
  renders_many :actions

  def initialize(title:, subtitle: nil)
    @title = title
    @subtitle = subtitle
  end
end
