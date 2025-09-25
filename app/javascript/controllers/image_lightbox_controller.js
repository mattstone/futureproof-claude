import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { images: Array, currentIndex: Number }

  connect() {
    // Create lightbox HTML if it doesn't exist
    this.createLightbox()
    // Set up keyboard event listener
    this.keydownHandler = this.handleKeydown.bind(this)
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener('keydown', this.keydownHandler)
  }

  createLightbox() {
    if (document.getElementById('image-lightbox')) return

    const lightboxHTML = `
      <div id="image-lightbox" class="image-lightbox hidden">
        <div class="lightbox-overlay"></div>
        <div class="lightbox-content">
          <button class="lightbox-close" aria-label="Close">×</button>
          <button class="lightbox-nav lightbox-prev" aria-label="Previous">‹</button>
          <button class="lightbox-nav lightbox-next" aria-label="Next">›</button>
          <img class="lightbox-image" alt="Property image">
          <div class="lightbox-counter"></div>
        </div>
      </div>
    `

    document.body.insertAdjacentHTML('beforeend', lightboxHTML)

    // Store references to the created elements
    this.lightboxElement = document.getElementById('image-lightbox')
    this.imageElement = this.lightboxElement.querySelector('.lightbox-image')
    this.counterElement = this.lightboxElement.querySelector('.lightbox-counter')

    // Add event listeners manually since they're not connected to Stimulus
    this.lightboxElement.querySelector('.lightbox-overlay').addEventListener('click', () => this.close())
    this.lightboxElement.querySelector('.lightbox-close').addEventListener('click', () => this.close())
    this.lightboxElement.querySelector('.lightbox-prev').addEventListener('click', () => this.previous())
    this.lightboxElement.querySelector('.lightbox-next').addEventListener('click', () => this.next())
  }

  show(event) {
    const clickedImage = event.currentTarget
    const imageUrl = clickedImage.src
    const imageAlt = clickedImage.alt

    // Get all images from the container
    const container = this.element.querySelector('.property-images-grid')
    const allImages = Array.from(container.querySelectorAll('.property-image'))

    this.imagesValue = allImages.map(img => ({
      src: img.src,
      alt: img.alt
    }))

    // Find current image index
    this.currentIndexValue = allImages.findIndex(img => img.src === imageUrl)

    this.displayCurrentImage()
    this.lightboxElement.classList.remove('hidden')
    document.body.style.overflow = 'hidden'

    // Add keyboard event listener
    document.addEventListener('keydown', this.keydownHandler)
  }

  close() {
    this.lightboxElement.classList.add('hidden')
    document.body.style.overflow = ''
    document.removeEventListener('keydown', this.keydownHandler)
  }

  previous() {
    if (this.imagesValue.length <= 1) return

    this.currentIndexValue = this.currentIndexValue > 0
      ? this.currentIndexValue - 1
      : this.imagesValue.length - 1

    this.displayCurrentImage()
  }

  next() {
    if (this.imagesValue.length <= 1) return

    this.currentIndexValue = this.currentIndexValue < this.imagesValue.length - 1
      ? this.currentIndexValue + 1
      : 0

    this.displayCurrentImage()
  }

  displayCurrentImage() {
    const currentImage = this.imagesValue[this.currentIndexValue]
    this.imageElement.src = currentImage.src
    this.imageElement.alt = currentImage.alt

    if (this.imagesValue.length > 1) {
      this.counterElement.textContent = `${this.currentIndexValue + 1} of ${this.imagesValue.length}`
    } else {
      this.counterElement.textContent = ''
    }
  }

  handleKeydown(event) {
    switch(event.key) {
      case 'Escape':
        this.close()
        break
      case 'ArrowLeft':
        event.preventDefault()
        this.previous()
        break
      case 'ArrowRight':
        event.preventDefault()
        this.next()
        break
    }
  }
}