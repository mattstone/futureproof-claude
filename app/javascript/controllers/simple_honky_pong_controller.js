import { Controller } from "@hotwired/stimulus"

// Simple Donkey Kong Clone - Fresh Start
export default class extends Controller {
  static targets = ["canvas"]

  connect() {
    console.log('🎮 SIMPLE Honky Pong Controller Connected');
    this.canvas = this.canvasTarget;
    this.ctx = this.canvas.getContext('2d');
    this.canvas.width = 900;
    this.canvas.height = 700;
    
    this.initGame();
    this.setupControls();
    this.gameLoop();
  }

  initGame() {
    // Simple game state
    this.gameRunning = true;
    
    // Player (Mario)
    this.player = {
      x: 50,
      y: 620,
      width: 16,
      height: 24,
      vx: 0,
      vy: 0,
      speed: 2,
      onGround: true,
      onLadder: false
    };

    // Simple platforms based on GROK pseudocode
    this.platforms = [
      // Bottom platform (ground) - flat
      { x: 20, y: 640, width: 860, height: 20, slope: 0, color: '#F24A8D' },
      
      // Second girder - sloped up from left to right  
      { x: 120, y: 540, width: 700, height: 20, slope: -0.02, color: '#F24A8D' },
      
      // Third girder - sloped down from left to right
      { x: 20, y: 440, width: 700, height: 20, slope: 0.02, color: '#F24A8D' },
      
      // Fourth girder - sloped up from left to right
      { x: 120, y: 340, width: 700, height: 20, slope: -0.02, color: '#F24A8D' },
      
      // Fifth girder - sloped down from left to right  
      { x: 20, y: 240, width: 700, height: 20, slope: 0.02, color: '#F24A8D' },
      
      // Top platform (DK's platform) - flat
      { x: 250, y: 140, width: 450, height: 20, slope: 0, color: '#FF0000' }
    ];

    // Simple ladders
    this.ladders = [
      { x: 750, y: 540, width: 16, height: 100 }, // Ground to level 2
      { x: 80, y: 440, width: 16, height: 100 },  // Level 2 to 3
      { x: 750, y: 340, width: 16, height: 100 }, // Level 3 to 4
      { x: 80, y: 240, width: 16, height: 100 },  // Level 4 to 5
      { x: 400, y: 140, width: 16, height: 100 }  // Level 5 to top
    ];

    // Simple Donkey Kong
    this.donkeyKong = { x: 300, y: 110, width: 40, height: 30 };
    
    // Simple Princess
    this.princess = { x: 600, y: 110, width: 16, height: 24 };

    console.log('✅ Simple game initialized with', this.platforms.length, 'platforms');
  }

  setupControls() {
    this.keys = {};
    
    document.addEventListener('keydown', (e) => {
      this.keys[e.code] = true;
    });
    
    document.addEventListener('keyup', (e) => {
      this.keys[e.code] = false;
    });
  }

  update() {
    if (!this.gameRunning) return;

    // Player movement
    this.player.vx = 0;
    
    if (this.keys['ArrowLeft']) {
      this.player.vx = -this.player.speed;
    }
    if (this.keys['ArrowRight']) {
      this.player.vx = this.player.speed;
    }
    
    // Check ladder climbing
    if (this.keys['ArrowUp']) {
      const nearbyLadder = this.checkLadderCollision();
      if (nearbyLadder) {
        this.player.onLadder = true;
        this.player.vy = -2; // Climb up
        this.player.x = nearbyLadder.x; // Snap to ladder
      }
    }
    
    if (this.keys['ArrowDown'] && this.player.onLadder) {
      this.player.vy = 2; // Climb down
    }
    
    // Apply movement
    this.player.x += this.player.vx;
    this.player.y += this.player.vy;
    
    // Gravity (when not on ladder)
    if (!this.player.onLadder) {
      this.player.vy += 0.5; // Gravity
    }
    
    // Platform collision
    this.checkPlatformCollision();
    
    // Boundaries
    this.player.x = Math.max(0, Math.min(this.canvas.width - this.player.width, this.player.x));
  }

  checkPlatformCollision() {
    this.player.onGround = false;
    
    for (let platform of this.platforms) {
      // Calculate platform Y at player's X position (accounting for slope)
      const relativeX = this.player.x - platform.x;
      const platformY = platform.y + (relativeX * platform.slope);
      
      // Check if player is on platform
      if (this.player.x + this.player.width > platform.x &&
          this.player.x < platform.x + platform.width &&
          this.player.y + this.player.height >= platformY &&
          this.player.y + this.player.height <= platformY + platform.height + 10) {
        
        this.player.y = platformY - this.player.height;
        this.player.vy = 0;
        this.player.onGround = true;
        this.player.onLadder = false;
        break;
      }
    }
  }

  checkLadderCollision() {
    for (let ladder of this.ladders) {
      if (Math.abs(this.player.x - ladder.x) < 20 &&
          this.player.y + this.player.height >= ladder.y &&
          this.player.y <= ladder.y + ladder.height) {
        return ladder;
      }
    }
    return null;
  }

  render() {
    // Clear canvas
    this.ctx.fillStyle = '#000000';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    
    // Draw platforms
    for (let platform of this.platforms) {
      this.ctx.fillStyle = platform.color;
      
      if (platform.slope === 0) {
        // Flat platform
        this.ctx.fillRect(platform.x, platform.y, platform.width, platform.height);
      } else {
        // Sloped platform
        const slopeOffset = platform.slope * platform.width;
        this.ctx.beginPath();
        this.ctx.moveTo(platform.x, platform.y);
        this.ctx.lineTo(platform.x + platform.width, platform.y + slopeOffset);
        this.ctx.lineTo(platform.x + platform.width, platform.y + slopeOffset + platform.height);
        this.ctx.lineTo(platform.x, platform.y + platform.height);
        this.ctx.closePath();
        this.ctx.fill();
      }
    }
    
    // Draw ladders
    this.ctx.fillStyle = '#FFFF00';
    for (let ladder of this.ladders) {
      this.ctx.fillRect(ladder.x, ladder.y, ladder.width, ladder.height);
    }
    
    // Draw player (Mario)
    this.ctx.fillStyle = '#FF0000';
    this.ctx.fillRect(this.player.x, this.player.y, this.player.width, this.player.height);
    
    // Draw Donkey Kong
    this.ctx.fillStyle = '#8B4513';
    this.ctx.fillRect(this.donkeyKong.x, this.donkeyKong.y, this.donkeyKong.width, this.donkeyKong.height);
    
    // Draw Princess
    this.ctx.fillStyle = '#FFB6C1';
    this.ctx.fillRect(this.princess.x, this.princess.y, this.princess.width, this.princess.height);
    
    // Debug info
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = '12px Arial';
    this.ctx.fillText(`Mario: (${Math.round(this.player.x)}, ${Math.round(this.player.y)})`, 10, 20);
    this.ctx.fillText(`On Ground: ${this.player.onGround}`, 10, 35);
    this.ctx.fillText(`On Ladder: ${this.player.onLadder}`, 10, 50);
  }

  gameLoop() {
    this.update();
    this.render();
    requestAnimationFrame(() => this.gameLoop());
  }
}