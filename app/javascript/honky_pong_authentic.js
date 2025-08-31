// Honky Pong - Authentic Donkey Kong Clone
// Proper implementation with authentic game mechanics and sprite usage

import { AudioManager } from "audio_manager"

export class HonkyPongGame {
  constructor(options = {}) {
    // Setup DOM elements
    this.canvas = options.canvas || document.getElementById('gameCanvas');
    this.scoreElement = options.scoreElement || document.getElementById('score');
    this.livesElement = options.livesElement || document.getElementById('lives');
    this.levelElement = options.levelElement || document.getElementById('level');
    this.bonusElement = options.bonusElement || document.getElementById('bonus');
    this.startButton = options.startButton || document.getElementById('startButton');
    this.pauseButton = options.pauseButton || document.getElementById('pauseButton');
    this.gameOverElement = options.gameOverElement || document.getElementById('gameOver');
    this.finalScoreElement = options.finalScoreElement || document.getElementById('finalScore');
    this.restartButton = options.restartButton || document.getElementById('restartButton');
    
    if (!this.canvas) {
      throw new Error('Game canvas not found!');
    }
    
    this.ctx = this.canvas.getContext('2d');
    this.width = this.canvas.width;
    this.height = this.canvas.height;
    
    // Game state
    this.gameState = 'menu'; // menu, playing, paused, gameOver, levelComplete
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.bonus = 5000;
    this.bonusTimer = 0;
    
    // Input handling
    this.keys = {};
    this.lastKeys = {};
    
    // Sprite management
    this.sprites = {};
    this.assetsLoaded = false;
    this.loadAssets();
    
    // Game objects
    this.mario = null;
    this.donkeyKong = null;
    this.barrels = [];
    this.ladders = [];
    this.platforms = [];
    this.hammers = [];
    this.collectibles = [];
    this.particles = [];
    
    // Audio
    this.audioManager = new AudioManager();
    this.setupAudio();
    
    // Setup event handlers
    this.setupEventHandlers();
    
    // Game loop
    this.lastTime = 0;
    this.running = false;
  }
  
  async loadAssets() {
    const assetPaths = {
      mario: this.canvas.dataset.marioSprite,
      enemies: this.canvas.dataset.enemiesSprite,
      pauline: this.canvas.dataset.paulineSprite,
      levels: this.canvas.dataset.levelsSprite
    };
    
    try {
      const promises = Object.entries(assetPaths).map(([key, path]) => {
        return new Promise((resolve, reject) => {
          if (!path) {
            console.warn(`No path found for ${key} sprite`);
            resolve(null);
            return;
          }
          
          const img = new Image();
          img.onload = () => resolve({key, img});
          img.onerror = () => {
            console.warn(`Failed to load ${key} sprite from ${path}`);
            resolve(null);
          };
          img.src = path;
        });
      });
      
      const results = await Promise.all(promises);
      
      results.forEach(result => {
        if (result && result.img) {
          this.sprites[result.key] = result.img;
        }
      });
      
      this.assetsLoaded = true;
      this.initializeLevel();
      console.log('✅ Honky Pong assets loaded successfully');
      
    } catch (error) {
      console.error('Failed to load game assets:', error);
      this.assetsLoaded = false;
    }
  }
  
  setupAudio() {
    const soundPaths = {
      background: this.canvas.dataset.soundBacmusic,
      death: this.canvas.dataset.soundDeath,
      hammer: this.canvas.dataset.soundHammer,
      howhigh: this.canvas.dataset.soundHowhigh,
      intro: this.canvas.dataset.soundIntro,
      itemget: this.canvas.dataset.soundItemget,
      jump: this.canvas.dataset.soundJump,
      walking: this.canvas.dataset.soundWalking,
      win1: this.canvas.dataset.soundWin1,
      win2: this.canvas.dataset.soundWin2
    };
    
    Object.entries(soundPaths).forEach(([key, path]) => {
      if (path) {
        this.audioManager.loadSound(key, path);
      }
    });
  }
  
