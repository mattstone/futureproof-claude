// Fresh Start - Proper Donkey Kong Clone
// Actually renders the levels from the sprite sheet

export class HonkyPongGame {
  constructor(options = {}) {
    this.canvas = options.canvas;
    this.ctx = this.canvas.getContext('2d');
    
    // Game dimensions
    this.width = this.canvas.width;
    this.height = this.canvas.height;
    
    // Load sprites
    this.sprites = {};
    this.loadSprites();
    
    // Game state
    this.gameState = 'loading';
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    
    // Mario
    this.mario = {
      x: 50,
      y: this.height - 80,
      width: 24,
      height: 24,
      vx: 0,
      vy: 0,
      speed: 3,
      onGround: false,
      facing: 'right'
    };
    
    // Donkey Kong
    this.donkeyKong = {
      x: 100,
      y: 100,
      width: 48,
      height: 48
    };
    
    // Barrels
    this.barrels = [];
    
    // Input
    this.keys = {};
    
    // Setup controls
    this.setupControls();
    
    // UI elements
    this.scoreElement = options.scoreElement;
    this.livesElement = options.livesElement;
    this.startButton = options.startButton;
    
    if (this.startButton) {
      this.startButton.addEventListener('click', () => this.startGame());
    }
  }
  
  async loadSprites() {
    const paths = {
      mario: this.canvas.dataset.marioSprite,
      levels: this.canvas.dataset.levelsSprite,
      enemies: this.canvas.dataset.enemiesSprite,
      pauline: this.canvas.dataset.paulineSprite
    };
    
    for (const [key, path] of Object.entries(paths)) {
      if (path) {
        try {
          const img = new Image();
          await new Promise((resolve, reject) => {
            img.onload = resolve;
            img.onerror = reject;
            img.src = path;
          });
          this.sprites[key] = img;
          console.log(`✅ Loaded ${key} sprite`);
        } catch (error) {
          console.warn(`❌ Failed to load ${key}:`, error);
        }
      }
    }
    
    this.gameState = 'ready';
    console.log('🎮 All sprites loaded, ready to start!');
  }
  
  setupControls() {
    document.addEventListener('keydown', (e) => {
      this.keys[e.code] = true;
      
      if (e.code === 'Space') {
        this.jump();
        e.preventDefault();
      }
    });
    
    document.addEventListener('keyup', (e) => {
      this.keys[e.code] = false;
    });
  }
  
  startGame() {
    if (this.gameState !== 'ready') return;
    
    this.gameState = 'playing';
    this.gameLoop();
    
    if (this.startButton) this.startButton.disabled = true;
  }
  
  jump() {
    if (this.mario.onGround) {
      this.mario.vy = -12;
      this.mario.onGround = false;
    }
  }
  
  gameLoop() {
    if (this.gameState !== 'playing') return;
    
    this.update();
    this.render();
    
    requestAnimationFrame(() => this.gameLoop());
  }
  
  update() {
    this.updateMario();
    this.updateBarrels();
  }
  
  updateMario() {
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
    
    // Apply movement
    this.mario.x += this.mario.vx;
    
    // Gravity
    this.mario.vy += 0.5;
    this.mario.y += this.mario.vy;
    
    // Simple ground collision (bottom of screen for now)
    if (this.mario.y >= this.height - 80) {
      this.mario.y = this.height - 80;
      this.mario.vy = 0;
      this.mario.onGround = true;
    }
    
    // Screen boundaries
    this.mario.x = Math.max(0, Math.min(this.width - this.mario.width, this.mario.x));
  }
  
  updateBarrels() {
    // Add barrels occasionally
    if (Math.random() < 0.01) {
      this.barrels.push({
        x: this.donkeyKong.x + 20,
        y: this.donkeyKong.y + 40,
        width: 16,
        height: 16,
        vx: -2,
        vy: 0
      });
    }
    
    // Update barrel positions
    for (let i = this.barrels.length - 1; i >= 0; i--) {
      const barrel = this.barrels[i];
      barrel.x += barrel.vx;
      barrel.vy += 0.3;
      barrel.y += barrel.vy;
      
      // Simple ground collision
      if (barrel.y >= this.height - 60) {
        barrel.y = this.height - 60;
        barrel.vy = 0;
      }
      
      // Remove barrels that are off screen
      if (barrel.x < -50) {
        this.barrels.splice(i, 1);
      }
    }
  }
  
  render() {
    // Clear screen - proper black background
    this.ctx.fillStyle = '#000000';
    this.ctx.fillRect(0, 0, this.width, this.height);
    
    if (this.gameState === 'loading') {
      this.renderLoading();
      return;
    }
    
    // Render level structure using the actual sprite
    this.renderLevel();
    
    // Render Donkey Kong
    this.renderDonkeyKong();
    
    // Render barrels
    this.renderBarrels();
    
    // Render Mario
    this.renderMario();
    
    // Render basic UI
    this.renderUI();
  }
  
