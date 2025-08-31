// Honky Pong - Streamlined Donkey Kong Clone for Rails
// Based on working Donkey Kong implementation

export class HonkyPongSimple {
  constructor(options = {}) {
    // Game container and UI elements
    this.container = options.container;
    this.scoreElement = options.scoreElement;
    this.livesElement = options.livesElement;
    this.startButton = options.startButton;
    this.gameOverElement = options.gameOverElement;
    
    if (!this.container) {
      throw new Error('Game container not found!');
    }
    
    // Get asset paths from data attributes
    this.assets = {
      donkeyKong: this.container.dataset.assetDonkeyKong,
      mono: this.container.dataset.assetMono,
      barriles: this.container.dataset.assetBarriles,
      barrilesGif: this.container.dataset.assetBarrilesGif,
      heart: this.container.dataset.assetHeart,
      hearts: this.container.dataset.assetHearts,
      hammer: this.container.dataset.assetHammer,
      gameOver: this.container.dataset.assetGameOver
    };
    
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
      <img class="donkey-kong-banner animate__animated animate__bounceInDown" 
           src="${this.assets.donkeyKong}" 
           alt="Honky Pong" 
           height="200px">
      <button class="btn-start animate__animated animate__tada">Start Game</button>
    `;
    
    // Re-attach start button listener
    const startBtn = this.container.querySelector('.btn-start');
    startBtn.addEventListener('click', () => this.startGame());
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
          <img class="donkey" 
               src="${this.assets.mono}" 
               alt="Donkey Kong" 
               height="160" 
               width="160">
          <img class="barrels-pile" 
               src="${this.assets.barriles}" 
               alt="Barrels" 
               height="140" 
               width="140">
        </div>
      </div>
      
      <!-- Enhanced Multi-Level Platform System -->
      <div class="platform platform-level-1"></div>
      <div class="platform platform-level-2"></div>
      <div class="platform platform-level-3"></div>
      <div class="platform platform-level-4"></div>
      <div class="platform platform-level-5"></div>
      
      <!-- Ladders connecting the platforms -->
      <div class="ladder ladder-1-2"></div>
      <div class="ladder ladder-2-3"></div>
      <div class="ladder ladder-3-4"></div>
      <div class="ladder ladder-4-5"></div>
      
      <!-- Legacy floors for compatibility -->
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
      if (mario.classList.contains('hammer')) {
        mario.classList.remove('view-left', 'hammer-left');
        mario.classList.add('hammer-right');
      } else {
        mario.classList.add('right');
        mario.classList.remove('view-left');
      }
    } else {
      mario.classList.remove('right');
    }
  }
  
  moveLeft(isPressed) {
    const mario = document.querySelector('.mario');
    if (!mario) return;
    
    if (isPressed && !mario.matches('.no-move')) {
      this.contRight -= 5;
      if (mario.classList.contains('hammer')) {
        mario.classList.remove('hammer-right', 'view-right');
        mario.classList.add('hammer-left');
      } else {
        mario.classList.add('view-left', 'left');
      }
    } else {
      mario.classList.remove('left');
    }
  }
  
  moveUp(isPressed) {
    const mario = document.querySelector('.mario');
    if (!mario) return;
    
    if (isPressed && !mario.matches('.no-move')) {
      mario.style.setProperty('--contRight', this.contRight + 'px');
      
      // Check for ladder climbing
      const nearbyLadder = this.checkLadderProximity(mario);
      if (nearbyLadder) {
        this.startClimbing(mario, nearbyLadder);
        return;
      }
      
      // Regular jump behavior
      if (mario.classList.contains('view-left')) {
        mario.classList.add('up-left');
      } else {
        mario.classList.add('up');
        mario.classList.remove('up-left');
      }
    } else {
      mario.classList.remove('up', 'up-left');
      if (mario.classList.contains('climbing')) {
        this.stopClimbing(mario);
      }
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
        if (mario.classList.contains('hammer-left')) {
          // Hit barrel with hammer but wrong direction - lose life
          this.playerHit(mario, barrel);
        } else if (mario.classList.contains('hammer')) {
          // Hit barrel with hammer correctly - score points
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
    const floorRight = document.querySelector('.floor-right');
    const containerKong = document.querySelector('.container-kong');
    const princess = document.querySelector('.princess');
    const mario = document.querySelector('.mario');
    
    // Animate princess rescue
    if (floorRight) floorRight.classList.add('animate__animated', 'animate__fadeOutDownBig');
    if (containerKong) containerKong.classList.add('animate__animated', 'animate__fadeOutDownBig');
    if (princess) princess.classList.add('princess-down');
    if (mario) {
      mario.className = 'mario no-move';
      this.contRight -= 20;
      mario.style.setProperty('--contRight', this.contRight + 'px');
    }
    
    this.addScore(2500);
    this.showHearts();
    
    setTimeout(() => {
      this.levelComplete();
    }, 7000);
  }
  
  showHearts() {
    const princess = document.querySelector('.princess');
    if (!princess) return;
    
    const hearts = document.createElement('img');
    hearts.className = 'hearts';
    hearts.src = this.assets.hearts;
    hearts.height = 40;
    hearts.width = 40;
    
    setTimeout(() => {
      princess.appendChild(hearts);
    }, 2000);
  }
  
  levelComplete() {
    this.showStartScreen();
    this.isGameRunning = false;
    this.clearIntervals();
  }
  
  addLives() {
    const livesDiv = document.createElement('div');
    livesDiv.className = 'content-lives';
    
    const heart = document.createElement('img');
    heart.className = 'heart-icon';
    heart.src = this.assets.heart;
    heart.height = 30;
    heart.width = 30;
    livesDiv.appendChild(heart);
    
    this.container.appendChild(livesDiv);
  }
  
  deleteLives() {
    const heart = document.querySelector('.content-lives img');
    if (heart) heart.remove();
  }
  
  addHammer() {
    const hammer = document.createElement('img');
    hammer.className = 'img-hammer';
    hammer.src = this.assets.hammer;
    hammer.height = 60;
    hammer.width = 60;
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
      <button class="btn-start restart animate__animated animate__tada">Restart</button>
    `;
    
    const restartBtn = this.container.querySelector('.btn-start');
    restartBtn.addEventListener('click', () => this.startGame());
    
    if (this.gameOverElement) {
      this.gameOverElement.classList.remove('game-over-hidden');
    }
  }
  
