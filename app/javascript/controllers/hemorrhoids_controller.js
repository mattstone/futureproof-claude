import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="hemorrhoids"
export default class extends Controller {
  static targets = ["canvas", "score", "lives", "level", "asteroids", "startButton", "gameOver", "loadingScreen"]
  
  connect() {
    console.log("🚀 Hemorrhoids Controller Connected")
    this.initializeGame()
  }
  
  disconnect() {
    if (this.game) {
      this.game.destroy()
    }
    if (this.animationId) {
      cancelAnimationFrame(this.animationId)
    }
  }
  
  focusGame() {
    if (this.hasCanvasTarget) {
      this.canvasTarget.focus()
    }
  }
  
  restart() {
    // Reset game state
    this.gameState.score = 0
    this.gameState.lives = 3
    this.gameState.level = 1
    this.gameState.gameStarted = false
    this.gameState.gameOver = false
    this.gameState.bullets = []
    this.gameState.asteroids = []
    this.gameState.ufos = []
    this.gameState.ufoBullets = []
    this.gameState.particles = []
    
    // Reset ship position
    this.gameState.ship.x = this.canvasTarget.width / 2
    this.gameState.ship.y = this.canvasTarget.height / 2
    this.gameState.ship.angle = 0
    this.gameState.ship.velocity.x = 0
    this.gameState.ship.velocity.y = 0
    this.gameState.ship.invulnerable = 0
    
    // Hide game over screen
    if (this.hasGameOverTarget) {
      this.gameOverTarget.classList.add('game-over-hidden')
    }
    
    const gameOverScreen = document.getElementById('gameOverScreen')
    if (gameOverScreen) {
      gameOverScreen.style.display = 'none'
    }
    
    // Show start screen
    const startScreen = document.getElementById('startScreen')
    if (startScreen) {
      startScreen.style.display = 'flex'
    }
    
    // Spawn initial asteroids
    this.spawnAsteroids(4)
    
    // Update UI
    this.updateUI()
  }
  
  async initializeGame() {
    try {
      console.log("🚀 Starting Hemorrhoids initialization...")
      
      // Show loading screen
      this.showLoadingScreen()
      
      // Wait a brief moment to ensure DOM is ready
      await new Promise(resolve => setTimeout(resolve, 100))
      
      // Verify required elements exist
      if (!this.hasCanvasTarget) {
        throw new Error("Canvas element not found")
      }
      
      console.log("🚀 Creating game instance...")
      
      // Initialize the game directly in this controller
      this.setupGame()
      
      console.log("🚀 Game initialized successfully!")
      
      // Hide loading screen
      this.hideLoadingScreen()
      
    } catch (error) {
      console.error("❌ Failed to initialize Hemorrhoids:", error)
      this.showError(error)
    }
  }
  
  setupGame() {
    const canvas = this.canvasTarget
    const ctx = canvas.getContext('2d')
    
    // Game state
    this.gameState = {
      ship: null,
      bullets: [],
      asteroids: [],
      ufos: [],
      ufoBullets: [],
      particles: [],
      score: 0,
      lives: 3,
      level: 1,
      gameStarted: false,
      gameOver: false,
      keys: {},
      lastUFOSpawn: 0
    }
    
    // Game constants
    this.CONSTANTS = {
      SHIP_SIZE: 8,
      BULLET_SPEED: 5,
      ASTEROID_SPEEDS: [0.5, 1, 2],
      UFO_SPEED: 1,
      UFO_BULLET_SPEED: 3,
      HYPERSPACE_COOLDOWN: 3000
    }
    
    // Initialize ship
    this.gameState.ship = {
      x: canvas.width / 2,
      y: canvas.height / 2,
      angle: 0,
      velocity: { x: 0, y: 0 },
      thrust: false,
      size: this.CONSTANTS.SHIP_SIZE,
      invulnerable: 0,
      hyperspaceReady: true,
      lastHyperspace: 0
    }
    
    // Event listeners
    this.setupEventListeners()
    
    // Start game loop
    this.gameLoop()
    
    // Initial asteroids
    this.spawnAsteroids(4)
    
    // Update UI
    this.updateUI()
  }
  