  initializeLevel() {
    // Classic Donkey Kong level layout
    this.platforms = [
      // Bottom platform (ground level)
      { x: 0, y: this.height - 32, width: this.width, height: 32 },
      // Platform levels (authentic DK layout)
      { x: 0, y: this.height - 140, width: 200, height: 20 },
      { x: 240, y: this.height - 140, width: this.width - 240, height: 20 },
      { x: 0, y: this.height - 220, width: this.width - 200, height: 20 },
      { x: this.width - 160, y: this.height - 220, width: 160, height: 20 },
      { x: 40, y: this.height - 300, width: this.width - 80, height: 20 },
      { x: 0, y: this.height - 380, width: 200, height: 20 },
      { x: 240, y: this.height - 380, width: this.width - 240, height: 20 },
      { x: 0, y: this.height - 460, width: this.width - 100, height: 20 },
      // Top platform (Donkey Kong's level)
      { x: 0, y: 80, width: this.width, height: 20 }
    ];
    
    this.ladders = [
      // Ladders connecting platforms (authentic placement)
      { x: 220, y: this.height - 140, width: 20, height: 108 },
      { x: this.width - 220, y: this.height - 240, width: 20, height: 120 },
      { x: 60, y: this.height - 320, width: 20, height: 120 },
      { x: this.width - 80, y: this.height - 400, width: 20, height: 120 },
      { x: 120, y: this.height - 480, width: 20, height: 120 },
      // Ladders to top level
      { x: this.width - 160, y: 80, width: 20, height: 380 },
      { x: 200, y: 80, width: 20, height: 120 }
    ];
    
    // Initialize Mario (Jumpman)
    this.mario = {
      x: 80,
      y: this.height - 64,
      width: 16,
      height: 24,
      vx: 0,
      vy: 0,
      speed: 2.0,
      onGround: false,
      onLadder: false,
      climbing: false,
      facing: 'right',
      animFrame: 0,
      animTimer: 0,
      jumpTimer: 0,
      isJumping: false,
      hasHammer: false,
      hammerTimer: 0
    };
    
    // Initialize Donkey Kong
    this.donkeyKong = {
      x: this.width - 100,
      y: 40,
      width: 32,
      height: 32,
      animFrame: 0,
      animTimer: 0,
      barrelTimer: 0,
      barrelDelay: 120  // frames between barrels
    };
    
    // Initialize Princess Pauline
    this.pauline = {
      x: this.width - 200,
      y: 40,
      width: 16,
      height: 24,
      animFrame: 0,
      animTimer: 0
    };
    
    // Clear dynamic objects
    this.barrels = [];
    this.hammers = [];
    this.collectibles = [];
    this.particles = [];
    
    // Add hammers to level
    this.hammers.push(
      { x: 150, y: this.height - 160, width: 16, height: 16, collected: false },
      { x: this.width - 150, y: this.height - 320, width: 16, height: 16, collected: false }
    );
    
    console.log(`🎮 Level ${this.level} initialized with authentic Donkey Kong layout`);
  }
  
  setupEventHandlers() {
    // Button handlers
    if (this.startButton) {
      this.startButton.addEventListener('click', () => this.startGame());
    }
    
    if (this.pauseButton) {
      this.pauseButton.addEventListener('click', () => this.togglePause());
    }
    
    if (this.restartButton) {
      this.restartButton.addEventListener('click', () => this.restartGame());
    }
    
    // Keyboard handlers (bound to this context)
    document.addEventListener('keydown', (e) => this.handleKeyDown(e));
    document.addEventListener('keyup', (e) => this.handleKeyUp(e));
  }
  
  handleKeyDown(event) {
    if (this.gameState !== 'playing') return;
    
    const key = event.code;
    this.keys[key] = true;
    
    // Handle jump (spacebar)
    if (key === 'Space' && !this.mario.isJumping && this.mario.onGround) {
      this.jump();
      event.preventDefault();
    }
    
    // Handle pause
    if (key === 'KeyP') {
      this.togglePause();
      event.preventDefault();
    }
    
    // Handle restart
    if (key === 'KeyR' && this.gameState === 'gameOver') {
      this.restartGame();
      event.preventDefault();
    }
  }
  
  handleKeyUp(event) {
    const key = event.code;
    this.keys[key] = false;
  }
  
  startGame() {
    this.gameState = 'playing';
    this.running = true;
    this.audioManager.playSound('intro');
    
    if (this.startButton) this.startButton.disabled = true;
    if (this.pauseButton) this.pauseButton.disabled = false;
    if (this.gameOverElement) this.gameOverElement.classList.add('game-over-hidden');
    
    this.gameLoop();
  }
  
