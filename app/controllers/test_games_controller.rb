class TestGamesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_email_verified!
  layout "games"
end