  setupEventListeners() {
    const canvas = this.canvasTarget
    
    // Keyboard events
    document.addEventListener('keydown', (e) => this.handleKeyDown(e))
    document.addEventListener('keyup', (e) => this.handleKeyUp(e))
    
    // Focus canvas for keyboard input
    canvas.setAttribute('tabindex', '0')
    canvas.focus()
    
    // Start button
    if (this.hasStartButtonTarget) {
      this.startButtonTarget.addEventListener('click', () => this.startGame())
    }
  }
  
  handleKeyDown(e) {
    this.gameState.keys[e.code] = true
    
    if (e.code === 'Space') {
      e.preventDefault()
      if (!this.gameState.gameStarted) {
        this.startGame()
      } else {
        this.fireBullet()
      }
    }
    
    if (e.code === 'KeyH') {
      this.hyperspace()
    }
  }
  
  handleKeyUp(e) {
    this.gameState.keys[e.code] = false
  }
  
  startGame() {
    this.gameState.gameStarted = true
    this.gameState.gameOver = false
    document.getElementById('startScreen')?.style.setProperty('display', 'none')
    this.canvasTarget.focus()
  }
  
  gameLoop() {
    this.update()
    this.render()
    this.animationId = requestAnimationFrame(() => this.gameLoop())
  }
  
  update() {
    if (!this.gameState.gameStarted || this.gameState.gameOver) return
    
    this.updateShip()
    this.updateBullets()
    this.updateAsteroids()
    this.updateUFOs()
    this.updateParticles()
    this.checkCollisions()
    this.spawnUFOIfNeeded()
    
    // Check if level complete
    if (this.gameState.asteroids.length === 0 && this.gameState.ufos.length === 0) {
      this.nextLevel()
    }
  }
  
  updateShip() {
    const ship = this.gameState.ship
    const keys = this.gameState.keys
    
    if (ship.invulnerable > 0) ship.invulnerable--
    
    // Rotation
    if (keys['ArrowLeft']) ship.angle -= 0.15
    if (keys['ArrowRight']) ship.angle += 0.15
    
    // Thrust
    ship.thrust = keys['ArrowUp']
    if (ship.thrust) {
      ship.velocity.x += Math.cos(ship.angle) * 0.3
      ship.velocity.y += Math.sin(ship.angle) * 0.3
      
      // Add thrust particles
      for (let i = 0; i < 3; i++) {
        this.addParticle(
          ship.x - Math.cos(ship.angle) * 10,
          ship.y - Math.sin(ship.angle) * 10,
          Math.random() * 2 - 1,
          Math.random() * 2 - 1,
          15,
          '#ff6600'
        )
      }
    }
    
    // Apply friction
    ship.velocity.x *= 0.98
    ship.velocity.y *= 0.98
    
    // Update position
    ship.x += ship.velocity.x
    ship.y += ship.velocity.y
    
    // Screen wrapping
    ship.x = (ship.x + this.canvasTarget.width) % this.canvasTarget.width
    ship.y = (ship.y + this.canvasTarget.height) % this.canvasTarget.height
  }
  
  updateBullets() {
    this.gameState.bullets = this.gameState.bullets.filter(bullet => {
      bullet.x += bullet.velocity.x
      bullet.y += bullet.velocity.y
      bullet.life--
      
      // Screen wrapping
      bullet.x = (bullet.x + this.canvasTarget.width) % this.canvasTarget.width
      bullet.y = (bullet.y + this.canvasTarget.height) % this.canvasTarget.height
      
      return bullet.life > 0
    })
    
    // UFO bullets
    this.gameState.ufoBullets = this.gameState.ufoBullets.filter(bullet => {
      bullet.x += bullet.velocity.x
      bullet.y += bullet.velocity.y
      bullet.life--
      
      // Screen wrapping
      bullet.x = (bullet.x + this.canvasTarget.width) % this.canvasTarget.width
      bullet.y = (bullet.y + this.canvasTarget.height) % this.canvasTarget.height
      
      return bullet.life > 0
    })
  }
  
  updateAsteroids() {
    this.gameState.asteroids.forEach(asteroid => {
      asteroid.x += asteroid.velocity.x
      asteroid.y += asteroid.velocity.y
      asteroid.rotation += asteroid.rotationSpeed
      
      // Screen wrapping
      asteroid.x = (asteroid.x + this.canvasTarget.width) % this.canvasTarget.width
      asteroid.y = (asteroid.y + this.canvasTarget.height) % this.canvasTarget.height
    })
  }
  
