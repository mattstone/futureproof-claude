// Lace Invaders - Professional Space Invaders Clone
export class LaceInvadersGame {
  constructor(options) {
    console.log("🎮 Lace Invaders initializing...");
    
    this.canvas = options.canvas;
    this.ctx = this.canvas.getContext('2d');
    this.scoreElement = options.scoreElement;
    this.livesElement = options.livesElement;
    this.levelElement = options.levelElement;
    this.startButton = options.startButton;
    this.gameOverElement = options.gameOverElement;
    this.finalScoreElement = options.finalScoreElement;
    this.restartButton = options.restartButton;
    
    // Game state
    this.gameState = 'menu';
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.frameCounter = 0;
    
    // Input handling
    this.keys = {};
    this.keyPressed = {};
    
    // Player
    this.player = {
      x: this.canvas.width / 2 - 30,
      y: this.canvas.height - 80,
      width: 60,
      height: 40,
      speed: 5,
      canShoot: true,
      shootCooldown: 0,
      animation: 0
    };
    
    // Game objects
    this.invaders = [];
    this.playerLaces = [];
    this.invaderLaces = [];
    this.barriers = [];
    this.particles = [];
    this.ufo = null;
    
    // Invader movement
    this.invaderDirection = 1; // 1 = right, -1 = left
    this.invaderSpeed = 12;
    this.invaderDropDistance = 20;
    this.lastInvaderMoveTime = 0;
    this.invaderMoveInterval = 400; // ms between moves
    
    // Audio stub
    this.audio = {
      play: (sound) => console.log(`🔊 ${sound}`)
    };
    
    this.initializeSprites();
    this.initializeLevel();
    this.setupEventListeners();
    this.gameLoop();
    
    console.log("🎮 Lace Invaders initialized successfully!");
  }
  
  // Helper function for smooth rounded rectangles
  drawRoundedRect(x, y, width, height, radius) {
    this.ctx.beginPath();
    this.ctx.moveTo(x + radius, y);
    this.ctx.lineTo(x + width - radius, y);
    this.ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
    this.ctx.lineTo(x + width, y + height - radius);
    this.ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
    this.ctx.lineTo(x + radius, y + height);
    this.ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
    this.ctx.lineTo(x, y + radius);
    this.ctx.quadraticCurveTo(x, y, x + radius, y);
    this.ctx.closePath();
    this.ctx.fill();
  }