  clearIntervals() {
    this.gameIntervals.forEach(interval => clearInterval(interval));
    this.gameIntervals = [];
  }
  
  // Enhanced ladder climbing mechanics
  checkLadderProximity(mario) {
    const marioRect = mario.getBoundingClientRect();
    const ladders = document.querySelectorAll('.ladder');
    
    for (let ladder of ladders) {
      const ladderRect = ladder.getBoundingClientRect();
      
      // Check horizontal alignment with ladder (within 40px)
      const horizontalOverlap = Math.abs(marioRect.left + marioRect.width/2 - (ladderRect.left + ladderRect.width/2)) < 40;
      
      // Check if Mario is at the bottom of the ladder (can start climbing)
      const verticalOverlap = marioRect.bottom >= ladderRect.top - 20 && marioRect.bottom <= ladderRect.bottom + 20;
      
      if (horizontalOverlap && verticalOverlap) {
        return ladder;
      }
    }
    return null;
  }
  
  startClimbing(mario, ladder) {
    mario.classList.add('climbing');
    mario.classList.remove('up', 'up-left', 'left', 'right', 'view-left');
    
    const ladderRect = ladder.getBoundingClientRect();
    const marioRect = mario.getBoundingClientRect();
    
    // Center Mario on ladder
    const ladderCenter = ladderRect.left + ladderRect.width/2;
    const newContRight = ladderCenter - (mario.offsetParent?.getBoundingClientRect().left || 0) - 50;
    this.contRight = newContRight;
    mario.style.setProperty('--contRight', this.contRight + 'px');
    
    // Move Mario up the ladder
    const currentBottom = parseInt(mario.style.bottom) || 0;
    const newBottom = currentBottom + 5;
    mario.style.bottom = newBottom + 'px';
    
    // Check if reached top of ladder
    if (marioRect.top <= ladderRect.top + 20) {
      this.stopClimbing(mario);
      this.checkPlatformLanding(mario);
    }
  }
  
  stopClimbing(mario) {
    mario.classList.remove('climbing');
  }
  
  checkPlatformLanding(mario) {
    const marioRect = mario.getBoundingClientRect();
    const platforms = document.querySelectorAll('.platform');
    
    for (let platform of platforms) {
      const platformRect = platform.getBoundingClientRect();
      
      // Check if Mario should land on this platform
      const onPlatform = Math.abs(marioRect.bottom - platformRect.top) < 10 && 
                        marioRect.left < platformRect.right && 
                        marioRect.right > platformRect.left;
      
      if (onPlatform) {
        // Position Mario on the platform
        mario.style.bottom = (window.innerHeight - platformRect.top - 100) + "px";
        break;
      }
    }
  }
  
  destroy() {
    this.isGameRunning = false;
    this.clearIntervals();
    
    // Remove event listeners
    document.removeEventListener('keydown', this.handleKeyDown);
    document.removeEventListener('keyup', this.handleKeyUp);
  }
}