  updateUFOs() {
    this.gameState.ufos.forEach(ufo => {
      ufo.x += ufo.velocity.x
      ufo.y += ufo.velocity.y
      
      // Change direction occasionally
      if (Math.random() < 0.02) {
        ufo.velocity.x = (Math.random() - 0.5) * this.CONSTANTS.UFO_SPEED * 2
        ufo.velocity.y = (Math.random() - 0.5) * this.CONSTANTS.UFO_SPEED * 2
      }
      
      // Shoot at player
      if (Math.random() < 0.01) {
        this.ufoShoot(ufo)
      }
      
      // Screen wrapping
      ufo.x = (ufo.x + this.canvasTarget.width) % this.canvasTarget.width
      ufo.y = (ufo.y + this.canvasTarget.height) % this.canvasTarget.height
    })
  }
  
  updateParticles() {
    this.gameState.particles = this.gameState.particles.filter(particle => {
      particle.x += particle.velocity.x
      particle.y += particle.velocity.y
      particle.life--
      particle.alpha = particle.life / particle.maxLife
      
      return particle.life > 0
    })
  }
  
  fireBullet() {
    const ship = this.gameState.ship
    const bullet = {
      x: ship.x + Math.cos(ship.angle) * ship.size,
      y: ship.y + Math.sin(ship.angle) * ship.size,
      velocity: {
        x: Math.cos(ship.angle) * this.CONSTANTS.BULLET_SPEED + ship.velocity.x,
        y: Math.sin(ship.angle) * this.CONSTANTS.BULLET_SPEED + ship.velocity.y
      },
      life: 60,
      size: 2
    }
    
    this.gameState.bullets.push(bullet)
    this.playSound('shoot')
  }
  
  hyperspace() {
    const ship = this.gameState.ship
    const now = Date.now()
    
    if (ship.hyperspaceReady && now - ship.lastHyperspace > this.CONSTANTS.HYPERSPACE_COOLDOWN) {
      // Random teleportation
      ship.x = Math.random() * this.canvasTarget.width
      ship.y = Math.random() * this.canvasTarget.height
      ship.velocity.x = 0
      ship.velocity.y = 0
      ship.invulnerable = 60
      ship.lastHyperspace = now
      
      // Hyperspace particles
      for (let i = 0; i < 20; i++) {
        this.addParticle(
          ship.x,
          ship.y,
          (Math.random() - 0.5) * 8,
          (Math.random() - 0.5) * 8,
          30,
          '#00ffff'
        )
      }
      
      this.playSound('hyperspace')
    }
  }
  
  spawnAsteroids(count) {
    for (let i = 0; i < count; i++) {
      this.createAsteroid(0) // Size 0 = large
    }
  }
  
  createAsteroid(size, x = null, y = null) {
    const canvas = this.canvasTarget
    const asteroid = {
      x: x !== null ? x : Math.random() * canvas.width,
      y: y !== null ? y : Math.random() * canvas.height,
      velocity: {
        x: (Math.random() - 0.5) * this.CONSTANTS.ASTEROID_SPEEDS[size],
        y: (Math.random() - 0.5) * this.CONSTANTS.ASTEROID_SPEEDS[size]
      },
      size: size,
      radius: [30, 20, 10][size],
      rotation: 0,
      rotationSpeed: (Math.random() - 0.5) * 0.1,
      points: this.generateAsteroidShape()
    }
    
    this.gameState.asteroids.push(asteroid)
  }
  
  generateAsteroidShape() {
    const points = []
    const numPoints = 8 + Math.floor(Math.random() * 4)
    
    for (let i = 0; i < numPoints; i++) {
      const angle = (i / numPoints) * Math.PI * 2
      const radius = 0.8 + Math.random() * 0.4
      points.push({ angle, radius })
    }
    
    return points
  }
  