  initializeSprites() {
    this.sprites = {
      // High Quality Player Shoe (Simplified)
      playerShoe: (x, y, animation = 0) => {
        try {
          this.ctx.save();
          
          // Shadow
          this.ctx.fillStyle = 'rgba(0, 0, 0, 0.4)';
          this.ctx.fillRect(x + 3, y + 36, 58, 7);
          
          // Shoe sole
          this.ctx.fillStyle = '#8B4513';
          this.ctx.fillRect(x, y + 28, 60, 12);
          this.ctx.fillStyle = '#654321';
          this.ctx.fillRect(x + 2, y + 30, 56, 8);
          
          // Main shoe body
          this.ctx.fillStyle = '#2E8B57';
          this.ctx.fillRect(x + 4, y + 12, 48, 20);
          this.ctx.fillStyle = '#32CD32';
          this.ctx.fillRect(x + 6, y + 14, 44, 16);
          
          // Toe cap
          this.ctx.fillStyle = '#228B22';
          this.ctx.fillRect(x + 42, y + 8, 16, 18);
          this.ctx.fillStyle = '#32CD32';
          this.ctx.fillRect(x + 44, y + 10, 12, 14);
          
          // Highlights
          this.ctx.fillStyle = '#90EE90';
          this.ctx.fillRect(x + 6, y + 14, 44, 2);
          this.ctx.fillRect(x + 6, y + 14, 2, 16);
          
          // Eyelets
          this.ctx.fillStyle = '#C0C0C0';
          this.ctx.fillRect(x + 12, y + 16, 2, 2);
          this.ctx.fillRect(x + 20, y + 16, 2, 2);
          this.ctx.fillRect(x + 28, y + 16, 2, 2);
          this.ctx.fillRect(x + 36, y + 16, 2, 2);
          
          // Laces
          this.ctx.strokeStyle = '#FFFFFF';
          this.ctx.lineWidth = 2;
          this.ctx.lineCap = 'round';
          this.ctx.beginPath();
          this.ctx.moveTo(x + 13, y + 17);
          this.ctx.lineTo(x + 29, y + 17);
          this.ctx.moveTo(x + 21, y + 17);
          this.ctx.lineTo(x + 37, y + 17);
          this.ctx.stroke();
          
          // Shooting effect
          if (animation > 0) {
            this.ctx.save();
            this.ctx.shadowColor = '#FFFF00';
            this.ctx.shadowBlur = 8;
            this.ctx.fillStyle = '#FFFF00';
            this.ctx.fillRect(x + 52, y + 16, 6, 3);
            this.ctx.restore();
          }
          
          this.ctx.restore();
        } catch(e) {
          console.error('Error rendering player shoe:', e);
          // Fallback simple rectangle
          this.ctx.fillStyle = '#32CD32';
          this.ctx.fillRect(x, y, 60, 40);
        }
      },
      
      // High-Top Sneaker (10 points) - Simplified
      sneakerType1: (x, y, frame = 0) => {
        try {
          this.ctx.save();
          
          const bounce = Math.sin(frame * 0.08) * 2;
          y += bounce;
          
          // Shadow
          this.ctx.fillStyle = 'rgba(0, 0, 0, 0.3)';
          this.ctx.fillRect(x + 1, y + 31, 38, 4);
          
          // Sole
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.fillRect(x - 2, y + 26, 40, 6);
          
          // Main shoe body
          this.ctx.fillStyle = '#FF4500';
          this.ctx.fillRect(x + 2, y + 12, 32, 16);
          
          // High ankle
          this.ctx.fillStyle = '#DC143C';
          this.ctx.fillRect(x + 4, y + 4, 28, 12);
          
          // Highlights
          this.ctx.fillStyle = '#FF7F50';
          this.ctx.fillRect(x + 4, y + 14, 28, 1);
          this.ctx.fillRect(x + 4, y + 14, 1, 12);
          
          // Brand swoosh
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.beginPath();
          this.ctx.moveTo(x + 18, y + 20);
          this.ctx.lineTo(x + 28, y + 18);
          this.ctx.lineTo(x + 26, y + 22);
          this.ctx.lineTo(x + 16, y + 23);
          this.ctx.closePath();
          this.ctx.fill();
          
          // Laces
          this.ctx.strokeStyle = '#FFFFFF';
          this.ctx.lineWidth = 2;
          this.ctx.beginPath();
          this.ctx.moveTo(x + 12, y + 18);
          this.ctx.lineTo(x + 24, y + 18);
          this.ctx.stroke();
          
          // Glowing eyes
          this.ctx.save();
          this.ctx.shadowColor = '#FF0000';
          this.ctx.shadowBlur = 3;
          this.ctx.fillStyle = '#FF0000';
          this.ctx.fillRect(x + 10, y + 6, 3, 3);
          this.ctx.fillRect(x + 22, y + 6, 3, 3);
          this.ctx.restore();
          
          // Angry mouth
          this.ctx.fillStyle = '#000000';
          this.ctx.fillRect(x + 14, y + 9, 8, 2);
          
          this.ctx.restore();
        } catch(e) {
          console.error('Error rendering sneaker type 1:', e);
          // Fallback
          this.ctx.fillStyle = '#FF4500';
          this.ctx.fillRect(x, y, 36, 30);
        }
      },
      
      // Athletic Sneaker (20 points) - Simplified  
      sneakerType2: (x, y, frame = 0) => {
        try {
          this.ctx.save();
          
          const bounce = Math.sin(frame * 0.08) * 2;
          y += bounce;
          
          // Shadow
          this.ctx.fillStyle = 'rgba(0, 0, 0, 0.35)';
          this.ctx.fillRect(x + 1, y + 29, 36, 4);
          
          // Sole
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.fillRect(x - 1, y + 22, 36, 8);
          
          // Air cushion bubbles
          this.ctx.fillStyle = '#87CEEB';
          this.ctx.fillRect(x + 6, y + 25, 4, 2);
          this.ctx.fillRect(x + 14, y + 25, 4, 2);
          this.ctx.fillRect(x + 22, y + 25, 4, 2);
          
          // Main body
          this.ctx.fillStyle = '#4169E1';
          this.ctx.fillRect(x + 2, y + 14, 30, 10);
          
          // Upper
          this.ctx.fillStyle = '#1E90FF';
          this.ctx.fillRect(x + 4, y + 8, 26, 8);
          
          // Mesh sections
          this.ctx.fillStyle = '#B0E0E6';
          this.ctx.fillRect(x + 6, y + 10, 1, 4);
          this.ctx.fillRect(x + 9, y + 10, 1, 4);
          this.ctx.fillRect(x + 12, y + 10, 1, 4);
          this.ctx.fillRect(x + 24, y + 10, 1, 4);
          this.ctx.fillRect(x + 27, y + 10, 1, 4);
          
          // Racing stripes
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.fillRect(x + 8, y + 16, 20, 1);
          this.ctx.fillRect(x + 8, y + 18, 20, 1);
          this.ctx.fillRect(x + 10, y + 20, 16, 1);
          
          // Logo
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.fillRect(x + 15, y + 12, 4, 2);
          this.ctx.fillRect(x + 16, y + 10, 2, 4);
          
          // Eyes
          this.ctx.save();
          this.ctx.shadowColor = '#00BFFF';
          this.ctx.shadowBlur = 4;
          this.ctx.fillStyle = '#00BFFF';
          this.ctx.fillRect(x + 8, y + 6, 3, 2);
          this.ctx.fillRect(x + 22, y + 6, 3, 2);
          this.ctx.restore();
          
          // Mouth
          this.ctx.fillStyle = '#000080';
          this.ctx.fillRect(x + 12, y + 11, 10, 2);
          
          this.ctx.restore();
        } catch(e) {
          console.error('Error rendering sneaker type 2:', e);
          // Fallback
          this.ctx.fillStyle = '#4169E1';
          this.ctx.fillRect(x, y, 34, 30);
        }
      },
      
      // Combat Boot Sneaker (30 points) - Simplified
      sneakerType3: (x, y, frame = 0) => {
        try {
          this.ctx.save();
          
          const bounce = Math.sin(frame * 0.06) * 2.5;
          y += bounce;
          
          // Shadow
          this.ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
          this.ctx.fillRect(x, y + 27, 42, 6);
          
          // Heavy sole
          this.ctx.fillStyle = '#333333';
          this.ctx.fillRect(x - 2, y + 26, 40, 8);
          this.ctx.fillStyle = '#000000';
          this.ctx.fillRect(x - 1, y + 28, 38, 4);
          
          // Boot treads
          this.ctx.fillStyle = '#4A4A4A';
          for (let i = 0; i < 7; i++) {
            this.ctx.fillRect(x + i * 5, y + 28, 2, 2);
            this.ctx.fillRect(x + i * 5, y + 31, 2, 2);
          }
          
          // Boot body
          this.ctx.fillStyle = '#8B008B';
          this.ctx.fillRect(x + 2, y + 10, 32, 18);
          
          // Upper boot
          this.ctx.fillStyle = '#4B0082';
          this.ctx.fillRect(x + 3, y + 2, 30, 12);
          
          // Highlights
          this.ctx.fillStyle = '#9370DB';
          this.ctx.fillRect(x + 4, y + 12, 28, 1);
          this.ctx.fillRect(x + 4, y + 16, 28, 1);
          
          // Metallic buckles
          this.ctx.save();
          this.ctx.shadowColor = '#FFD700';
          this.ctx.shadowBlur = 3;
          this.ctx.fillStyle = '#FFD700';
          this.ctx.fillRect(x + 8, y + 6, 6, 3);
          this.ctx.fillRect(x + 18, y + 6, 6, 3);
          this.ctx.fillStyle = '#B8860B';
          this.ctx.fillRect(x + 9, y + 7, 4, 1);
          this.ctx.fillRect(x + 19, y + 7, 4, 1);
          this.ctx.restore();
          
          // Combat laces
          this.ctx.strokeStyle = '#C0C0C0';
          this.ctx.lineWidth = 2;
          this.ctx.beginPath();
          this.ctx.moveTo(x + 10, y + 14);
          this.ctx.lineTo(x + 24, y + 14);
          this.ctx.moveTo(x + 12, y + 16);
          this.ctx.lineTo(x + 22, y + 16);
          this.ctx.stroke();
          
          // Glowing red eyes
          this.ctx.save();
          this.ctx.shadowColor = '#FF0000';
          this.ctx.shadowBlur = 6;
          this.ctx.fillStyle = '#FF4500';
          this.ctx.fillRect(x + 10, y + 4, 4, 3);
          this.ctx.fillRect(x + 21, y + 4, 4, 3);
          this.ctx.fillStyle = '#FFFF00';
          this.ctx.fillRect(x + 11, y + 5, 2, 1);
          this.ctx.fillRect(x + 22, y + 5, 2, 1);
          this.ctx.restore();
          
          // Fierce mouth
          this.ctx.fillStyle = '#FF0000';
          this.ctx.fillRect(x + 14, y + 7, 8, 3);
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.fillRect(x + 15, y + 8, 1, 2);
          this.ctx.fillRect(x + 17, y + 8, 1, 2);
          this.ctx.fillRect(x + 19, y + 8, 1, 2);
          this.ctx.fillRect(x + 21, y + 8, 1, 2);
          
          this.ctx.restore();
        } catch(e) {
          console.error('Error rendering sneaker type 3:', e);
          // Fallback
          this.ctx.fillStyle = '#8B008B';
          this.ctx.fillRect(x, y, 36, 30);
        }
      },
      
      // High-Tech Projectiles (Simplified)
      playerLace: (x, y, trail = []) => {
        try {
          this.ctx.save();
          
          // Energy trail glow
          this.ctx.shadowColor = '#00FFFF';
          this.ctx.shadowBlur = 6;
          
          // Main lace body
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.fillRect(x, y, 4, 12);
          
          // Plasma tip
          this.ctx.fillStyle = '#FFFF00';
          this.ctx.fillRect(x, y, 4, 3);
          
          // Energy core
          this.ctx.fillStyle = '#00FFFF';
          this.ctx.fillRect(x + 1, y + 1, 2, 10);
          
          // Trailing particles
          for (let i = 0; i < 3; i++) {
            this.ctx.save();
            this.ctx.globalAlpha = 0.3 - i * 0.1;
            this.ctx.fillStyle = '#00FFFF';
            this.ctx.beginPath();
            this.ctx.arc(x + 2, y + 14 + i * 3, 1 - i * 0.2, 0, Math.PI * 2);
            this.ctx.fill();
            this.ctx.restore();
          }
          
          this.ctx.restore();
        } catch(e) {
          console.error('Error rendering player lace:', e);
          // Fallback
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.fillRect(x, y, 4, 12);
        }
      },
      
      invaderLace: (x, y) => {
        try {
          this.ctx.save();
          
          // Demonic energy glow
          this.ctx.shadowColor = '#FF0000';
          this.ctx.shadowBlur = 4;
          
          // Main enemy lace
          this.ctx.fillStyle = '#FF4444';
          this.ctx.fillRect(x, y, 3, 10);
          
          // Destructive tip
          this.ctx.fillStyle = '#FFFF00';
          this.ctx.fillRect(x, y + 8, 3, 2);
          
          // Evil core
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.fillRect(x + 1, y + 2, 1, 6);
          
          // Trailing evil particles
          for (let i = 0; i < 2; i++) {
            this.ctx.save();
            this.ctx.globalAlpha = 0.4 - i * 0.2;
            this.ctx.fillStyle = '#FF0000';
            this.ctx.beginPath();
            this.ctx.arc(x + 1.5, y - 2 - i * 2, 0.8 - i * 0.3, 0, Math.PI * 2);
            this.ctx.fill();
            this.ctx.restore();
          }
          
          this.ctx.restore();
        } catch(e) {
          console.error('Error rendering invader lace:', e);
          // Fallback
          this.ctx.fillStyle = '#FF4444';
          this.ctx.fillRect(x, y, 3, 10);
        }
      },
      
      // Destructible Shield - Large Professional Version
      shield: (x, y, damage = []) => {
        this.ctx.save();
        
        // Draw shield with damage system (66x48 pixels - 3x larger)
        for (let sx = 0; sx < 66; sx++) {
          for (let sy = 0; sy < 48; sy++) {
            const pixelKey = `${sx}-${sy}`;
            if (!damage.includes(pixelKey)) {
              // Shield structure pattern (scaled up 3x)
              if ((sx < 9 || sx > 54) && sy > 36) {
                // Side supports - gradient effect
                const alpha = 0.8 - (Math.abs(sx - 33) / 66) * 0.3;
                this.ctx.fillStyle = `rgba(0, 255, 0, ${alpha})`;
                this.ctx.fillRect(x + sx, y + sy, 1, 1);
              } else if (sy < 36 && sx > 6 && sx < 57) {
                // Main shield dome - gradient effect
                const distance = Math.sqrt(Math.pow(sx - 33, 2) + Math.pow(sy - 18, 2));
                const maxDistance = 30;
                const alpha = Math.max(0.6, 1 - (distance / maxDistance) * 0.4);
                this.ctx.fillStyle = `rgba(0, 255, 0, ${alpha})`;
                this.ctx.fillRect(x + sx, y + sy, 1, 1);
              } else if (sy >= 36 && sx >= 24 && sx <= 39) {
                // Center entrance gap
                continue;
              } else if (sy >= 36) {
                // Lower shield sections
                const alpha = 0.7;
                this.ctx.fillStyle = `rgba(0, 255, 0, ${alpha})`;
                this.ctx.fillRect(x + sx, y + sy, 1, 1);
              }
            }
          }
        }
        
        this.ctx.restore();
      }
    };
  }
  
