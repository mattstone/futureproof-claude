class ActivationBlockedError < StandardError
  def initialize(message = "Activation is blocked")
    super(message)
  end
end