import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["countdown", "timeDisplay", "resendLink", "resendContainer"]
  static values = { countdown: Number }

  connect() {
    this.startCountdown()
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  startCountdown() {
    this.timeRemaining = this.countdownValue
    this.updateDisplay()
    
    this.timer = setInterval(() => {
      this.timeRemaining--
      
      if (this.timeRemaining <= 0) {
        this.countdownComplete()
      } else {
        this.updateDisplay()
      }
    }, 1000)
  }

  updateDisplay() {
    const minutes = Math.floor(this.timeRemaining / 60)
    const seconds = this.timeRemaining % 60
    const formattedTime = `${minutes}:${seconds.toString().padStart(2, '0')}`
    
    this.timeDisplayTarget.textContent = formattedTime
  }

  countdownComplete() {
    clearInterval(this.timer)
    
    // Hide the countdown and show the resend link
    this.countdownTarget.style.display = 'none'
    this.resendLinkTarget.style.display = 'inline-block'
  }

  // Reset timer when resend is clicked
  resendClicked() {
    // Hide the resend link and show countdown again
    this.resendLinkTarget.style.display = 'none'
    this.countdownTarget.style.display = 'inline'
    
    // Restart the countdown
    this.startCountdown()
  }
}