  initializeLevel() {
    // Create invader formation
    this.invaders = [];
    const startX = 50;
    const startY = 100;
    const spacingX = 60;
    const spacingY = 50;
    
    for (let row = 0; row < 5; row++) {
      for (let col = 0; col < 11; col++) {
        let type = 1;
        if (row === 0) type = 3;
        else if (row <= 2) type = 2;
        
        this.invaders.push({
          x: startX + col * spacingX,
          y: startY + row * spacingY,
          width: 36,
          height: 30,
          type: type,
          points: type === 3 ? 30 : type === 2 ? 20 : 10,
          alive: true,
          shootCooldown: 0
        });
      }
    }
    
    // Create shields (4 shields like classic Space Invaders)
    this.barriers = [];
    const shieldY = this.canvas.height - 250;
    for (let i = 0; i < 4; i++) {
      this.barriers.push({
        x: 120 + i * 165,
        y: shieldY,
        width: 66,
        height: 48,
        damage: [] // Array of damaged pixel coordinates
      });
    }
    
    // Reset game elements
    this.playerLaces = [];
    this.invaderLaces = [];
    this.particles = [];
  }
  
  setupEventListeners() {
    this.keyDownHandler = (e) => {
      if (['ArrowLeft', 'ArrowRight', 'KeyA', 'KeyD', 'Space', 'KeyP'].includes(e.code)) {
        e.preventDefault();
      }
      
      this.keys[e.code] = true;
      
      if (!this.keyPressed[e.code]) {
        this.keyPressed[e.code] = true;
        
        if (e.code === 'Space') {
          if (this.gameState === 'menu') {
            this.startGame();
          } else if (this.gameState === 'playing') {
            this.shootPlayerLace();
          } else if (this.gameState === 'gameOver') {
            this.restartGame();
          }
        } else if (e.code === 'KeyP') {
          this.togglePause();
        }
      }
    };
    
    this.keyUpHandler = (e) => {
      this.keys[e.code] = false;
      this.keyPressed[e.code] = false;
    };
    
    document.addEventListener('keydown', this.keyDownHandler);
    document.addEventListener('keyup', this.keyUpHandler);
  }
  
