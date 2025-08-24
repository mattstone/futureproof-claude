class GamesController < ApplicationController
  before_action :authenticate_user!
  
  def honky_pong
    # Simple controller action to render the Honky Pong game
  end
  
  def lace_invaders
    # Simple controller action to render the Lace Invaders game
  end
  
  def hackman
    # Simple controller action to render the Hackman game
  end
  
  def defendher
    # Simple controller action to render the DefendHer game
  end
  
  def arcade
    # Arcade selection page
  end
end