  togglePause() {
    if (this.gameState === 'playing') {
      this.gameState = 'paused';
      this.running = false;
    } else if (this.gameState === 'paused') {
      this.gameState = 'playing';
      this.running = true;
      this.gameLoop();
    }
  }
  
  restartGame() {
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.bonus = 5000;
    this.updateUI();
    this.initializeLevel();
    this.startGame();
  }
  
  jump() {
    if (this.mario.onGround && !this.mario.isJumping) {
      this.mario.isJumping = true;
      this.mario.jumpTimer = 15; // Jump duration in frames
      this.mario.vy = -6; // Jump velocity
      this.mario.onGround = false;
      this.audioManager.playSound('jump');
    }
  }
  
  gameLoop(currentTime = 0) {
    if (!this.running || this.gameState !== 'playing') return;
    
    const deltaTime = currentTime - this.lastTime;
    this.lastTime = currentTime;
    
    this.update(deltaTime);
    this.render();
    
    requestAnimationFrame((time) => this.gameLoop(time));
  }
  
  update(deltaTime) {
    if (!this.assetsLoaded) return;
    
    this.updateMario();
    this.updateDonkeyKong();
    this.updateBarrels();
    this.updateCollisions();
    this.updateBonus();
    this.updateAnimations();
    
    // Check win condition (Mario reaches top)
    if (this.mario.y <= 120) {
      this.levelComplete();
    }
  }
  
  updateMario() {
    // Store last position
    const lastX = this.mario.x;
    const lastY = this.mario.y;
    
    // Horizontal movement
    if (this.keys['ArrowLeft']) {
      this.mario.vx = -this.mario.speed;
      this.mario.facing = 'left';
    } else if (this.keys['ArrowRight']) {
      this.mario.vx = this.mario.speed;
      this.mario.facing = 'right';
    } else {
      this.mario.vx = 0;
    }
    
    // Vertical movement (climbing)
    if (this.keys['ArrowUp'] || this.keys['ArrowDown']) {
      const onLadder = this.checkLadderCollision(this.mario);
      if (onLadder) {
        this.mario.climbing = true;
        this.mario.onLadder = true;
        this.mario.vy = 0; // Cancel gravity while climbing
        
        if (this.keys['ArrowUp']) {
          this.mario.y -= this.mario.speed;
        } else if (this.keys['ArrowDown']) {
          this.mario.y += this.mario.speed;
        }
      }
    } else {
      this.mario.climbing = false;
      this.mario.onLadder = false;
    }
    
    // Apply horizontal movement
    this.mario.x += this.mario.vx;
    
    // Apply gravity (if not climbing)
    if (!this.mario.climbing) {
      this.mario.vy += 0.3; // Gravity
      this.mario.y += this.mario.vy;
    }
    
    // Platform collision
    this.mario.onGround = false;
    for (const platform of this.platforms) {
      if (this.mario.x + this.mario.width > platform.x &&
          this.mario.x < platform.x + platform.width &&
          this.mario.y + this.mario.height >= platform.y &&
          this.mario.y + this.mario.height <= platform.y + platform.height + 8) {
        
        this.mario.y = platform.y - this.mario.height;
        this.mario.vy = 0;
        this.mario.onGround = true;
        this.mario.isJumping = false;
        break;
      }
    }
    
    // Screen boundaries
    this.mario.x = Math.max(0, Math.min(this.width - this.mario.width, this.mario.x));
    this.mario.y = Math.max(0, Math.min(this.height - this.mario.height, this.mario.y));
    
    // Update jump timer
    if (this.mario.isJumping && this.mario.jumpTimer > 0) {
      this.mario.jumpTimer--;
      if (this.mario.jumpTimer <= 0) {
        this.mario.isJumping = false;
      }
    }
    
    // Update hammer timer
    if (this.mario.hasHammer && this.mario.hammerTimer > 0) {
      this.mario.hammerTimer--;
      if (this.mario.hammerTimer <= 0) {
        this.mario.hasHammer = false;
      }
    }
  }
  
  checkLadderCollision(obj) {
    for (const ladder of this.ladders) {
      if (obj.x + obj.width/2 > ladder.x &&
          obj.x + obj.width/2 < ladder.x + ladder.width &&
          obj.y + obj.height >= ladder.y &&
          obj.y <= ladder.y + ladder.height) {
        return true;
      }
    }
    return false;
  }
  
