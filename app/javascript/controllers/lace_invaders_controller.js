import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="lace-invaders"
export default class extends Controller {
  static targets = ["canvas", "score", "lives", "level", "startButton", "gameOver", "finalScore", "restartButton", "loadingScreen"]
  
  connect() {
    console.log("🎮 Lace Invaders Controller Connected")
    this.initializeGame()
  }
  
  disconnect() {
    if (this.game) {
      this.game.destroy()
    }
  }
  
  async initializeGame() {
    try {
      console.log("🎮 Starting Lace Invaders initialization...")
      
      // Show loading screen
      this.showLoadingScreen()
      
      // Wait a brief moment to ensure DOM is ready
      await new Promise(resolve => setTimeout(resolve, 100))
      
      // Verify required elements exist
      if (!this.hasCanvasTarget) {
        throw new Error("Canvas element not found")
      }
      
      console.log("🎮 Importing game module...")
      // Dynamic import of the game module
      const { LaceInvadersGame } = await import("lace_invaders")
      
      console.log("🎮 Creating game instance...")
      // Initialize the Lace Invaders game
      this.game = new LaceInvadersGame({
        canvas: this.canvasTarget,
        scoreElement: this.hasScoreTarget ? this.scoreTarget : null,
        livesElement: this.hasLivesTarget ? this.livesTarget : null,
        levelElement: this.hasLevelTarget ? this.levelTarget : null,
        startButton: this.hasStartButtonTarget ? this.startButtonTarget : null,
        gameOverElement: this.hasGameOverTarget ? this.gameOverTarget : null,
        finalScoreElement: this.hasFinalScoreTarget ? this.finalScoreTarget : null,
        restartButton: this.hasRestartButtonTarget ? this.restartButtonTarget : null
      })
      
      console.log("🎮 Game initialized successfully!")
      
      // Hide loading screen after initialization
      setTimeout(() => {
        this.hideLoadingScreen()
      }, 1000)
      
    } catch (error) {
      console.error("🚨 Failed to initialize Lace Invaders:", error)
      console.error("Error stack:", error.stack)
      this.hideLoadingScreen()
      this.showError(`Failed to load game: ${error.message}. Please refresh the page.`)
    }
  }
  
  showLoadingScreen() {
    if (this.hasLoadingScreenTarget) {
      this.loadingScreenTarget.classList.remove('loading-hidden')
      this.loadingScreenTarget.classList.add('loading-visible')
    }
  }
  
  hideLoadingScreen() {
    if (this.hasLoadingScreenTarget) {
      this.loadingScreenTarget.classList.add('loading-fade-out')
      setTimeout(() => {
        this.loadingScreenTarget.classList.add('loading-hidden')
        this.loadingScreenTarget.classList.remove('loading-visible', 'loading-fade-out')
      }, 500)
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
  
  focusGame() {
    if (this.canvasTarget) {
      this.canvasTarget.focus()
    }
  }
}