  startGame() {
    this.gameState = 'playing';
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.initializeLevel();
    this.updateUI();
  }
  
  restartGame() {
    this.gameState = 'playing';
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.particles = [];
    this.initializeLevel();
    this.updateUI();
    
    // Hide game over screen
    if (this.gameOverElement) {
      this.gameOverElement.classList.add('game-over-hidden');
    }
  }
  
  togglePause() {
    if (this.gameState === 'playing') {
      this.gameState = 'paused';
    } else if (this.gameState === 'paused') {
      this.gameState = 'playing';
    }
  }
  
  shootPlayerLace() {
    if (this.player.canShoot && this.player.shootCooldown <= 0) {
      this.playerLaces.push({
        x: this.player.x + this.player.width / 2 - 2,
        y: this.player.y - 5,
        width: 4,
        height: 12,
        speed: 12,
        trail: []
      });
      
      this.player.canShoot = false;
      this.player.shootCooldown = 15;
      this.player.animation = 10;
      
      this.audio.play('shoot');
    }
  }
  
  update() {
    if (this.gameState !== 'playing') return;
    
    this.frameCounter++;
    
    // Update player
    if (this.keys['ArrowLeft'] || this.keys['KeyA']) {
      this.player.x = Math.max(0, this.player.x - this.player.speed);
    }
    if (this.keys['ArrowRight'] || this.keys['KeyD']) {
      this.player.x = Math.min(this.canvas.width - this.player.width, this.player.x + this.player.speed);
    }
    
    if (this.player.shootCooldown > 0) {
      this.player.shootCooldown--;
    }
    if (this.player.animation > 0) {
      this.player.animation--;
    }
    
    // Update invaders - authentic Space Invaders movement
    this.updateInvaders();
    
    // Update invader shooting
    this.updateInvaderShooting();
    
    // Update projectiles
    for (let i = this.playerLaces.length - 1; i >= 0; i--) {
      let lace = this.playerLaces[i];
      lace.y -= lace.speed;
      
      if (lace.y < -20) {
        this.playerLaces.splice(i, 1);
        this.player.canShoot = true;
      }
    }
    
    // Update invader projectiles
    for (let i = this.invaderLaces.length - 1; i >= 0; i--) {
      let lace = this.invaderLaces[i];
      lace.y += lace.speed;
      
      if (lace.y > this.canvas.height + 20) {
        this.invaderLaces.splice(i, 1);
      }
    }
    
    // Update particles
    for (let i = this.particles.length - 1; i >= 0; i--) {
      let particle = this.particles[i];
      particle.x += particle.vx;
      particle.y += particle.vy;
      particle.life--;
      
      if (particle.life <= 0) {
        this.particles.splice(i, 1);
      }
    }
    
    // Check collisions
    this.checkCollisions();
    
    // Check level completion
    this.checkLevelCompletion();
  }
  
