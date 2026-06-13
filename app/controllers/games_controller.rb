class GamesController < ApplicationController
  before_action :authenticate_user!
  layout "games"

  def lace_invaders
    # Simple controller action to render the Lace Invaders game
  end

  def arcade
    # Arcade selection page
  end
end
