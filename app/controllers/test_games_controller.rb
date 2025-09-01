class TestGamesController < ApplicationController
  # Skip authentication for testing
  skip_before_action :authenticate_user!
  skip_before_action :ensure_email_verified!
  layout 'games'
  
  def honky_pong_test
    render 'games/honky_pong'
  end
end