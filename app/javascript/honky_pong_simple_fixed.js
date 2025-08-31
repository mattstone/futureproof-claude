// Honky Pong Simple - Fixed version without CSP issues
// Basic game mechanics with simple colored shapes

export class HonkyPongSimpleFixed {
  constructor(options = {}) {
    this.container = options.container;
    this.scoreElement = options.scoreElement;
    this.livesElement = options.livesElement;
    this.startButton = options.startButton;
    this.gameOverElement = options.gameOverElement;
    
    if (!this.container) {
      throw new Error('Game container not found!');
    }
    
    // Game state
    this.lives = 1;
    this.score = 0;
    this.contRight = 0;
    this.isGameRunning = false;
    this.gameIntervals = [];
    
    // Key press tracking
    this.pressKey = {
      ArrowLeft: false,
      ArrowUp: false,
      ArrowRight: false,
    };
    
    this.init();
  }
  
  init() {
    this.setupEventListeners();
    this.showStartScreen();
  }
  
  setupEventListeners() {
    // Start button
    if (this.startButton) {
      this.startButton.addEventListener('click', () => {
        this.startGame();
      });
    }
    
    // Keyboard controls
    document.addEventListener('keydown', (e) => this.handleKeyDown(e));
    document.addEventListener('keyup', (e) => this.handleKeyUp(e));
  }
  
  showStartScreen() {
    this.container.className = 'honky-pong-container';
    this.container.innerHTML = `
      <div class="start-screen-content">
        <h2>🎮 HONKY PONG</h2>
        <p>Simple Donkey Kong Clone</p>
        <button class="btn-start">Start Game</button>
      </div>
    `;
    
    // Re-attach start button listener
    const startBtn = this.container.querySelector('.btn-start');
    if (startBtn) {
      startBtn.addEventListener('click', () => this.startGame());
    }
  }
  
  startGame() {
    this.lives = 1;
    this.score = 0;
    this.contRight = 0;
    this.isGameRunning = true;
    
    this.container.className = 'honky-pong-container play';
    this.container.innerHTML = `
      <div class="score-display">
        <h5>Score</h5>
        <p id="score-value">0</p>
      </div>
      <div class="game-area">
        <div class="mario"></div>
        <div class="container-kong">
          <div class="donkey">KONG</div>
          <div class="barrels-pile">BARRELS</div>
        </div>
      </div>
      <div class="floor"></div>
      <div class="floor-right"></div>
      <div class="princess"></div>
    `;
    
    this.addLives();
    this.addHammer();
    this.startBarrelSpawning();
    this.updateUI();
  }
  
  handleKeyDown(e) {
    if (!this.isGameRunning) return;
    
    const mario = document.querySelector('.mario');
    if (!mario || mario.matches('.no-move')) return;
    
    const key = e.code;
    
    // Reset all keys
    for (let i in this.pressKey) {
      this.pressKey[i] = (i === key);
    }
    
    this.handleMovement();
    mario.style.setProperty('--contRight', this.contRight + 'px');
  }
  
  handleKeyUp(e) {
    if (!this.isGameRunning) return;
    
    const mario = document.querySelector('.mario');
    if (!mario || mario.matches('.no-move')) return;
    
    // Reset all keys
    for (let i in this.pressKey) {
      this.pressKey[i] = false;
    }
    
    this.handleMovement();
    mario.style.setProperty('--contRight', this.contRight + 'px');
    this.checkPrincessCollision();
  }
  
  handleMovement() {
    const mario = document.querySelector('.mario');
    if (!mario) return;
    
    for (let key in this.pressKey) {
      if (key === 'ArrowLeft') {
        this.moveLeft(this.pressKey[key]);
      } else if (key === 'ArrowUp') {
        this.moveUp(this.pressKey[key]);
        this.checkHammerCollision();
      } else if (key === 'ArrowRight') {
        this.moveRight(this.pressKey[key]);
      }
    }
  }
  
  moveRight(isPressed) {
    const mario = document.querySelector('.mario');
    if (!mario) return;
    
    if (isPressed && !mario.matches('.no-move')) {
      this.contRight += 5;
      mario.classList.add('right');
      mario.classList.remove('view-left');
    } else {
      mario.classList.remove('right');
    }
  }
  
  moveLeft(isPressed) {
    const mario = document.querySelector('.mario');
    if (!mario) return;
    
    if (isPressed && !mario.matches('.no-move')) {
      this.contRight -= 5;
      mario.classList.add('left', 'view-left');
    } else {
      mario.classList.remove('left');
    }
  }
  
  moveUp(isPressed) {
    const mario = document.querySelector('.mario');
    if (!mario) return;
    
    if (isPressed && !mario.matches('.no-move')) {
      mario.style.setProperty('--contRight', this.contRight + 'px');
      mario.classList.add(mario.classList.contains('view-left') ? 'up-left' : 'up');
    } else {
      mario.classList.remove('up', 'up-left');
    }
  }
  
  startBarrelSpawning() {
    const spawnInterval = setInterval(() => {
      if (!this.isGameRunning) {
        clearInterval(spawnInterval);
        return;
      }
      this.spawnBarrel();
    }, 2000);
    
    this.gameIntervals.push(spawnInterval);
    
    // Spawn first barrel after delay
    setTimeout(() => {
      if (this.isGameRunning) this.spawnBarrel();
    }, 2100);
  }
  
  spawnBarrel() {
    const containerKong = document.querySelector('.container-kong');
    if (!containerKong) return;
    
    // Remove existing barrel if present
    const existingBarrel = document.querySelector('.new-barrel');
    if (existingBarrel) return;
    
    const barrel = document.createElement('div');
    barrel.className = 'new-barrel';
    containerKong.appendChild(barrel);
    
    // Track barrel movement
    this.trackBarrel(barrel);
    
    // Remove barrel after animation
    setTimeout(() => {
      if (barrel.parentNode) {
        barrel.remove();
      }
    }, 3000);
  }
  