  checkCollisions() {
    // Ship vs Asteroids
    if (this.gameState.ship.invulnerable <= 0) {
      this.gameState.asteroids.forEach((asteroid, asteroidIndex) => {
        if (this.checkCircleCollision(this.gameState.ship, asteroid)) {
          this.shipDestroyed()
          this.asteroidDestroyed(asteroidIndex)
        }
      })
      
      // Ship vs UFO bullets
      this.gameState.ufoBullets.forEach((bullet, bulletIndex) => {
        if (this.checkCircleCollision(this.gameState.ship, bullet)) {
          this.shipDestroyed()
          this.gameState.ufoBullets.splice(bulletIndex, 1)
        }
      })
    }
    
    // Bullets vs Asteroids
    this.gameState.bullets.forEach((bullet, bulletIndex) => {
      this.gameState.asteroids.forEach((asteroid, asteroidIndex) => {
        if (this.checkCircleCollision(bullet, asteroid)) {
          this.gameState.bullets.splice(bulletIndex, 1)
          this.asteroidDestroyed(asteroidIndex)
        }
      })
      
      // Bullets vs UFOs
      this.gameState.ufos.forEach((ufo, ufoIndex) => {
        if (this.checkCircleCollision(bullet, ufo)) {
          this.gameState.bullets.splice(bulletIndex, 1)
          this.ufoDestroyed(ufoIndex)
        }
      })
    })
  }
  
  checkCircleCollision(obj1, obj2) {
    const dx = obj1.x - obj2.x
    const dy = obj1.y - obj2.y
    const distance = Math.sqrt(dx * dx + dy * dy)
    return distance < (obj1.radius || obj1.size) + (obj2.radius || obj2.size)
  }
  
  asteroidDestroyed(index) {
    const asteroid = this.gameState.asteroids[index]
    
    // Add score
    this.gameState.score += [20, 50, 100][asteroid.size]
    
    // Create explosion particles
    for (let i = 0; i < 10; i++) {
      this.addParticle(
        asteroid.x,
        asteroid.y,
        (Math.random() - 0.5) * 6,
        (Math.random() - 0.5) * 6,
        30,
        '#ffffff'
      )
    }
    
    // Split asteroid if not smallest
    if (asteroid.size < 2) {
      for (let i = 0; i < 2; i++) {
        this.createAsteroid(asteroid.size + 1, asteroid.x, asteroid.y)
      }
    }
    
    this.gameState.asteroids.splice(index, 1)
    this.playSound('explosion')
    this.updateUI()
  }
  
  ufoDestroyed(index) {
    const ufo = this.gameState.ufos[index]
    
    // Add score
    this.gameState.score += 500
    
    // Create explosion particles
    for (let i = 0; i < 15; i++) {
      this.addParticle(
        ufo.x,
        ufo.y,
        (Math.random() - 0.5) * 8,
        (Math.random() - 0.5) * 8,
        40,
        '#ffff00'
      )
    }
    
    this.gameState.ufos.splice(index, 1)
    this.playSound('explosion')
    this.updateUI()
  }
  
  shipDestroyed() {
    const ship = this.gameState.ship
    
    // Create explosion particles
    for (let i = 0; i < 20; i++) {
      this.addParticle(
        ship.x,
        ship.y,
        (Math.random() - 0.5) * 10,
        (Math.random() - 0.5) * 10,
        50,
        '#ff0000'
      )
    }
    
    this.gameState.lives--
    this.updateUI()
    
    if (this.gameState.lives <= 0) {
      this.endGame()
    } else {
      // Respawn ship
      ship.x = this.canvasTarget.width / 2
      ship.y = this.canvasTarget.height / 2
      ship.velocity.x = 0
      ship.velocity.y = 0
      ship.angle = 0
      ship.invulnerable = 120
    }
    
    this.playSound('explosion')
  }
  
  spawnUFOIfNeeded() {
    const now = Date.now()
    if (this.gameState.ufos.length === 0 && now - this.gameState.lastUFOSpawn > 30000) {
      this.spawnUFO()
      this.gameState.lastUFOSpawn = now
    }
  }
  
  spawnUFO() {
    const canvas = this.canvasTarget
    const ufo = {
      x: Math.random() < 0.5 ? 0 : canvas.width,
      y: Math.random() * canvas.height,
      velocity: {
        x: (Math.random() - 0.5) * this.CONSTANTS.UFO_SPEED * 2,
        y: (Math.random() - 0.5) * this.CONSTANTS.UFO_SPEED * 2
      },
      size: 15,
      radius: 15
    }
    
    this.gameState.ufos.push(ufo)
  }
  
