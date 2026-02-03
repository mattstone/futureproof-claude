import { Controller } from "@hotwired/stimulus"

// Demo Gallery Controller
// Handles image carousel, lightbox, and map view for property details
export default class extends Controller {
  static targets = [
    "mainImage",
    "carouselTrack",
    "thumbnail",
    "photoToggle",
    "mapToggle",
    "photoView",
    "mapView",
    "lightbox",
    "lightboxImage",
    "lightboxCounter",
    "prevBtn",
    "nextBtn"
  ]

  static values = {
    images: Array,
    currentIndex: { type: Number, default: 0 },
    latitude: { type: Number, default: -33.6372 },
    longitude: { type: Number, default: 151.2953 }
  }

  connect() {
    this.mapLoaded = false
  }

  // Toggle between Photos and Map view
  showPhotos() {
    if (this.hasPhotoToggleTarget) {
      this.photoToggleTarget.classList.add("active")
    }
    if (this.hasMapToggleTarget) {
      this.mapToggleTarget.classList.remove("active")
    }
    if (this.hasPhotoViewTarget) {
      this.photoViewTarget.style.display = "flex"
    }
    if (this.hasMapViewTarget) {
      this.mapViewTarget.style.display = "none"
    }
  }

  showMap() {
    if (this.hasPhotoToggleTarget) {
      this.photoToggleTarget.classList.remove("active")
    }
    if (this.hasMapToggleTarget) {
      this.mapToggleTarget.classList.add("active")
    }
    if (this.hasPhotoViewTarget) {
      this.photoViewTarget.style.display = "none"
    }
    if (this.hasMapViewTarget) {
      this.mapViewTarget.style.display = "block"
    }

    // Load map if not already loaded
    if (!this.mapLoaded) {
      this.loadMap()
    }
  }

  loadMap() {
    const mapContainer = this.mapViewTarget
    const lat = this.latitudeValue
    const lng = this.longitudeValue

    // Create OpenStreetMap iframe embed
    const iframe = document.createElement("iframe")
    iframe.width = "100%"
    iframe.height = "100%"
    iframe.frameBorder = "0"
    iframe.scrolling = "no"
    iframe.src = `https://www.openstreetmap.org/export/embed.html?bbox=${lng - 0.01}%2C${lat - 0.01}%2C${lng + 0.01}%2C${lat + 0.01}&layer=mapnik&marker=${lat}%2C${lng}`
    iframe.style.border = "0"
    iframe.style.borderRadius = "8px"

    mapContainer.innerHTML = ""
    mapContainer.appendChild(iframe)
    this.mapLoaded = true
  }

  // Carousel navigation
  selectImage(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.goToImage(index)
  }

  goToImage(index) {
    const images = this.imagesValue
    if (index < 0) index = images.length - 1
    if (index >= images.length) index = 0

    this.currentIndexValue = index

    // Update main image
    if (this.hasMainImageTarget) {
      this.mainImageTarget.src = images[index]
    }

    // Update thumbnail selection
    this.thumbnailTargets.forEach((thumb, i) => {
      thumb.classList.toggle("active", i === index)
    })

    // Scroll thumbnail into view within the track
    if (this.thumbnailTargets[index] && this.hasCarouselTrackTarget) {
      const track = this.carouselTrackTarget
      const thumb = this.thumbnailTargets[index]
      const thumbLeft = thumb.offsetLeft
      const thumbWidth = thumb.offsetWidth
      const trackWidth = track.offsetWidth
      const trackScrollLeft = track.scrollLeft

      // Calculate the center position for the thumbnail
      const targetScroll = thumbLeft - (trackWidth / 2) + (thumbWidth / 2)

      track.scrollTo({
        left: Math.max(0, targetScroll),
        behavior: "smooth"
      })
    }
  }

  prevImage() {
    this.goToImage(this.currentIndexValue - 1)
  }

  nextImage() {
    this.goToImage(this.currentIndexValue + 1)
  }

  // Lightbox functionality
  openLightbox(event) {
    const index = event.currentTarget.dataset.index
      ? parseInt(event.currentTarget.dataset.index)
      : this.currentIndexValue

    this.currentIndexValue = index
    this.updateLightboxImage()

    if (this.hasLightboxTarget) {
      this.lightboxTarget.style.display = "flex"
      document.body.style.overflow = "hidden"
    }

    // Add keyboard listener
    this.keyboardHandler = this.handleKeyboard.bind(this)
    document.addEventListener("keydown", this.keyboardHandler)
  }

  closeLightbox() {
    if (this.hasLightboxTarget) {
      this.lightboxTarget.style.display = "none"
      document.body.style.overflow = ""
    }

    // Remove keyboard listener
    if (this.keyboardHandler) {
      document.removeEventListener("keydown", this.keyboardHandler)
    }
  }

  lightboxPrev() {
    this.currentIndexValue = this.currentIndexValue - 1
    if (this.currentIndexValue < 0) {
      this.currentIndexValue = this.imagesValue.length - 1
    }
    this.updateLightboxImage()
  }

  lightboxNext() {
    this.currentIndexValue = this.currentIndexValue + 1
    if (this.currentIndexValue >= this.imagesValue.length) {
      this.currentIndexValue = 0
    }
    this.updateLightboxImage()
  }

  updateLightboxImage() {
    const images = this.imagesValue
    const index = this.currentIndexValue

    if (this.hasLightboxImageTarget) {
      this.lightboxImageTarget.src = images[index]
    }

    if (this.hasLightboxCounterTarget) {
      this.lightboxCounterTarget.textContent = `${index + 1} / ${images.length}`
    }

    // Also update carousel selection
    this.goToImage(index)
  }

  handleKeyboard(event) {
    switch (event.key) {
      case "Escape":
        this.closeLightbox()
        break
      case "ArrowLeft":
        this.lightboxPrev()
        break
      case "ArrowRight":
        this.lightboxNext()
        break
    }
  }

  // Close lightbox when clicking outside the image
  lightboxBackdropClick(event) {
    if (event.target === this.lightboxTarget) {
      this.closeLightbox()
    }
  }
}
