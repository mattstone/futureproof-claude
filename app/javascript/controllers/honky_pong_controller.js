import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "score", "lives", "level"]

  connect() {
    console.log("🎮 Honky Pong controller connected")
    this.initGame()
  }

  disconnect() {
    if (this.game) this.game.destroy()
  }

  async initGame() {
    try {
      const { HonkyPongGame } = await import("honky_pong_enhanced")
      const canvas = this.containerTarget.querySelector('canvas')

      this.game = new HonkyPongGame({
        canvas: canvas,
        container: this.containerTarget,
        scoreElement: this.hasScoreTarget ? this.scoreTarget : null,
        livesElement: this.hasLivesTarget ? this.livesTarget : null,
        levelElement: this.hasLevelTarget ? this.levelTarget : null,
        onStateChange: (state) => this.onStateChange(state)
      })
    } catch (error) {
      console.error("Failed to init Honky Pong:", error)
    }
  }

  startGame() {
    if (this.game) this.game.start()
  }

  togglePause() {
    if (this.game) this.game.togglePause()
  }

  onStateChange(state) {
    // Could update button text etc
  }
}