  ufoShoot(ufo) {
    const ship = this.gameState.ship
    const angle = Math.atan2(ship.y - ufo.y, ship.x - ufo.x)
    
    const bullet = {
      x: ufo.x,
      y: ufo.y,
      velocity: {
        x: Math.cos(angle) * this.CONSTANTS.UFO_BULLET_SPEED,
        y: Math.sin(angle) * this.CONSTANTS.UFO_BULLET_SPEED
      },
      life: 120,
      size: 3,
      radius: 3
    }
    
    this.gameState.ufoBullets.push(bullet)
    this.playSound('ufoShoot')
  }
  
  nextLevel() {
    this.gameState.level++
    this.spawnAsteroids(3 + this.gameState.level)
    this.updateUI()
  }
  
  endGame() {
    this.gameState.gameOver = true
    document.getElementById('gameOverScreen').style.display = 'block'
    document.getElementById('finalScore').textContent = this.gameState.score
    document.getElementById('finalLevel').textContent = this.gameState.level
    
    if (this.hasGameOverTarget) {
      this.gameOverTarget.classList.remove('game-over-hidden')
      document.getElementById('finalScoreDisplay').textContent = this.gameState.score
      document.getElementById('finalLevelDisplay').textContent = this.gameState.level
    }
  }
  
  addParticle(x, y, vx, vy, life, color) {
    this.gameState.particles.push({
      x, y,
      velocity: { x: vx, y: vy },
      life,
      maxLife: life,
      color,
      alpha: 1
    })
  }
  
  render() {
    const canvas = this.canvasTarget
    const ctx = canvas.getContext('2d')
    
    // Clear canvas
    ctx.fillStyle = '#000011'
    ctx.fillRect(0, 0, canvas.width, canvas.height)
    
    // Draw stars
    this.drawStars(ctx)
    
    if (this.gameState.gameStarted && !this.gameState.gameOver) {
      this.drawShip(ctx)
      this.drawBullets(ctx)
      this.drawAsteroids(ctx)
      this.drawUFOs(ctx)
    }
    
    this.drawParticles(ctx)
    
    if (!this.gameState.gameStarted) {
      this.drawStartScreen(ctx)
    }
  }
  
  drawStars(ctx) {
    ctx.fillStyle = '#ffffff'
    for (let i = 0; i < 100; i++) {
      const x = (i * 123) % this.canvasTarget.width
      const y = (i * 456) % this.canvasTarget.height
      ctx.fillRect(x, y, 1, 1)
    }
  }
  
  drawShip(ctx) {
    const ship = this.gameState.ship
    
    if (ship.invulnerable > 0 && Math.floor(ship.invulnerable / 5) % 2) {
      return // Flashing when invulnerable
    }
    
    ctx.save()
    ctx.translate(ship.x, ship.y)
    ctx.rotate(ship.angle)
    
    ctx.strokeStyle = '#ffffff'
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.moveTo(ship.size, 0)
    ctx.lineTo(-ship.size, -ship.size / 2)
    ctx.lineTo(-ship.size / 2, 0)
    ctx.lineTo(-ship.size, ship.size / 2)
    ctx.closePath()
    ctx.stroke()
    
    // Thrust flame
    if (ship.thrust) {
      ctx.strokeStyle = '#ff6600'
      ctx.beginPath()
      ctx.moveTo(-ship.size, -3)
      ctx.lineTo(-ship.size * 1.5, 0)
      ctx.lineTo(-ship.size, 3)
      ctx.stroke()
    }
    
    ctx.restore()
  }
  
  drawBullets(ctx) {
    ctx.fillStyle = '#ffffff'
    this.gameState.bullets.forEach(bullet => {
      ctx.fillRect(bullet.x - bullet.size/2, bullet.y - bullet.size/2, bullet.size, bullet.size)
    })
    
    ctx.fillStyle = '#ff0000'
    this.gameState.ufoBullets.forEach(bullet => {
      ctx.fillRect(bullet.x - bullet.size/2, bullet.y - bullet.size/2, bullet.size, bullet.size)
    })
  }
  
