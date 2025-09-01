import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="honky-pong"
export default class extends Controller {
  static targets = ["canvas", "score", "lives", "level", "bonus", "startButton", "pauseButton", "gameOver", "finalScore", "restartButton", "loadingScreen", "performanceIndicator"]
  
  connect() {
    console.log("🎮 Honky Pong Professional Controller Connected")
    this.initializeGame()
  }
  
  disconnect() {
    if (this.game) {
      this.game.destroy()
    }
  }
  
  async initializeGame() {
    try {
      // Show professional loading screen
      this.showLoadingScreen()
      
      // Dynamic import of the enhanced game module
      const { HonkyPongGame } = await import("honky_pong_enhanced")
      
      // Initialize the professional game engine
      this.game = new HonkyPongGame({
        canvas: this.canvasTarget,
        scoreElement: this.scoreTarget,
        livesElement: this.livesTarget,
        levelElement: this.levelTarget,
        bonusElement: this.bonusTarget,
        startButton: this.startButtonTarget,
        pauseButton: this.pauseButtonTarget,
        gameOverElement: this.gameOverTarget,
        finalScoreElement: this.finalScoreTarget,
        restartButton: this.restartButtonTarget,
        performanceIndicator: this.hasPerformanceIndicatorTarget ? this.performanceIndicatorTarget : null
      })
      
      // Hide loading screen after initialization
      setTimeout(() => {
        this.hideLoadingScreen()
      }, 1000)
      
    } catch (error) {
      console.error("Failed to initialize Honky Pong:", error)
      this.hideLoadingScreen()
      this.showError("Failed to load game. Please refresh the page.")
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
    // Create professional error message
    const errorDiv = document.createElement('div')
    errorDiv.className = 'game-error'
    errorDiv.innerHTML = `
      <div class="error-content">
        <h3>🚨 Game Error</h3>
        <p>${message}</p>
        <button class="btn btn-secondary error-reload-btn">Reload Game</button>
      </div>
    `
    
    // Add event listener for reload button (CSP compliant)
    const reloadBtn = errorDiv.querySelector('.error-reload-btn')
    reloadBtn.addEventListener('click', () => location.reload())
    
    this.element.appendChild(errorDiv)
  }
  
  // Professional keyboard event handling
  handleKeyDown(event) {
    if (this.game) {
      this.game.handleKeyDown(event)
    }
  }
  
  handleKeyUp(event) {
    if (this.game) {
      this.game.handleKeyUp(event)
    }
  }
  
  // Professional focus management
  focusGame() {
    if (this.canvasTarget) {
      this.canvasTarget.focus()
    }
  }
  
  // Professional performance monitoring
  updatePerformance(data) {
    if (this.hasPerformanceIndicatorTarget) {
      this.performanceIndicatorTarget.innerHTML = `
        <div class="fps-counter">FPS: ${data.fps}</div>
        <div class="memory-usage">Memory: ${data.memory}MB</div>
        <div class="particle-count">Particles: ${data.particles}</div>
      `
    }
  }
}