  updateInvaders() {
    // Authentic Space Invaders movement pattern
    const now = Date.now();
    
    if (now - this.lastInvaderMoveTime > this.invaderMoveInterval) {
      let shouldDrop = false;
      
      // Check if any invader hits the edge
      for (let invader of this.invaders) {
        if (!invader.alive) continue;
        
        if (this.invaderDirection === 1 && invader.x + invader.width >= this.canvas.width - 10) {
          shouldDrop = true;
          break;
        }
        if (this.invaderDirection === -1 && invader.x <= 10) {
          shouldDrop = true;
          break;
        }
      }
      
      // Move all invaders
      for (let invader of this.invaders) {
        if (!invader.alive) continue;
        
        if (shouldDrop) {
          // Drop down and reverse direction
          invader.y += this.invaderDropDistance;
        } else {
          // Move horizontally
          invader.x += this.invaderDirection * this.invaderSpeed;
        }
      }
      
      // Reverse direction if we dropped
      if (shouldDrop) {
        this.invaderDirection *= -1;
        // Speed up slightly each time they drop (authentic Space Invaders)
        this.invaderMoveInterval = Math.max(200, this.invaderMoveInterval - 20);
      }
      
      this.lastInvaderMoveTime = now;
    }
  }
  
  updateInvaderShooting() {
    // Authentic Space Invaders shooting - random invaders shoot occasionally
    if (Math.random() < 0.008) { // Shooting frequency
      const aliveInvaders = this.invaders.filter(inv => inv.alive);
      if (aliveInvaders.length > 0) {
        // Pick a random alive invader to shoot
        const shooter = aliveInvaders[Math.floor(Math.random() * aliveInvaders.length)];
        
        // Prioritize invaders in the front (bottom rows)
        const bottomInvaders = aliveInvaders.filter(inv => {
          return !aliveInvaders.some(other => 
            other.x === inv.x && other.y > inv.y && other.alive
          );
        });
        
        const finalShooter = bottomInvaders.length > 0 ? 
          bottomInvaders[Math.floor(Math.random() * bottomInvaders.length)] : 
          shooter;
        
        this.invaderLaces.push({
          x: finalShooter.x + finalShooter.width / 2 - 1.5,
          y: finalShooter.y + finalShooter.height,
          width: 3,
          height: 10,
          speed: 4
        });
        
        this.audio.play('invaderShoot');
      }
    }
  }
  