  trackBarrel(barrel) {
    const trackingInterval = setInterval(() => {
      const mario = document.querySelector('.mario');
      if (!barrel.parentNode || !mario || !this.isGameRunning) {
        clearInterval(trackingInterval);
        return;
      }
      
      const marioRect = mario.getBoundingClientRect();
      const barrelRect = barrel.getBoundingClientRect();
      
      const marioX = Math.floor(marioRect.x);
      const marioY = Math.floor(marioRect.y);
      const barrelX = Math.floor(barrelRect.x);
      const barrelY = Math.floor(barrelRect.y - 37);
      
      // Check collision
      if (this.checkCollision(marioX, marioY, barrelX, barrelY)) {
        if (mario.classList.contains('hammer')) {
          // Hit barrel with hammer - score points
          this.barrelDestroyed(barrel);
          this.addScore(500);
        } else {
          // Hit by barrel - lose life
          this.playerHit(mario, barrel);
        }
        clearInterval(trackingInterval);
      }
      
      // Remove barrel if it goes off screen
      if (barrelX < 0) {
        barrel.remove();
        clearInterval(trackingInterval);
      }
    }, 16); // ~60fps
  }
  
  checkCollision(marioX, marioY, barrelX, barrelY) {
    return (barrelX - marioX <= 60 && 
            barrelX - marioX > 0 && 
            barrelY - marioY < 40);
  }
  
  playerHit(mario, barrel) {
    mario.classList.add('blink');
    barrel.remove();
    
    setTimeout(() => {
      this.lives--;
      this.deleteLives();
      mario.classList.remove('blink');
      
      if (this.lives <= 0) {
        this.gameOver();
      }
    }, 1000);
  }
  
  barrelDestroyed(barrel) {
    barrel.remove();
  }
  
  checkHammerCollision() {
    const hammer = document.querySelector('.img-hammer');
    const mario = document.querySelector('.mario');
    
    if (!hammer || !mario) return;
    
    const marioRect = mario.getBoundingClientRect();
    const hammerRect = hammer.getBoundingClientRect();
    
    const hammerX = Math.floor(hammerRect.x);
    const hammerY = Math.floor(hammerRect.y);
    const marioX = Math.floor(marioRect.x) + 35;
    const marioY = Math.floor(marioRect.y);
    
    if (marioX >= hammerX && 
        marioX <= hammerX + 50 && 
        marioY - hammerY < 10) {
      hammer.remove();
      mario.classList.add('hammer');
    }
  }
  
  checkPrincessCollision() {
    const mario = document.querySelector('.mario');
    const floorRight = document.querySelector('.floor-right');
    
    if (!mario || !floorRight) return;
    
    const marioRect = mario.getBoundingClientRect();
    const floorRect = floorRight.getBoundingClientRect();
    
    const marioX = Math.floor(marioRect.x);
    const floorX = Math.floor(floorRect.x);
    
    if (floorX - marioX < 90) {
      this.rescuePrincess();
    }
  }
  
  rescuePrincess() {
    const mario = document.querySelector('.mario');
    
    if (mario) {
      mario.className = 'mario no-move';
      this.contRight -= 20;
      mario.style.setProperty('--contRight', this.contRight + 'px');
    }
    
    this.addScore(2500);
    
    setTimeout(() => {
      this.levelComplete();
    }, 3000);
  }
  
  levelComplete() {
    this.showStartScreen();
    this.isGameRunning = false;
    this.clearIntervals();
  }
  
  addLives() {
    const livesDiv = document.createElement('div');
    livesDiv.className = 'content-lives';
    
    const heart = document.createElement('div');
    heart.className = 'heart-icon';
    heart.textContent = '❤️';
    livesDiv.appendChild(heart);
    
    this.container.appendChild(livesDiv);
  }
  
  deleteLives() {
    const heart = document.querySelector('.content-lives .heart-icon');
    if (heart) heart.remove();
  }
  
  addHammer() {
    const hammer = document.createElement('div');
    hammer.className = 'img-hammer';
    hammer.textContent = '🔨';
    this.container.appendChild(hammer);
  }
  
  addScore(points) {
    this.score += points;
    this.updateUI();
  }
  
  updateUI() {
    const scoreValue = document.getElementById('score-value');
    if (scoreValue) {
      scoreValue.textContent = this.score;
    }
    
    if (this.scoreElement) {
      this.scoreElement.textContent = this.score.toString().padStart(6, '0');
    }
  }
  
  gameOver() {
    this.isGameRunning = false;
    this.clearIntervals();
    
    this.container.className = 'honky-pong-container game-over';
    this.container.innerHTML = `
      <div class="game-over-content">
        <h2>🎮 GAME OVER! 🎮</h2>
        <p>Final Score: ${this.score}</p>
        <button class="btn-start restart">🔄 Play Again</button>
      </div>
    `;
    
    const restartBtn = this.container.querySelector('.btn-start');
    if (restartBtn) {
      restartBtn.addEventListener('click', () => this.startGame());
    }
  }
  
  clearIntervals() {
    this.gameIntervals.forEach(interval => clearInterval(interval));
    this.gameIntervals = [];
  }
  
  destroy() {
    this.isGameRunning = false;
    this.clearIntervals();
    
    // Remove event listeners
    document.removeEventListener('keydown', this.handleKeyDown);
    document.removeEventListener('keyup', this.handleKeyUp);
  }
}