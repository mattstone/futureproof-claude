import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="honky-pong-minimal"
export default class extends Controller {
  static targets = ["container"]
  
  connect() {
    console.log("🎮 Honky Pong Minimal Controller Connected")
    this.initializeGame()
  }
  
  disconnect() {
    if (this.game) {
      this.game.destroy()
    }
  }
  
  startGame() {
    if (this.game) {
      this.game.start()
    }
  }
  
  async initializeGame() {
    try {
      // Dynamic import of the minimal game module
      const { HonkyPongMinimal } = await import("honky_pong_minimal")
      
      // Initialize the game
      this.game = new HonkyPongMinimal({
        container: this.containerTarget
      })
      
    } catch (error) {
      console.error("Failed to initialize Honky Pong Minimal:", error)
    }
  }
}