  checkCollisions() {
    // Player laces vs invaders
    for (let i = this.playerLaces.length - 1; i >= 0; i--) {
      let lace = this.playerLaces[i];
      
      for (let invader of this.invaders) {
        if (!invader.alive) continue;
        
        if (this.collision(lace, invader)) {
          invader.alive = false;
          this.score += invader.points;
          this.playerLaces.splice(i, 1);
          this.player.canShoot = true;
          this.audio.play('hit');
          this.updateUI();
          break;
        }
      }
    }
    
    // Player laces vs shields
    for (let i = this.playerLaces.length - 1; i >= 0; i--) {
      let lace = this.playerLaces[i];
      
      for (let shield of this.barriers) {
        if (this.collision(lace, shield)) {
          // Add damage to shield
          this.damageShield(shield, lace.x - shield.x, lace.y - shield.y);
          this.playerLaces.splice(i, 1);
          this.player.canShoot = true;
          break;
        }
      }
    }
    
    // Invader laces vs player
    for (let i = this.invaderLaces.length - 1; i >= 0; i--) {
      let lace = this.invaderLaces[i];
      
      if (this.collision(lace, this.player)) {
        this.invaderLaces.splice(i, 1);
        this.playerDeath();
        break;
      }
    }
    
    // Invader laces vs shields
    for (let i = this.invaderLaces.length - 1; i >= 0; i--) {
      let lace = this.invaderLaces[i];
      
      for (let shield of this.barriers) {
        if (this.collision(lace, shield)) {
          // Add damage to shield from enemy fire
          this.damageShield(shield, lace.x - shield.x, lace.y - shield.y);
          this.invaderLaces.splice(i, 1);
          break;
        }
      }
    }
    
    // Invaders vs shields - eat through them as they pass
    for (let invader of this.invaders) {
      if (!invader.alive) continue;
      
      for (let shield of this.barriers) {
        if (this.collision(invader, shield)) {
          // Invaders eat through shields gradually
          this.eatThroughShield(shield, invader.x - shield.x, invader.y - shield.y, invader.width, invader.height);
        }
      }
    }
    
    // Invaders vs player - game over collision
    for (let invader of this.invaders) {
      if (!invader.alive) continue;
      
      if (this.collision(invader, this.player)) {
        this.playerDeath();
        break;
      }
    }
    
    // Check if invaders reached bottom (also triggers death)
    for (let invader of this.invaders) {
      if (!invader.alive) continue;
      
      if (invader.y + invader.height >= this.player.y) {
        this.playerDeath();
        break;
      }
    }
  }
  
  damageShield(shield, hitX, hitY) {
    // Add damage in a larger area for the bigger shields
    for (let dx = -6; dx <= 6; dx++) {
      for (let dy = -6; dy <= 6; dy++) {
        const px = Math.floor(hitX) + dx;
        const py = Math.floor(hitY) + dy;
        
        if (px >= 0 && px < 66 && py >= 0 && py < 48) {
          const pixelKey = `${px}-${py}`;
          if (!shield.damage.includes(pixelKey)) {
            shield.damage.push(pixelKey);
          }
        }
      }
    }
  }
  
  eatThroughShield(shield, hitX, hitY, width, height) {
    // Invaders eat through shields more extensively as they pass
    for (let dx = 0; dx < width + 4; dx++) {
      for (let dy = 0; dy < height + 4; dy++) {
        const px = Math.floor(hitX) + dx - 2;
        const py = Math.floor(hitY) + dy - 2;
        
        if (px >= 0 && px < 66 && py >= 0 && py < 48) {
          const pixelKey = `${px}-${py}`;
          if (!shield.damage.includes(pixelKey)) {
            shield.damage.push(pixelKey);
          }
        }
      }
    }
  }
  
  playerDeath() {
    this.lives--;
    this.updateUI();
    this.audio.play('death');
    
    // Create explosion particles
    this.createExplosion(this.player.x + this.player.width / 2, this.player.y + this.player.height / 2);
    
    if (this.lives <= 0) {
      this.gameState = 'gameOver';
      if (this.gameOverElement) {
        this.gameOverElement.classList.remove('game-over-hidden');
      }
      if (this.finalScoreElement) {
        this.finalScoreElement.textContent = this.score.toString().padStart(6, '0');
      }
    } else {
      // Reset player position and clear projectiles
      this.player.x = this.canvas.width / 2 - 30;
      this.playerLaces = [];
      this.invaderLaces = [];
      this.player.canShoot = true;
    }
  }
  