  renderLoading() {
    this.ctx.fillStyle = '#FFFF00';
    this.ctx.font = '24px Arial';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('Loading Donkey Kong...', this.width/2, this.height/2);
  }
  
  renderLevel() {
    if (!this.sprites.levels) {
      // Fallback - draw simple platforms
      this.ctx.fillStyle = '#FF4444';
      // Bottom platform
      this.ctx.fillRect(0, this.height - 32, this.width, 32);
      // A few more platforms
      this.ctx.fillRect(0, this.height - 150, this.width * 0.8, 20);
      this.ctx.fillRect(this.width * 0.2, this.height - 250, this.width * 0.8, 20);
      
      // Simple ladders
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.fillRect(200, this.height - 150, 8, 100);
      this.ctx.fillRect(this.width - 100, this.height - 250, 8, 100);
      return;
    }
    
    // Use the actual level sprite - draw the first level layout (top-left of spritesheet)
    // The level sprite shows the classic DK layout with angled girders
    this.ctx.drawImage(
      this.sprites.levels,
      0, 0,           // Source x, y (top-left level)
      256, 232,       // Source width, height (size of one level)
      0, 0,           // Destination x, y
      this.width, this.height  // Destination width, height (scale to canvas)
    );
  }
  
  renderDonkeyKong() {
    if (this.sprites.enemies) {
      // Draw DK from enemies sprite
      this.ctx.drawImage(
        this.sprites.enemies,
        64, 16,         // DK sprite position in enemies sheet
        32, 32,         // DK sprite size
        this.donkeyKong.x, this.donkeyKong.y,
        this.donkeyKong.width, this.donkeyKong.height
      );
    } else {
      // Fallback
      this.ctx.fillStyle = '#8B4513';
      this.ctx.fillRect(this.donkeyKong.x, this.donkeyKong.y, this.donkeyKong.width, this.donkeyKong.height);
    }
  }
  
  renderBarrels() {
    this.ctx.fillStyle = '#8B4513';
    for (const barrel of this.barrels) {
      if (this.sprites.enemies) {
        // Use barrel sprite from enemies sheet
        this.ctx.drawImage(
          this.sprites.enemies,
          0, 0,           // Barrel sprite position
          16, 16,         // Barrel sprite size
          barrel.x, barrel.y,
          barrel.width, barrel.height
        );
      } else {
        // Fallback
        this.ctx.fillRect(barrel.x, barrel.y, barrel.width, barrel.height);
      }
    }
  }
  
  renderMario() {
    if (this.sprites.mario) {
      // Draw Mario from sprite sheet
      let spriteX = 0;
      let spriteY = this.mario.facing === 'left' ? 24 : 0;
      
      this.ctx.drawImage(
        this.sprites.mario,
        spriteX, spriteY,   // Source position
        24, 24,             // Source size
        this.mario.x, this.mario.y,
        this.mario.width, this.mario.height
      );
    } else {
      // Fallback
      this.ctx.fillStyle = '#0000FF';
      this.ctx.fillRect(this.mario.x, this.mario.y, this.mario.width, this.mario.height);
    }
  }
  
  renderUI() {
    // Score and lives
    this.ctx.fillStyle = '#FFFF00';
    this.ctx.font = '16px monospace';
    this.ctx.textAlign = 'left';
    this.ctx.fillText(`SCORE: ${this.score.toString().padStart(6, '0')}`, 10, 30);
    this.ctx.fillText(`LIVES: ${this.lives}`, 10, 50);
    this.ctx.fillText(`LEVEL: ${this.level}`, 10, 70);
    
    if (this.gameState === 'ready') {
      this.ctx.textAlign = 'center';
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.font = '20px Arial';
      this.ctx.fillText('PRESS START TO PLAY', this.width/2, this.height/2 + 50);
    }
  }
  
  updateUI() {
    if (this.scoreElement) {
      this.scoreElement.textContent = this.score.toString().padStart(6, '0');
    }
    if (this.livesElement) {
      this.livesElement.textContent = this.lives.toString();
    }
  }
  
  handleKeyDown(event) {
    // Called by controller
    this.keys[event.code] = true;
    
    if (event.code === 'Space') {
      this.jump();
      event.preventDefault();
    }
  }
  
  handleKeyUp(event) {
    // Called by controller  
    this.keys[event.code] = false;
  }
  
  destroy() {
    // Cleanup
    this.gameState = 'destroyed';
  }
}

export { HonkyPongGame };