  drawAsteroids(ctx) {
    ctx.strokeStyle = '#cccccc'
    ctx.lineWidth = 2
    
    this.gameState.asteroids.forEach(asteroid => {
      ctx.save()
      ctx.translate(asteroid.x, asteroid.y)
      ctx.rotate(asteroid.rotation)
      
      ctx.beginPath()
      asteroid.points.forEach((point, i) => {
        const x = Math.cos(point.angle) * point.radius * asteroid.radius
        const y = Math.sin(point.angle) * point.radius * asteroid.radius
        
        if (i === 0) {
          ctx.moveTo(x, y)
        } else {
          ctx.lineTo(x, y)
        }
      })
      ctx.closePath()
      ctx.stroke()
      
      ctx.restore()
    })
  }
  
  drawUFOs(ctx) {
    ctx.strokeStyle = '#00ff00'
    ctx.lineWidth = 2
    
    this.gameState.ufos.forEach(ufo => {
      ctx.save()
      ctx.translate(ufo.x, ufo.y)
      
      // UFO body
      ctx.beginPath()
      ctx.ellipse(0, 0, ufo.size, ufo.size / 2, 0, 0, Math.PI * 2)
      ctx.stroke()
      
      // UFO dome
      ctx.beginPath()
      ctx.ellipse(0, -ufo.size / 4, ufo.size / 2, ufo.size / 4, 0, 0, Math.PI * 2)
      ctx.stroke()
      
      ctx.restore()
    })
  }
  
  drawParticles(ctx) {
    this.gameState.particles.forEach(particle => {
      ctx.save()
      ctx.globalAlpha = particle.alpha
      ctx.fillStyle = particle.color
      ctx.fillRect(particle.x - 1, particle.y - 1, 2, 2)
      ctx.restore()
    })
  }
  
  drawStartScreen(ctx) {
    ctx.fillStyle = 'rgba(0, 0, 0, 0.7)'
    ctx.fillRect(0, 0, this.canvasTarget.width, this.canvasTarget.height)
    
    ctx.fillStyle = '#ffffff'
    ctx.font = '48px monospace'
    ctx.textAlign = 'center'
    ctx.fillText('HEMORRHOIDS', this.canvasTarget.width / 2, this.canvasTarget.height / 2 - 100)
    
    ctx.font = '24px monospace'
    ctx.fillText('PRESS SPACE TO START', this.canvasTarget.width / 2, this.canvasTarget.height / 2 + 50)
  }
  
  updateUI() {
    // Update score displays
    if (this.hasScoreTarget) {
      this.scoreTarget.textContent = this.gameState.score.toString().padStart(6, '0')
    }
    
    // Update lives displays  
    if (this.hasLivesTarget) {
      this.livesTarget.textContent = this.gameState.lives
    }
    
    // Update level displays
    if (this.hasLevelTarget) {
      this.levelTarget.textContent = this.gameState.level
    }
    
    // Update asteroids count displays
    if (this.hasAsteroidsTarget) {
      this.asteroidsTarget.textContent = this.gameState.asteroids.length
    }
    
    // Update individual UI elements
    const scoreDisplay = document.getElementById('scoreDisplay')
    if (scoreDisplay) scoreDisplay.textContent = this.gameState.score.toString().padStart(6, '0')
    
    const livesDisplay = document.getElementById('livesDisplay')
    if (livesDisplay) livesDisplay.textContent = this.gameState.lives
    
    const levelDisplay = document.getElementById('levelDisplay')
    if (levelDisplay) levelDisplay.textContent = this.gameState.level
    
    const asteroidsDisplay = document.getElementById('asteroidsDisplay')
    if (asteroidsDisplay) asteroidsDisplay.textContent = this.gameState.asteroids.length
    
    const score = document.getElementById('score')
    if (score) score.textContent = this.gameState.score
    
    const lives = document.getElementById('lives')
    if (lives) lives.textContent = this.gameState.lives
    
    const level = document.getElementById('level')
    if (level) level.textContent = this.gameState.level
    
    const asteroids = document.getElementById('asteroids')
    if (asteroids) asteroids.textContent = this.gameState.asteroids.length
  }
  