  updateDonkeyKong() {
    this.donkeyKong.animTimer++;
    if (this.donkeyKong.animTimer >= 30) {
      this.donkeyKong.animFrame = (this.donkeyKong.animFrame + 1) % 2;
      this.donkeyKong.animTimer = 0;
    }
    
    // Barrel throwing
    this.donkeyKong.barrelTimer++;
    if (this.donkeyKong.barrelTimer >= this.donkeyKong.barrelDelay) {
      this.throwBarrel();
      this.donkeyKong.barrelTimer = 0;
      // Vary delay for difficulty
      this.donkeyKong.barrelDelay = 60 + Math.random() * 120;
    }
  }
  
  throwBarrel() {
    const barrel = {
      x: this.donkeyKong.x,
      y: this.donkeyKong.y + 20,
      width: 16,
      height: 16,
      vx: -1 - Math.random(),
      vy: 0,
      onGround: false,
      animFrame: 0,
      animTimer: 0
    };
    
    this.barrels.push(barrel);
    console.log('🛢️ Donkey Kong threw a barrel!');
  }
  
  updateBarrels() {
    for (let i = this.barrels.length - 1; i >= 0; i--) {
      const barrel = this.barrels[i];
      
      // Apply movement
      barrel.x += barrel.vx;
      
      // Apply gravity
      if (!barrel.onGround) {
        barrel.vy += 0.3;
        barrel.y += barrel.vy;
      }
      
      // Platform collision for barrels
      barrel.onGround = false;
      for (const platform of this.platforms) {
        if (barrel.x + barrel.width > platform.x &&
            barrel.x < platform.x + platform.width &&
            barrel.y + barrel.height >= platform.y &&
            barrel.y + barrel.height <= platform.y + platform.height + 8) {
          
          barrel.y = platform.y - barrel.height;
          barrel.vy = 0;
          barrel.onGround = true;
          
          // Authentic Donkey Kong barrel behavior: roll and bounce
          if (Math.abs(barrel.vx) < 0.5) {
            barrel.vx = barrel.vx < 0 ? -1.5 : 1.5;
          }
          
          // Check for ladder descent (barrels can fall down ladders)
          for (const ladder of this.ladders) {
            if (barrel.x + barrel.width/2 > ladder.x &&
                barrel.x + barrel.width/2 < ladder.x + ladder.width &&
                barrel.y + barrel.height >= ladder.y &&
                barrel.y + barrel.height <= ladder.y + 20) {
              
              // 30% chance barrel falls down ladder (authentic behavior)
              if (Math.random() < 0.3) {
                barrel.vy = 2;
                barrel.onGround = false;
                barrel.vx *= 0.5; // Slow horizontal movement while falling
                break;
              }
            }
          }
          break;
        }
      }
      
      // Animation (rolling barrels)
      barrel.animTimer++;
      if (barrel.animTimer >= 8) {
        barrel.animFrame = (barrel.animFrame + 1) % 4;
        barrel.animTimer = 0;
      }
      
      // Remove barrels that fall off screen
      if (barrel.y > this.height + 50 || barrel.x < -50) {
        this.barrels.splice(i, 1);
      }
    }
  }
  
  updateCollisions() {
    // Mario vs Barrels
    for (let i = this.barrels.length - 1; i >= 0; i--) {
      const barrel = this.barrels[i];
      
      if (this.mario.x < barrel.x + barrel.width &&
          this.mario.x + this.mario.width > barrel.x &&
          this.mario.y < barrel.y + barrel.height &&
          this.mario.y + this.mario.height > barrel.y) {
        
        if (this.mario.hasHammer) {
          // Smash barrel with hammer
          this.barrels.splice(i, 1);
          this.score += 500;
          this.audioManager.playSound('hammer');
          this.updateUI();
        } else {
          // Mario dies
          this.marioDies();
          return;
        }
      }
    }
    
    // Mario vs Hammers
    for (const hammer of this.hammers) {
      if (!hammer.collected &&
          this.mario.x < hammer.x + hammer.width &&
          this.mario.x + this.mario.width > hammer.x &&
          this.mario.y < hammer.y + hammer.height &&
          this.mario.y + this.mario.height > hammer.y) {
        
        hammer.collected = true;
        this.mario.hasHammer = true;
        this.mario.hammerTimer = 300; // Hammer duration
        this.score += 100;
        this.audioManager.playSound('itemget');
        this.updateUI();
      }
    }
  }
  