  checkLevelCompletion() {
    // Count remaining alive invaders
    const aliveInvaders = this.invaders.filter(inv => inv.alive).length;
    
    if (aliveInvaders === 0) {
      // Level completed!
      this.level++;
      this.audio.play('levelComplete');
      
      // Show level completion message briefly
      this.gameState = 'levelComplete';
      
      // Advance to next level after 2 seconds
      setTimeout(() => {
        this.startNextLevel();
      }, 2000);
    }
  }
  
  startNextLevel() {
    // Reset invader movement speed for new level
    this.invaderMoveInterval = Math.max(200, 800 - (this.level - 1) * 100);
    this.invaderSpeed = Math.min(15, 12 + (this.level - 1) * 1);
    
    // Initialize new level
    this.initializeLevel();
    this.gameState = 'playing';
    this.updateUI();
  }
  
  createExplosion(x, y) {
    // Create explosion particles
    for (let i = 0; i < 20; i++) {
      this.particles.push({
        x: x + (Math.random() - 0.5) * 20,
        y: y + (Math.random() - 0.5) * 20,
        vx: (Math.random() - 0.5) * 8,
        vy: (Math.random() - 0.5) * 8,
        life: 60,
        maxLife: 60,
        color: Math.random() > 0.5 ? '#FF4500' : '#FFFF00'
      });
    }
  }
  
  collision(obj1, obj2) {
    return obj1.x < obj2.x + obj2.width &&
           obj1.x + obj1.width > obj2.x &&
           obj1.y < obj2.y + obj2.height &&
           obj1.y + obj1.height > obj2.y;
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
  }
  
  render() {
    // Clear canvas
    this.ctx.fillStyle = '#000000';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    
    if (this.gameState === 'playing') {
      this.renderGame();
    } else if (this.gameState === 'menu') {
      this.renderMenu();
    } else if (this.gameState === 'paused') {
      this.renderGame();
      this.renderPause();
    } else if (this.gameState === 'gameOver') {
      this.renderGame();
      this.renderGameOver();
    } else if (this.gameState === 'levelComplete') {
      this.renderGame();
      this.renderLevelComplete();
    }
  }
  
  renderGame() {
    // Draw shields first (so they appear behind everything)
    for (let shield of this.barriers) {
      this.sprites.shield(shield.x, shield.y, shield.damage);
    }
    
    // Draw invaders
    for (let invader of this.invaders) {
      if (!invader.alive) continue;
      
      if (invader.type === 1) {
        this.sprites.sneakerType1(invader.x, invader.y, this.frameCounter);
      } else if (invader.type === 2) {
        this.sprites.sneakerType2(invader.x, invader.y, this.frameCounter);
      } else {
        this.sprites.sneakerType3(invader.x, invader.y, this.frameCounter);
      }
    }
    
    // Draw player
    this.sprites.playerShoe(this.player.x, this.player.y, this.player.animation);
    
    // Draw projectiles
    for (let lace of this.playerLaces) {
      this.sprites.playerLace(lace.x, lace.y, lace.trail);
    }
    
    // Draw invader projectiles
    for (let lace of this.invaderLaces) {
      this.sprites.invaderLace(lace.x, lace.y);
    }
    
    // Draw particles (explosions)
    for (let particle of this.particles) {
      const alpha = particle.life / particle.maxLife;
      this.ctx.save();
      this.ctx.globalAlpha = alpha;
      this.ctx.fillStyle = particle.color;
      this.ctx.fillRect(particle.x, particle.y, 3, 3);
      this.ctx.restore();
    }
  }
  
