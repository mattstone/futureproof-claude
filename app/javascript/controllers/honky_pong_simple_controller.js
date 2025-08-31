import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="honky-pong-simple"
export default class extends Controller {
  static targets = ["container", "score", "lives", "startButton", "gameOver"]
  
  connect() {
    console.log("🎮 Honky Pong Simple Controller Connected")
    this.initializeGame()
  }
  
  disconnect() {
    if (this.game) {
      this.game.destroy()
    }
  }
  
  async initializeGame() {
    try {
      // Dynamic import of the fixed simple game module
      const { HonkyPongSimpleFixed } = await import("honky_pong_simple_fixed")
      
      // Initialize the game with the container
      this.game = new HonkyPongSimpleFixed({
        container: this.containerTarget,
        scoreElement: this.hasScoreTarget ? this.scoreTarget : null,
        livesElement: this.hasLivesTarget ? this.livesTarget : null,
        startButton: this.hasStartButtonTarget ? this.startButtonTarget : null,
        gameOverElement: this.hasGameOverTarget ? this.gameOverTarget : null
      })
      
    } catch (error) {
      console.error("Failed to initialize Honky Pong Simple:", error)
      this.showError("Failed to load game. Please refresh the page.")
    }
  }
  
  showError(message) {
    const errorDiv = document.createElement('div')
    errorDiv.className = 'game-error'
    errorDiv.innerHTML = `
      <div class="error-content">
        <h3>🚨 Game Error</h3>
        <p>${message}</p>
        <button class="btn btn-secondary error-reload-btn">Reload Game</button>
      </div>
    `
    
    const reloadBtn = errorDiv.querySelector('.error-reload-btn')
    reloadBtn.addEventListener('click', () => location.reload())
    
    this.element.appendChild(errorDiv)
  }
}