  marioDies() {
    this.lives--;
    this.audioManager.playSound('death');
    this.updateUI();
    
    if (this.lives <= 0) {
      this.gameOver();
    } else {
      // Reset Mario position
      this.mario.x = 80;
      this.mario.y = this.height - 64;
      this.mario.vx = 0;
      this.mario.vy = 0;
      this.mario.hasHammer = false;
      // Brief invulnerability could be added here
    }
  }
  
  levelComplete() {
    // Authentic Donkey Kong scoring
    this.score += this.bonus; // Remaining bonus time
    this.score += 5000; // Level completion bonus (authentic DK value)
    this.score += this.mario.y < 100 ? 8000 : 0; // Extra points for reaching Pauline
    
    this.level++;
    this.bonus = Math.max(2000, 5000 - (this.level * 500)); // Bonus decreases with level
    
    this.audioManager.playSound('win1');
    this.updateUI();
    
    console.log(`🏆 Level ${this.level - 1} complete! Score: ${this.score}`);
    
    // Brief celebration before next level
    setTimeout(() => {
      this.initializeLevel();
      this.audioManager.playSound('howhigh');
    }, 2000);
  }
  
  gameOver() {
    this.gameState = 'gameOver';
    this.running = false;
    
    if (this.finalScoreElement) {
      this.finalScoreElement.textContent = this.score.toString().padStart(6, '0');
    }
    
    if (this.gameOverElement) {
      this.gameOverElement.classList.remove('game-over-hidden');
    }
    
    if (this.startButton) this.startButton.disabled = false;
    if (this.pauseButton) this.pauseButton.disabled = true;
  }
  
  updateBonus() {
    if (this.bonus > 0) {
      this.bonusTimer++;
      if (this.bonusTimer >= 60) { // Decrease every second (at 60fps)
        this.bonus -= 100;
        this.bonusTimer = 0;
        this.updateUI();
      }
    }
  }
  
  updateAnimations() {
    this.mario.animTimer++;
    if (this.mario.animTimer >= 10) {
      if (Math.abs(this.mario.vx) > 0 || this.mario.climbing) {
        this.mario.animFrame = (this.mario.animFrame + 1) % 3;
      } else {
        this.mario.animFrame = 0; // Standing pose
      }
      this.mario.animTimer = 0;
    }
  }
  
  render() {
    if (!this.assetsLoaded) {
      this.renderLoadingScreen();
      return;
    }
    
    // Clear canvas
    this.ctx.fillStyle = '#000000';
    this.ctx.fillRect(0, 0, this.width, this.height);
    
    this.renderLevel();
    this.renderBarrels();
    this.renderHammers();
    this.renderDonkeyKong();
    this.renderMario();
    this.renderPauline();
    this.renderUI();
  }
  
  renderLoadingScreen() {
    this.ctx.fillStyle = '#000080';
    this.ctx.fillRect(0, 0, this.width, this.height);
    
    this.ctx.fillStyle = '#FFFF00';
    this.ctx.font = 'bold 24px Arial';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('HONKY PONG', this.width/2, this.height/2 - 40);
    
    this.ctx.font = '16px Arial';
    this.ctx.fillText('Loading authentic Donkey Kong assets...', this.width/2, this.height/2);
    
    // Loading animation
    const dots = '.'.repeat((Math.floor(Date.now() / 500) % 4));
    this.ctx.fillText(dots, this.width/2, this.height/2 + 30);
  }
  
  renderLevel() {
    // Render platforms
    this.ctx.fillStyle = '#FF4444';
    for (const platform of this.platforms) {
      this.ctx.fillRect(platform.x, platform.y, platform.width, platform.height);
    }
    
    // Render ladders
    this.ctx.fillStyle = '#FFFF00';
    for (const ladder of this.ladders) {
      // Draw ladder rungs
      for (let y = ladder.y; y < ladder.y + ladder.height; y += 8) {
        this.ctx.fillRect(ladder.x, y, ladder.width, 2);
      }
    }
  }
  