  renderMenu() {
    // Always set text alignment properly
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    
    // Professional title
    this.ctx.save();
    this.ctx.shadowColor = '#00FF00';
    this.ctx.shadowBlur = 20;
    this.ctx.fillStyle = '#00FF00';
    this.ctx.font = 'bold 48px monospace';
    this.ctx.fillText('LACE INVADERS', this.canvas.width / 2, this.canvas.height / 2 - 120);
    this.ctx.restore();
    
    // Subtitle
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = '20px monospace';
    this.ctx.fillText('🌍 Professional Sneaker Defense System 🌍', this.canvas.width / 2, this.canvas.height / 2 - 80);
    
    // Start prompt
    const pulse = Math.sin(this.frameCounter * 0.1) * 0.3 + 0.7;
    this.ctx.save();
    this.ctx.globalAlpha = pulse;
    this.ctx.fillStyle = '#FFFF00';
    this.ctx.font = 'bold 24px monospace';
    this.ctx.fillText('▶ PRESS SPACE TO DEFEND EARTH ◀', this.canvas.width / 2, this.canvas.height / 2 - 30);
    this.ctx.restore();
    
    // Controls
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = '16px monospace';
    this.ctx.fillText('🎮 Arrow Keys / WASD: Move Your Shoe Cannon', this.canvas.width / 2, this.canvas.height / 2 + 20);
    this.ctx.fillText('👟 SPACE: Fire Professional Laces', this.canvas.width / 2, this.canvas.height / 2 + 45);
    
    // Enemy samples with better spacing
    this.ctx.fillStyle = '#FFD700';
    this.ctx.font = 'bold 18px monospace';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('🎯 THREAT ASSESSMENT:', this.canvas.width / 2, this.canvas.height / 2 + 100);
    
    // Left enemy - High-Top
    try {
      this.sprites.sneakerType1(this.canvas.width / 2 - 180, this.canvas.height / 2 + 130, this.frameCounter);
      this.ctx.fillStyle = '#FF4500';
      this.ctx.font = '14px monospace';
      this.ctx.fillText('HIGH-TOP = 10pts', this.canvas.width / 2 - 162, this.canvas.height / 2 + 175);
    } catch(e) {
      console.error('Error rendering sneaker type 1:', e);
    }
    
    // Center enemy - Athletic  
    try {
      this.sprites.sneakerType2(this.canvas.width / 2 - 18, this.canvas.height / 2 + 130, this.frameCounter);
      this.ctx.fillStyle = '#4169E1';
      this.ctx.fillText('ATHLETIC = 20pts', this.canvas.width / 2, this.canvas.height / 2 + 175);
    } catch(e) {
      console.error('Error rendering sneaker type 2:', e);
    }
    
    // Right enemy - Boot
    try {
      this.sprites.sneakerType3(this.canvas.width / 2 + 144, this.canvas.height / 2 + 130, this.frameCounter);
      this.ctx.fillStyle = '#8B008B';
      this.ctx.fillText('BOOT = 30pts', this.canvas.width / 2 + 162, this.canvas.height / 2 + 175);
    } catch(e) {
      console.error('Error rendering sneaker type 3:', e);
    }
  }
  
  renderPause() {
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    
    this.ctx.fillStyle = '#FFFF00';
    this.ctx.font = 'bold 48px monospace';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('PAUSED', this.canvas.width / 2, this.canvas.height / 2);
    
    this.ctx.font = '24px monospace';
    this.ctx.fillText('Press P to Resume', this.canvas.width / 2, this.canvas.height / 2 + 50);
  }
  
  renderGameOver() {
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.8)';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    
    this.ctx.save();
    this.ctx.shadowColor = '#FF0000';
    this.ctx.shadowBlur = 10;
    this.ctx.fillStyle = '#FF0000';
    this.ctx.font = 'bold 48px monospace';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('GAME OVER', this.canvas.width / 2, this.canvas.height / 2 - 60);
    this.ctx.restore();
    
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = '24px monospace';
    this.ctx.fillText(`Final Score: ${this.score.toString().padStart(6, '0')}`, this.canvas.width / 2, this.canvas.height / 2);
    
    const pulse = Math.sin(this.frameCounter * 0.1) * 0.3 + 0.7;
    this.ctx.save();
    this.ctx.globalAlpha = pulse;
    this.ctx.fillStyle = '#FFFF00';
    this.ctx.font = 'bold 20px monospace';
    this.ctx.fillText('Press SPACE to Try Again', this.canvas.width / 2, this.canvas.height / 2 + 60);
    this.ctx.restore();
  }
  
  renderLevelComplete() {
    this.ctx.fillStyle = 'rgba(0, 255, 0, 0.1)';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    
    this.ctx.save();
    this.ctx.shadowColor = '#00FF00';
    this.ctx.shadowBlur = 15;
    this.ctx.fillStyle = '#00FF00';
    this.ctx.font = 'bold 48px monospace';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('LEVEL CLEARED!', this.canvas.width / 2, this.canvas.height / 2 - 60);
    this.ctx.restore();
    
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = '32px monospace';
    this.ctx.textAlign = 'center';
    this.ctx.fillText(`Level ${this.level - 1} Complete!`, this.canvas.width / 2, this.canvas.height / 2 - 10);
    this.ctx.fillText(`Score: ${this.score.toString().padStart(6, '0')}`, this.canvas.width / 2, this.canvas.height / 2 + 30);
    
    const pulse = Math.sin(this.frameCounter * 0.15) * 0.3 + 0.7;
    this.ctx.save();
    this.ctx.globalAlpha = pulse;
    this.ctx.fillStyle = '#FFFF00';
    this.ctx.font = 'bold 24px monospace';
    this.ctx.fillText(`▶ Advancing to Level ${this.level} ◀`, this.canvas.width / 2, this.canvas.height / 2 + 80);
    this.ctx.restore();
  }
  
  gameLoop() {
    try {
      this.update();
      this.render();
    } catch (error) {
      console.error("Game loop error:", error);
    }
    requestAnimationFrame(() => this.gameLoop());
  }
  
  destroy() {
    if (this.keyDownHandler) {
      document.removeEventListener('keydown', this.keyDownHandler);
    }
    if (this.keyUpHandler) {
      document.removeEventListener('keyup', this.keyUpHandler);
    }
    console.log("🎮 Lace Invaders destroyed");
  }
}