  playSound(soundType) {
    // Sound effects using Web Audio API with synthesized sounds
    try {
      const audioContext = new (window.AudioContext || window.webkitAudioContext)()
      
      switch (soundType) {
        case 'shoot':
          this.playLaserSound(audioContext)
          break
        case 'explosion':
          this.playExplosionSound(audioContext)
          break
        case 'hyperspace':
          this.playHyperspaceSound(audioContext)
          break
        case 'ufoShoot':
          this.playUFOSound(audioContext)
          break
      }
    } catch (error) {
      // Ignore audio errors if Web Audio API not supported
      console.log('Audio not available:', error.message)
    }
  }
  
  playLaserSound(audioContext) {
    const oscillator = audioContext.createOscillator()
    const gainNode = audioContext.createGain()
    
    oscillator.connect(gainNode)
    gainNode.connect(audioContext.destination)
    
    oscillator.frequency.setValueAtTime(800, audioContext.currentTime)
    oscillator.frequency.exponentialRampToValueAtTime(200, audioContext.currentTime + 0.1)
    
    gainNode.gain.setValueAtTime(0.3, audioContext.currentTime)
    gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.1)
    
    oscillator.start(audioContext.currentTime)
    oscillator.stop(audioContext.currentTime + 0.1)
  }
  
  playExplosionSound(audioContext) {
    const bufferSize = audioContext.sampleRate * 0.5
    const buffer = audioContext.createBuffer(1, bufferSize, audioContext.sampleRate)
    const output = buffer.getChannelData(0)
    
    for (let i = 0; i < bufferSize; i++) {
      output[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / bufferSize, 2)
    }
    
    const bufferSource = audioContext.createBufferSource()
    const gainNode = audioContext.createGain()
    
    bufferSource.buffer = buffer
    bufferSource.connect(gainNode)
    gainNode.connect(audioContext.destination)
    
    gainNode.gain.setValueAtTime(0.2, audioContext.currentTime)
    gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.5)
    
    bufferSource.start(audioContext.currentTime)
  }
  
  playHyperspaceSound(audioContext) {
    const oscillator = audioContext.createOscillator()
    const gainNode = audioContext.createGain()
    
    oscillator.connect(gainNode)
    gainNode.connect(audioContext.destination)
    
    oscillator.frequency.setValueAtTime(400, audioContext.currentTime)
    oscillator.frequency.exponentialRampToValueAtTime(1200, audioContext.currentTime + 0.3)
    oscillator.frequency.exponentialRampToValueAtTime(100, audioContext.currentTime + 0.6)
    
    gainNode.gain.setValueAtTime(0.2, audioContext.currentTime)
    gainNode.gain.linearRampToValueAtTime(0, audioContext.currentTime + 0.6)
    
    oscillator.start(audioContext.currentTime)
    oscillator.stop(audioContext.currentTime + 0.6)
  }
  
  playUFOSound(audioContext) {
    const oscillator = audioContext.createOscillator()
    const gainNode = audioContext.createGain()
    
    oscillator.connect(gainNode)
    gainNode.connect(audioContext.destination)
    
    oscillator.frequency.setValueAtTime(150, audioContext.currentTime)
    oscillator.frequency.exponentialRampToValueAtTime(300, audioContext.currentTime + 0.15)
    
    gainNode.gain.setValueAtTime(0.25, audioContext.currentTime)
    gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.15)
    
    oscillator.start(audioContext.currentTime)
    oscillator.stop(audioContext.currentTime + 0.15)
  }
  
  showLoadingScreen() {
    if (this.hasLoadingScreenTarget) {
      this.loadingScreenTarget.style.display = 'flex'
    }
  }
  
  hideLoadingScreen() {
    if (this.hasLoadingScreenTarget) {
      this.loadingScreenTarget.style.display = 'none'
    }
  }
  
  showError(error) {
    console.error("Game initialization error:", error)
    this.hideLoadingScreen()
    
    // Show error message to user
    const errorDiv = document.createElement('div')
    errorDiv.style.cssText = 'position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); color: red; font-size: 24px; text-align: center; background: rgba(0,0,0,0.8); padding: 20px; border-radius: 10px;'
    errorDiv.innerHTML = `
      <h3>Game Failed to Load</h3>
      <p>${error.message}</p>
      <p>Please refresh the page to try again.</p>
    `
    
    const container = this.element.querySelector('.whackeroids-container')
    if (container) {
      container.appendChild(errorDiv)
    }
  }
}