  renderBarrels() {
    for (const barrel of this.barrels) {
      if (this.sprites.enemies) {
        // Use barrel sprite from enemies spritesheet
        this.drawSprite(this.sprites.enemies, 
                       barrel.animFrame * 16, 0, 16, 16,
                       barrel.x, barrel.y, barrel.width, barrel.height);
      } else {
        // Fallback rectangle
        this.ctx.fillStyle = '#8B4513';
        this.ctx.fillRect(barrel.x, barrel.y, barrel.width, barrel.height);
      }
    }
  }
  
  renderHammers() {
    for (const hammer of this.hammers) {
      if (!hammer.collected) {
        this.ctx.fillStyle = '#C0C0C0';
        this.ctx.fillRect(hammer.x, hammer.y, hammer.width, hammer.height);
      }
    }
  }
  
  renderMario() {
    if (this.sprites.mario) {
      let spriteX = 0;
      let spriteY = 0;
      
      // Calculate sprite position based on animation and state
      if (this.mario.climbing) {
        spriteX = 32 + (this.mario.animFrame * 16);
        spriteY = 0;
      } else if (this.mario.hasHammer) {
        spriteX = 80 + (this.mario.animFrame * 16);
        spriteY = 0;
      } else if (Math.abs(this.mario.vx) > 0) {
        spriteX = this.mario.animFrame * 16;
        spriteY = this.mario.facing === 'left' ? 16 : 0;
      } else {
        spriteX = 0;
        spriteY = this.mario.facing === 'left' ? 16 : 0;
      }
      
      this.drawSprite(this.sprites.mario, 
                     spriteX, spriteY, 16, 24,
                     this.mario.x, this.mario.y, this.mario.width, this.mario.height);
    } else {
      // Fallback rectangle
      this.ctx.fillStyle = this.mario.hasHammer ? '#FF00FF' : '#0000FF';
      this.ctx.fillRect(this.mario.x, this.mario.y, this.mario.width, this.mario.height);
    }
  }
  
  renderDonkeyKong() {
    if (this.sprites.enemies) {
      // DK sprite from enemies sheet
      this.drawSprite(this.sprites.enemies, 
                     64 + (this.donkeyKong.animFrame * 32), 16, 32, 32,
                     this.donkeyKong.x, this.donkeyKong.y, this.donkeyKong.width, this.donkeyKong.height);
    } else {
      // Fallback
      this.ctx.fillStyle = '#8B4513';
      this.ctx.fillRect(this.donkeyKong.x, this.donkeyKong.y, this.donkeyKong.width, this.donkeyKong.height);
    }
  }
  
  renderPauline() {
    if (this.sprites.pauline) {
      this.drawSprite(this.sprites.pauline, 
                     0, 0, 16, 24,
                     this.pauline.x, this.pauline.y, this.pauline.width, this.pauline.height);
    } else {
      // Fallback
      this.ctx.fillStyle = '#FF69B4';
      this.ctx.fillRect(this.pauline.x, this.pauline.y, this.pauline.width, this.pauline.height);
    }
  }
  
  renderUI() {
    // Game state text
    if (this.gameState === 'paused') {
      this.ctx.fillStyle = 'rgba(0,0,0,0.7)';
      this.ctx.fillRect(0, 0, this.width, this.height);
      
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.font = 'bold 36px Arial';
      this.ctx.textAlign = 'center';
      this.ctx.fillText('PAUSED', this.width/2, this.height/2);
      this.ctx.font = '16px Arial';
      this.ctx.fillText('Press P to resume', this.width/2, this.height/2 + 40);
    }
  }
  
  drawSprite(image, sx, sy, sw, sh, dx, dy, dw, dh) {
    try {
      this.ctx.drawImage(image, sx, sy, sw, sh, dx, dy, dw, dh);
    } catch (error) {
      // Fallback if sprite drawing fails
      this.ctx.fillStyle = '#FF0000';
      this.ctx.fillRect(dx, dy, dw, dh);
    }
  }
  
  updateUI() {
    if (this.scoreElement) {
      this.scoreElement.textContent = this.score.toString().padStart(6, '0');
    }
    if (this.livesElement) {
      this.livesElement.textContent = this.lives.toString();
    }
    if (this.levelElement) {
      this.levelElement.textContent = this.level.toString();
    }
    if (this.bonusElement) {
      this.bonusElement.textContent = this.bonus.toString();
    }
  }
  
  destroy() {
    this.running = false;
    // Clean up resources
    if (this.audioManager) {
      this.audioManager.stopAll();
    }
  }
}

// Export for dynamic import compatibility
export { HonkyPongGame };