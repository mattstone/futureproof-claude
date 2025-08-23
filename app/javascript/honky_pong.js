// Honky Pong Game - Professional CSP-Compliant Donkey Kong Clone
import { AudioManager } from "audio_manager"

export class HonkyPongGame {
  constructor(options = {}) {
    // Professional dependency injection
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
    this.performanceIndicator = options.performanceIndicator;
    
    if (!this.canvas) {
      throw new Error('Game canvas not found!');
    }
    
    this.ctx = this.canvas.getContext('2d');
    this.gameState = 'menu'; // menu, playing, paused, gameOver
    
    // Professional sprite system (inline for better compatibility)
    this.initializeSprites();
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.bonus = 5000;
    this.bonusTimer = 0;
    this.frameCounter = 0;
    
    // Player (Mario/Jumpman)
    this.player = {
      x: 100,
      y: 620,
      width: 16,
      height: 24,
      vx: 0,
      vy: 0,
      onGround: true,
      onLadder: false,
      climbingLadder: false,
      speed: 1.8,
      jumpPower: 0, // No vertical jumping
      jumpDistance: 32, // Horizontal jump distance
      isJumping: false,
      jumpTimer: 0,
      jumpDuration: 20, // frames for jump animation
      direction: 1, // 1 for right, -1 for left
      hasHammer: false,
      hammerTimer: 0,
      walkAnimation: 0,
      climbAnimation: 0
    };
    
    // AUTHENTIC DONKEY KONG PLATFORM GENERATION - MUST COME FIRST
    this.platforms = this.generateDonkeyKongPlatforms();
    
    // Generate ladders dynamically based on platform positions
    this.ladders = this.generateLadders();
    
    // Generate hammer positions dynamically on middle platforms
    this.hammers = this.generateHammers();
    
    // Honky Kong (Donkey Kong) - on top platform
    this.honkyKong = {
      x: 270,  // Left side of top platform (x=250 + 20 margin)
      y: 160,  // On top of platform (platform y: 200 - kong height: 40 = y: 160)
      width: 48,
      height: 40,
      throwTimer: 0,
      throwRate: 90,
      animation: 0,
      beating: false,
      beatTimer: 0
    };
    
    // Princess (Pauline) - right side of top platform
    this.princess = {
      x: 600,  // Right side of top platform  
      y: 176,  // On top of platform 
      width: 16,
      height: 24,
      animation: 0,
      helpTimer: 0
    };
    
    // Strategic broken ladders for challenge
    this.brokenLadders = [];
    
    // Enhanced barrel system
    this.barrels = [];
    this.barrelSpawnTimer = 0;
    this.barrelSpawnRate = 300; // Slower spawning for testing (5 seconds)
    
    // Fireballs with better AI
    this.fireballs = [];
    this.fireballSpawnTimer = 0;
    
    // Oil drum
    this.oilDrum = { x: 40, y: 620, width: 24, height: 24, fire: 0 };
    
    // Controls with debouncing
    this.keys = {};
    this.keyPressed = {};
    
    // Professional sound system integration
    this.sounds = {
      walk: () => this.audioManager.playSound("walk"),
      jump: () => this.audioManager.playSound("jump"), 
      barrel: () => this.audioManager.playSound("barrel"),
      hammer: () => this.audioManager.playSound("hammer"),
      death: () => this.audioManager.playSound("death"),
      levelComplete: () => this.audioManager.playSound("levelComplete"),
      climb: () => this.audioManager.playSound("climb"),
      coin: () => this.audioManager.playSound("coin"),
      powerUp: () => this.audioManager.playSound("powerUp")
    };
    
    // Professional particle system
    this.particles = [];
    this.maxParticles = 50;
    
    // Professional audio system
    this.audioManager = new AudioManager();
    this.lastFrameTime = performance.now();
    
    this.init();
  }
  
  // Professional inline sprite system for better compatibility
  initializeSprites() {
    // Simple sprite drawing functions
    this.sprites = {
      mario: (x, y, state = 'right') => {
        const s = 1; // scale factor
        
        // Hat
        this.ctx.fillStyle = '#CC0000';
        this.ctx.fillRect(x + 2*s, y, 12*s, 6*s);
        
        // Face
        this.ctx.fillStyle = '#FFE4B5';
        this.ctx.fillRect(x + 3*s, y + 6*s, 10*s, 8*s);
        
        // Eyes
        this.ctx.fillStyle = '#000000';
        this.ctx.fillRect(x + 5*s, y + 8*s, 2*s, 2*s);
        this.ctx.fillRect(x + 9*s, y + 8*s, 2*s, 2*s);
        
        // Mustache
        this.ctx.fillStyle = '#8B4513';
        this.ctx.fillRect(x + 6*s, y + 11*s, 4*s, 2*s);
        
        // Overalls color based on state
        this.ctx.fillStyle = state === 'hammer' ? '#FFD700' : '#0066FF';
        this.ctx.fillRect(x + 1*s, y + 14*s, 14*s, 10*s);
        
        // Overalls straps
        this.ctx.fillStyle = state === 'hammer' ? '#B8860B' : '#004499';
        this.ctx.fillRect(x + 4*s, y + 14*s, 2*s, 4*s);
        this.ctx.fillRect(x + 10*s, y + 14*s, 2*s, 4*s);
        
        // Arms
        this.ctx.fillStyle = '#FFE4B5';
        if (state === 'climb') {
          // Arms up for climbing
          this.ctx.fillRect(x + 1*s, y + 12*s, 3*s, 8*s);
          this.ctx.fillRect(x + 12*s, y + 12*s, 3*s, 8*s);
        } else {
          this.ctx.fillRect(x, y + 16*s, 3*s, 6*s);
          this.ctx.fillRect(x + 13*s, y + 16*s, 3*s, 6*s);
        }
        
        // Shoes
        this.ctx.fillStyle = '#8B4513';
        this.ctx.fillRect(x + 2*s, y + 22*s, 5*s, 2*s);
        this.ctx.fillRect(x + 9*s, y + 22*s, 5*s, 2*s);
        
        // Hammer if holding one
        if (state === 'hammer') {
          this.ctx.fillStyle = '#8B4513'; // Handle
          this.ctx.fillRect(x + 16*s, y + 8*s, 2*s, 12*s);
          this.ctx.fillStyle = '#666666'; // Head
          this.ctx.fillRect(x + 14*s, y + 6*s, 6*s, 6*s);
          this.ctx.fillStyle = '#FFFF00'; // Glow
          this.ctx.fillRect(x + 13*s, y + 5*s, 8*s, 1*s);
        }
      },
      
      donkeyKong: (x, y, state = 'normal') => {
        const s = 1;
        
        // Body
        this.ctx.fillStyle = '#8B4513';
        this.ctx.fillRect(x + 8*s, y + 15*s, 32*s, 25*s);
        
        // Chest
        this.ctx.fillStyle = '#DEB887';
        this.ctx.fillRect(x + 12*s, y + 20*s, 24*s, 15*s);
        
        // Head
        this.ctx.fillStyle = '#DEB887';
        this.ctx.fillRect(x + 10*s, y + 5*s, 28*s, 20*s);
        
        // Hair
        this.ctx.fillStyle = '#8B4513';
        this.ctx.fillRect(x + 12*s, y, 24*s, 8*s);
        
        // Eyes
        this.ctx.fillStyle = '#FFFFFF';
        this.ctx.fillRect(x + 16*s, y + 12*s, 6*s, 4*s);
        this.ctx.fillRect(x + 26*s, y + 12*s, 6*s, 4*s);
        
        // Eye pupils (red when angry)
        this.ctx.fillStyle = state === 'beating' ? '#FF0000' : '#000000';
        this.ctx.fillRect(x + 18*s, y + 13*s, 2*s, 2*s);
        this.ctx.fillRect(x + 28*s, y + 13*s, 2*s, 2*s);
        
        // Mouth (open when beating/throwing)
        if (state === 'beating' || state === 'throwing') {
          this.ctx.fillStyle = '#FF0000';
          this.ctx.fillRect(x + 20*s, y + 22*s, 8*s, 4*s);
        }
        
        // Nostrils
        this.ctx.fillStyle = '#000000';
        this.ctx.fillRect(x + 22*s, y + 18*s, 2*s, 2*s);
        this.ctx.fillRect(x + 26*s, y + 18*s, 2*s, 2*s);
        
        // Arms (extended when throwing)
        this.ctx.fillStyle = '#8B4513';
        if (state === 'throwing') {
          this.ctx.fillRect(x + 40*s, y + 15*s, 12*s, 8*s);
          // Extended hand
          this.ctx.fillStyle = '#DEB887';
          this.ctx.fillRect(x + 48*s, y + 18*s, 4*s, 6*s);
        } else {
          this.ctx.fillRect(x, y + 20*s, 12*s, 15*s);
          this.ctx.fillRect(x + 36*s, y + 20*s, 12*s, 15*s);
          // Hands
          this.ctx.fillStyle = '#DEB887';
          this.ctx.fillRect(x + 2*s, y + 32*s, 8*s, 8*s);
          this.ctx.fillRect(x + 38*s, y + 32*s, 8*s, 8*s);
        }
        
        // Chest beating effect
        if (state === 'beating') {
          this.ctx.fillStyle = '#FFAA00';
          this.ctx.fillRect(x + 15*s, y + 25*s, 6*s, 6*s);
          this.ctx.fillRect(x + 27*s, y + 25*s, 6*s, 6*s);
        }
        
        // Legs
        this.ctx.fillStyle = '#8B4513';
        this.ctx.fillRect(x + 12*s, y + 35*s, 8*s, 5*s);
        this.ctx.fillRect(x + 28*s, y + 35*s, 8*s, 5*s);
      },
      
      princess: (x, y, state = 'normal') => {
        const s = 1;
        
        // Dress
        this.ctx.fillStyle = '#FF69B4';
        this.ctx.fillRect(x, y + 10*s, 16*s, 14*s);
        
        // Dress trim
        this.ctx.fillStyle = '#FFB6C1';
        this.ctx.fillRect(x, y + 10*s, 16*s, 2*s);
        
        // Head
        this.ctx.fillStyle = '#FFE4B5';
        this.ctx.fillRect(x + 3*s, y + 2*s, 10*s, 10*s);
        
        // Hair
        this.ctx.fillStyle = '#FFD700';
        this.ctx.fillRect(x + 2*s, y, 12*s, 8*s);
        
        // Crown
        this.ctx.fillStyle = '#FFFF00';
        this.ctx.fillRect(x + 4*s, y, 8*s, 2*s);
        this.ctx.fillRect(x + 6*s, y - 1*s, 2*s, 2*s);
        this.ctx.fillRect(x + 10*s, y - 1*s, 2*s, 2*s);
        
        // Eyes
        this.ctx.fillStyle = '#000000';
        this.ctx.fillRect(x + 5*s, y + 5*s, 2*s, 2*s);
        this.ctx.fillRect(x + 9*s, y + 5*s, 2*s, 2*s);
        
        // Lips
        this.ctx.fillStyle = '#FF0000';
        this.ctx.fillRect(x + 6*s, y + 8*s, 4*s, 2*s);
        
        // Arms (raised if calling for help)
        this.ctx.fillStyle = '#FFE4B5';
        if (state === 'help') {
          this.ctx.fillRect(x + 1*s, y + 8*s, 3*s, 8*s);
          this.ctx.fillRect(x + 12*s, y + 8*s, 3*s, 8*s);
          // Hands raised
          this.ctx.fillRect(x + 2*s, y + 4*s, 2*s, 4*s);
          this.ctx.fillRect(x + 12*s, y + 4*s, 2*s, 4*s);
        } else {
          this.ctx.fillRect(x + 1*s, y + 12*s, 3*s, 8*s);
          this.ctx.fillRect(x + 12*s, y + 12*s, 3*s, 8*s);
        }
      }
    };
  }
  
  playSound(soundName) {
    // Professional audio with visual feedback
    this.audioManager.playSound(soundName);
    
    // Add professional visual sound feedback
    this.createSoundEffect(this.getSoundEmoji(soundName));
  }
  
  getSoundEmoji(soundName) {
    const emojiMap = {
      walk: "👟",
      jump: "🦘", 
      barrel: "💥",
      hammer: "🔨",
      death: "💀",
      levelComplete: "🎉",
      climb: "🪜",
      coin: "💰",
      powerUp: "⚡"
    };
    return emojiMap[soundName] || "🔊";
  }
  
  createSoundEffect(emoji) {
    // Create floating sound effect text
    if (!this.soundEffects) this.soundEffects = [];
    
    this.soundEffects.push({
      text: emoji,
      x: this.canvas.width - 50,
      y: 50 + (this.soundEffects.length % 5) * 20,
      life: 60,
      maxLife: 60
    });
    
    // Keep only recent sound effects
    if (this.soundEffects.length > 5) {
      this.soundEffects.shift();
    }
  }
  
  updateSoundEffects() {
    if (!this.soundEffects) return;
    
    for (let i = this.soundEffects.length - 1; i >= 0; i--) {
      let effect = this.soundEffects[i];
      effect.life--;
      effect.y -= 0.5;
      
      if (effect.life <= 0) {
        this.soundEffects.splice(i, 1);
      }
    }
  }
  
  renderSoundEffects() {
    if (!this.soundEffects) return;
    
    for (let effect of this.soundEffects) {
      let alpha = effect.life / effect.maxLife;
      this.ctx.save();
      this.ctx.globalAlpha = alpha;
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.font = 'bold 16px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.fillText(effect.text, effect.x, effect.y);
      this.ctx.restore();
    }
  }
  
  createParticles(x, y, count, color, type = 'explosion') {
    for (let i = 0; i < count; i++) {
      if (this.particles.length >= this.maxParticles) break;
      
      this.particles.push({
        x: x,
        y: y,
        vx: (Math.random() - 0.5) * 6,
        vy: (Math.random() - 0.5) * 6 - 2,
        color: color,
        life: 30 + Math.random() * 30,
        maxLife: 60,
        size: 2 + Math.random() * 3,
        type: type
      });
    }
  }
  
  updateParticles() {
    for (let i = this.particles.length - 1; i >= 0; i--) {
      let particle = this.particles[i];
      
      particle.x += particle.vx;
      particle.y += particle.vy;
      particle.vy += 0.2; // gravity
      particle.life--;
      
      if (particle.life <= 0) {
        this.particles.splice(i, 1);
      }
    }
  }
  
  renderParticles() {
    for (let particle of this.particles) {
      let alpha = particle.life / particle.maxLife;
      this.ctx.save();
      this.ctx.globalAlpha = alpha;
      this.ctx.fillStyle = particle.color;
      
      if (particle.type === 'spark') {
        this.ctx.fillRect(particle.x - 1, particle.y - 1, 2, 2);
      } else {
        this.ctx.fillRect(particle.x - particle.size/2, particle.y - particle.size/2, particle.size, particle.size);
      }
      
      this.ctx.restore();
    }
  }
  
  generateDonkeyKongPlatforms() {
    const platforms = [];
    
    // STEP 2: Fixed cascade system - each platform positioned to catch barrels
    
    // Bottom platform - flat, full width
    platforms.push({
      x: 50,
      y: 600,
      width: 800,
      height: 20,
      slope: 0,
      type: 'bottom'
    });
    
    // Level 1 - slopes RIGHT, positioned to catch from Level 2
    platforms.push({
      x: 100,  // Starts at x=100
      y: 500,
      width: 600, // Ends at x=700
      height: 20,
      slope: 0.04,
      type: 'girder'
    });
    
    // Level 2 - slopes LEFT, positioned to catch from Level 3  
    platforms.push({
      x: 200,  // Starts at x=200, ends at x=750 (overlaps with Level 1)
      y: 400,
      width: 550,
      height: 20,
      slope: -0.04,
      type: 'girder'
    });
    
    // Level 3 - slopes RIGHT, positioned to catch from Top
    platforms.push({
      x: 150,  // Starts at x=150, ends at x=600 (overlaps with Level 2)
      y: 300,
      width: 450,
      height: 20,
      slope: 0.04,
      type: 'girder'
    });
    
    // Top platform - slopes LEFT (where Kong sits)
    platforms.push({
      x: 250,  // Starts at x=250, ends at x=650 (overlaps with Level 3)
      y: 200,
      width: 400,
      height: 20,
      slope: -0.04,
      type: 'top'
    });
    
    return platforms;
  }

  generateLadders() {
    const ladders = [];
    
    // Ladders connecting all 5 levels
    // Bottom to Level 1
    ladders.push({
      x: 400,
      y: 500,
      width: 16, 
      height: 100, // 600 - 500 = 100
      type: 'full'
    });
    
    // Level 1 to Level 2  
    ladders.push({
      x: 500,
      y: 400,
      width: 16,
      height: 100, // 500 - 400 = 100
      type: 'full'
    });
    
    // Level 2 to Level 3
    ladders.push({
      x: 350,
      y: 300,
      width: 16,
      height: 100, // 400 - 300 = 100
      type: 'full'
    });
    
    // Level 3 to Top
    ladders.push({
      x: 450,
      y: 200,
      width: 16,
      height: 100, // 300 - 200 = 100
      type: 'full'
    });
    
    return ladders;
  }

  generateHammers() {
    const hammers = [];
    
    // Hammer on Level 2 (y: 400) - account for slope
    const level2Platform = { x: 200, y: 400, slope: -0.04 };
    const hammerX = 400;
    const relativeX = hammerX - level2Platform.x;
    const slopedY = level2Platform.y + (relativeX * level2Platform.slope);
    hammers.push({
      x: hammerX,
      y: slopedY - 12, // Position on sloped surface
      width: 16,
      height: 12,
      collected: false,
      sparkle: 0
    });
    
    // Hammer on Level 1 (y: 500) - account for slope  
    const level1Platform = { x: 100, y: 500, slope: 0.04 };
    const hammerX2 = 350;
    const relativeX2 = hammerX2 - level1Platform.x;
    const slopedY2 = level1Platform.y + (relativeX2 * level1Platform.slope);
    hammers.push({
      x: hammerX2,
      y: slopedY2 - 12, // Position on sloped surface
      width: 16,
      height: 12,
      collected: false,
      sparkle: 0
    });
    
    return hammers;
  }

  init() {
    this.setupControls();
    this.setupButtons();
    this.gameLoop();
  }
  
  setupControls() {
    // Professional CSP-compliant input handling
    this.keyDownHandler = (e) => {
      // Prevent default for game controls
      if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'KeyP', 'Escape'].includes(e.code)) {
        e.preventDefault();
        e.stopPropagation();
      }
      
      // Set key states first (before any early returns)
      if (!this.keys[e.code]) {
        this.keyPressed[e.code] = true;
      }
      this.keys[e.code] = true;
      
      // Handle special game controls
      if (e.code === 'KeyP' || e.code === 'Escape') {
        if (this.gameState === 'playing' || this.gameState === 'paused') {
          this.togglePause();
        }
        return;
      }
      
      // Handle start game with Enter or Space
      if ((e.code === 'Enter' || e.code === 'Space') && this.gameState === 'menu') {
        this.startGame();
        return;
      }
      
      // Handle restart with R
      if (e.code === 'KeyR' && this.gameState === 'gameOver') {
        this.restartGame();
        return;
      }
    };
    
    this.keyUpHandler = (e) => {
      // Prevent default for game controls
      if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) {
        e.preventDefault();
        e.stopPropagation();
      }
      
      this.keys[e.code] = false;
      this.keyPressed[e.code] = false;
    };
    
    this.blurHandler = () => {
      if (this.gameState === 'playing') {
        this.togglePause();
      }
    };
    
    // Add event listeners
    document.addEventListener('keydown', this.keyDownHandler, { passive: false });
    document.addEventListener('keyup', this.keyUpHandler, { passive: false });
    window.addEventListener('blur', this.blurHandler);
    
    // Focus management for better input handling
    this.canvas.setAttribute('tabindex', '0');
    this.canvas.focus();
    
    // Handle canvas focus for better input capture
    this.canvas.addEventListener('click', () => {
      this.canvas.focus();
      // Resume audio context on user interaction
      if (this.audioManager) {
        this.audioManager.resumeAudioContext();
      }
    });
  }
  
  setupButtons() {
    if (this.startButton) {
      this.startButton.addEventListener('click', () => {
        this.startGame();
      });
    }
    
    if (this.pauseButton) {
      this.pauseButton.addEventListener('click', () => {
        this.togglePause();
      });
    }
    
    if (this.restartButton) {
      this.restartButton.addEventListener('click', () => {
        this.restartGame();
      });
    }
  }
  
  startGame() {
    console.log('🎮 GAME: startGame() called - changing state from', this.gameState, 'to playing')
    this.gameState = 'playing';
    this.resetLevel();
    
    if (this.startButton) this.startButton.disabled = true;
    if (this.pauseButton) this.pauseButton.disabled = false;
    if (this.gameOverElement) this.gameOverElement.classList.add('game-over-hidden');
    console.log('🎮 GAME: Game started successfully, gameState:', this.gameState)
  }
  
  togglePause() {
    if (this.gameState === 'playing') {
      this.gameState = 'paused';
      if (this.pauseButton) this.pauseButton.textContent = 'Resume';
    } else if (this.gameState === 'paused') {
      this.gameState = 'playing';
      if (this.pauseButton) this.pauseButton.textContent = 'Pause';
    }
  }
  
  restartGame() {
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.bonus = 5000;
    this.frameCounter = 0;
    this.resetHammers();
    this.updateUI();
    this.startGame();
  }
  
  resetLevel() {
    this.player.x = 70; // Bottom-left start position  
    this.player.y = 596; // Bottom platform is at y:620, player height is 24, so 620-24=596
    this.player.vx = 0;
    this.player.vy = 0;
    this.player.onGround = true;
    this.player.onLadder = false;
    this.player.climbingLadder = false;
    this.player.isJumping = false;
    this.player.jumpTimer = 0;
    this.player.hasHammer = false;
    this.player.hammerTimer = 0;
    this.player.walkAnimation = 0;
    this.player.climbAnimation = 0;
    this.barrels = [];
    this.fireballs = [];
    this.bonus = 5000;
    this.bonusTimer = 0;
  }
  
  resetHammers() {
    for (let hammer of this.hammers) {
      hammer.collected = false;
      hammer.sparkle = 0;
    }
  }
  
  updatePlayer() {
    if (this.gameState !== 'playing' && this.gameState !== 'celebrating') return;
    
    // Handle celebration sequence
    if (this.gameState === 'celebrating') {
      this.celebrationTimer++;
      
      // Add more celebration particles throughout the celebration
      if (this.celebrationTimer % 20 === 0) {
        this.createParticles(this.princess.x + this.princess.width/2, this.princess.y + this.princess.height/2, 10, '#FFD700', 'spark');
        this.createParticles(this.player.x + this.player.width/2, this.player.y + this.player.height/2, 8, '#FFFF00', 'spark');
      }
      
      // End celebration and start next level
      if (this.celebrationTimer >= this.celebrationDuration) {
        this.gameState = 'playing';
        this.resetLevel();
        this.resetHammers();
        
        // Progressive difficulty
        this.barrelSpawnRate = Math.max(50, this.barrelSpawnRate - 8);
      }
      return;
    }
    
    this.frameCounter++;
    
    // Decrease bonus over time (every second)
    this.bonusTimer++;
    if (this.bonusTimer >= 60) {
      this.bonus = Math.max(0, this.bonus - 10);
      this.bonusTimer = 0;
    }
    
    // Hammer timer (15 seconds) with flashing warning
    if (this.player.hasHammer) {
      this.player.hammerTimer++;
      if (this.player.hammerTimer >= 900) {
        this.player.hasHammer = false;
        this.player.hammerTimer = 0;
      }
    }
    
    // Handle jumping animation
    if (this.player.isJumping) {
      this.player.jumpTimer++;
      if (this.player.jumpTimer >= this.player.jumpDuration) {
        this.player.isJumping = false;
        this.player.jumpTimer = 0;
      }
    }
    
    // Check ladder interaction
    this.checkLadderInteraction();
    
    if (this.player.climbingLadder) {
      // Ladder climbing mode
      this.player.vx = 0;
      this.player.vy = 0;
      
      if (this.keys['ArrowUp']) {
        this.player.vy = -1.5;
        this.player.climbAnimation = (this.player.climbAnimation + 1) % 20;
        if (this.frameCounter % 20 === 0) this.sounds.climb();
      } else if (this.keys['ArrowDown']) {
        this.player.vy = 1.5;
        this.player.climbAnimation = (this.player.climbAnimation + 1) % 20;
        if (this.frameCounter % 20 === 0) this.sounds.climb();
      }
      
      // Exit ladder with left/right movement
      if (this.keys['ArrowLeft'] || this.keys['ArrowRight']) {
        this.player.climbingLadder = false;
        this.player.onLadder = false;
      }
    } else {
      // Platform movement mode
      this.player.vx = 0;
      
      // Horizontal movement
      if (this.keys['ArrowLeft'] && !this.player.isJumping) {
        this.player.vx = -this.player.speed;
        this.player.direction = -1;
        this.player.walkAnimation = (this.player.walkAnimation + 1) % 30;
        if (this.frameCounter % 15 === 0) this.sounds.walk();
      } else if (this.keys['ArrowRight'] && !this.player.isJumping) {
        this.player.vx = this.player.speed;
        this.player.direction = 1;
        this.player.walkAnimation = (this.player.walkAnimation + 1) % 30;
        if (this.frameCounter % 15 === 0) this.sounds.walk();
      }
      
      // Donkey Kong style jumping - just enough to clear barrels on same platform
      if (this.keyPressed['Space'] && this.player.onGround && !this.player.isJumping && !this.player.hasHammer) {
        this.player.isJumping = true;
        this.player.jumpTimer = 0;
        this.player.jumpDuration = 25; // Medium jump duration
        this.player.vx = this.player.direction * (this.player.speed * 1.8); // Moderate horizontal movement
        this.player.vy = -5.5; // Just enough to clear barrels, not reach other platforms
        this.sounds.jump();
        // Add jump particles
        this.createParticles(this.player.x + this.player.width/2, this.player.y + this.player.height, 4, '#FFFF00', 'spark');
        this.keyPressed['Space'] = false; // Prevent continuous jumping
      }
      
      // Start climbing ladder (but not while holding hammer - authentic DK mechanic)
      if ((this.keys['ArrowUp'] || this.keys['ArrowDown']) && this.player.onLadder && this.player.onGround && !this.player.hasHammer) {
        this.player.climbingLadder = true;
        this.player.vx = 0;
        this.player.vy = 0;
        // Center player on ladder
        let currentLadder = this.getCurrentLadder();
        if (currentLadder) {
          this.player.x = currentLadder.x + (currentLadder.width - this.player.width) / 2;
        }
      }
    }
    
    // Apply gravity when not climbing and not on ground (lighter for better jumping)
    if (!this.player.climbingLadder && !this.player.onGround) {
      this.player.vy += 0.4; // Lighter gravity for better barrel jumping
    }
    
    // Update position
    this.player.x += this.player.vx;
    this.player.y += this.player.vy;
    
    // Keep player in bounds
    if (this.player.x < 0) this.player.x = 0;
    if (this.player.x + this.player.width > this.canvas.width) {
      this.player.x = this.canvas.width - this.player.width;
    }
    
    // Platform collision (only when not climbing)
    if (!this.player.climbingLadder) {
      this.checkPlatformCollisions();
    }
    
    // Check hammer collection
    this.checkHammerCollection();
    
    // Check if player reached princess
    if (this.checkCollision(this.player, this.princess)) {
      this.levelComplete();
    }
    
    // Check collisions - jumping logic handled inside checkEnemyCollisions
    this.checkEnemyCollisions();
  }
  
  getCurrentLadder() {
    let allLadders = [...this.ladders, ...this.brokenLadders];
    for (let ladder of allLadders) {
      if (this.player.x + this.player.width/2 > ladder.x &&
          this.player.x + this.player.width/2 < ladder.x + ladder.width &&
          this.player.y + this.player.height >= ladder.y &&
          this.player.y <= ladder.y + ladder.height) {
        return ladder;
      }
    }
    return null;
  }
  
  checkEnemyCollisions() {
    // Check barrel collisions
    for (let i = this.barrels.length - 1; i >= 0; i--) {
      let barrel = this.barrels[i];
      
      // Authentic DK mechanic - score points for jumping over barrels
      if (this.player.isJumping && !barrel.jumpedOver && 
          Math.abs(this.player.x - barrel.x) < 30 && 
          this.player.y < barrel.y - 5) {
        barrel.jumpedOver = true;
        this.score += 100;
        this.createParticles(barrel.x + barrel.width/2, barrel.y - 10, 3, '#FFFF00', 'spark');
        this.sounds.coin(); // Jump-over sound
        this.updateUI();
      }
      
      // Only check collision if player is NOT jumping or if player is on the ground
      // This allows jumping over barrels!
      if (!this.player.isJumping && this.checkCollision(this.player, barrel)) {
        if (this.player.hasHammer) {
          // Destroy barrel with hammer
          this.createParticles(barrel.x + barrel.width/2, barrel.y + barrel.height/2, 8, '#8B4513', 'explosion');
          this.createParticles(barrel.x + barrel.width/2, barrel.y + barrel.height/2, 5, '#FFFF00', 'spark');
          this.barrels.splice(i, 1);
          this.score += 300; // More points for hammer smash
          this.sounds.barrel();
          this.updateUI();
        } else {
          // Player hit by barrel - only when not jumping
          this.playerHit();
          return;
        }
      }
    }
    
    // Check fireball collisions
    for (let fireball of this.fireballs) {
      if (this.checkCollision(this.player, fireball)) {
        if (!this.player.hasHammer) {
          this.playerHit();
          return;
        }
      }
    }
  }
  
  checkLadderInteraction() {
    this.player.onLadder = false;
    
    let allLadders = [...this.ladders, ...this.brokenLadders];
    
    for (let ladder of allLadders) {
      // More precise ladder detection
      if (this.player.x + this.player.width/2 >= ladder.x + 2 &&
          this.player.x + this.player.width/2 <= ladder.x + ladder.width - 2 &&
          this.player.y + this.player.height >= ladder.y - 5 &&
          this.player.y <= ladder.y + ladder.height + 5) {
        this.player.onLadder = true;
        break;
      }
    }
  }
  
  checkPlatformCollisions() {
    this.player.onGround = false;
    
    for (let platform of this.platforms) {
      // Calculate exact platform height with slope
      let platformY = platform.y;
      if (platform.slope !== 0) {
        let relativeX = this.player.x + this.player.width/2 - platform.x;
        platformY = platform.y + (relativeX * platform.slope);
      }
      
      // Simple collision detection
      if (this.player.x + 2 < platform.x + platform.width &&
          this.player.x + this.player.width - 2 > platform.x &&
          this.player.y + this.player.height >= platformY &&
          this.player.y + this.player.height <= platformY + platform.height + 5) {
        
        this.player.y = platformY - this.player.height;
        this.player.vy = 0;
        this.player.onGround = true;
        break;
      }
    }
    
    // Fall off screen = death
    if (this.player.y > this.canvas.height) {
      this.playerHit();
    }
  }
  
  checkHammerCollection() {
    for (let hammer of this.hammers) {
      if (!hammer.collected) {
        hammer.sparkle = (hammer.sparkle + 1) % 60; // Sparkle animation
        
        if (this.checkCollision(this.player, hammer)) {
          hammer.collected = true;
          this.player.hasHammer = true;
          this.player.hammerTimer = 0;
          this.score += 300;
          // Add hammer collection particles
          this.createParticles(hammer.x + hammer.width/2, hammer.y + hammer.height/2, 10, '#FFFF00', 'spark');
          this.createParticles(hammer.x + hammer.width/2, hammer.y + hammer.height/2, 6, '#FF6B35', 'explosion');
          this.sounds.powerUp(); // Use power-up sound for hammer collection
          this.updateUI();
        }
      }
    }
  }
  
  updateBarrels() {
    if (this.gameState !== 'playing') return;
    
    // Update Honky Kong animations
    this.updateHonkyKong();
    
    // Spawn new barrels
    this.barrelSpawnTimer++;
    if (this.barrelSpawnTimer >= this.barrelSpawnRate) {
      this.spawnBarrel();
      this.barrelSpawnTimer = 0;
    }
    
    // Simple barrel physics for testing
    for (let i = this.barrels.length - 1; i >= 0; i--) {
      let barrel = this.barrels[i];
      
      if (barrel.onPlatform) {
        // Rolling on platform
        barrel.x += barrel.vx;
        barrel.rotation += Math.abs(barrel.vx) * 0.1;
        
        // Check if still on current platform
        let stillOnPlatform = false;
        for (let platform of this.platforms) {
          // Calculate platform surface Y with slope
          let relativeX = barrel.x + barrel.width/2 - platform.x;
          let platformY = platform.y + (relativeX * platform.slope);
          
          if (barrel.x + barrel.width > platform.x &&
              barrel.x < platform.x + platform.width &&
              Math.abs(barrel.y + barrel.height - platformY) < 25) {
            
            // Keep barrel on platform surface
            barrel.y = platformY - barrel.height;
            stillOnPlatform = true;
            break;
          }
        }
        
        // If barrel rolled off platform, start falling
        if (!stillOnPlatform) {
          barrel.onPlatform = false;
          barrel.vy = 0; // Start falling
        }
      } else {
        // Barrel is falling
        barrel.x += barrel.vx * 0.5; // Slower horizontal movement when falling
        barrel.y += barrel.vy;
        barrel.vy += 0.4; // Gravity
        barrel.rotation += Math.abs(barrel.vx) * 0.1;
        
        // Check if barrel lands on a platform
        for (let platform of this.platforms) {
          let platformY = platform.y;
          if (platform.slope !== 0) {
            let relativeX = barrel.x + barrel.width/2 - platform.x;
            platformY = platform.y + (relativeX * platform.slope);
          }
          
          if (barrel.x + barrel.width > platform.x &&
              barrel.x < platform.x + platform.width &&
              barrel.y + barrel.height >= platformY &&
              barrel.y + barrel.height <= platformY + platform.height + 10 &&
              barrel.vy > 0) {
            
            // Land on platform
            barrel.y = platformY - barrel.height;
            barrel.vy = 0;
            barrel.onPlatform = true;
            
            // Set rolling direction based on platform slope
            if (platform.slope > 0) {
              barrel.vx = 1.5; // Roll right down positive slope
            } else if (platform.slope < 0) {
              barrel.vx = -1.5; // Roll left down negative slope
            } else {
              barrel.vx = barrel.vx > 0 ? 1.5 : -1.5; // Keep direction on flat
            }
            
            break;
          }
        }
      }
      
      // Remove barrels that go off-screen
      if (barrel.y > this.canvas.height + 50 || 
          barrel.x < -50 || 
          barrel.x > this.canvas.width + 50) {
        this.barrels.splice(i, 1);
      }
    }
  }
  
  updateHonkyKong() {
    // Honky Kong beating animation
    this.honkyKong.beatTimer++;
    if (this.honkyKong.beatTimer >= 120) {
      this.honkyKong.beating = true;
      this.honkyKong.beatTimer = 0;
    }
    
    if (this.honkyKong.beating) {
      this.honkyKong.animation++;
      if (this.honkyKong.animation >= 30) {
        this.honkyKong.beating = false;
        this.honkyKong.animation = 0;
      }
    }
  }
  
  handleBarrelLadderLogic(barrel, platform) {
    // Enhanced barrel AI for ladder usage
    let nearLadder = false;
    let ladderDistance = 40;
    
    // Check if barrel is near platform edge and there's a ladder
    for (let ladder of this.ladders) {
      if (Math.abs(barrel.x - ladder.x) < ladderDistance &&
          Math.abs(barrel.y - ladder.y) < 10) {
        
        // Authentic DK barrel behavior - sometimes drop down ladders
        let dropChance = 0.15; // 15% chance like original DK
        
        if (Math.random() < dropChance) {
          barrel.x = ladder.x + (ladder.width - barrel.width) / 2;
          barrel.vy = 1.8;
          barrel.vx = 0;
          barrel.onPlatform = false;
          nearLadder = true;
          break;
        }
      }
    }
    
    // Authentic DK barrel behavior - keep rolling, don't bounce back much
    if (!nearLadder && (barrel.x <= platform.x + 5 || barrel.x >= platform.x + platform.width - 25)) {
      // Only 20% chance to bounce back, otherwise fall off platform
      if (Math.random() < 0.2) {
        barrel.vx = -barrel.vx * 0.6; // Weaker bounce
      } else {
        // Let barrel fall off platform edge
        barrel.onPlatform = false;
        barrel.vy = 0.5; // Start falling
      }
    }
  }
  
  spawnBarrel() {
    // Kong throws barrels that start rolling on top platform
    // Top platform slopes LEFT (negative slope), so barrel should roll LEFT
    this.barrels.push({
      x: this.honkyKong.x + 35,
      y: this.honkyKong.y + 45,
      width: 14,
      height: 12,
      vx: -1.5, // Roll LEFT down the negative slope
      vy: 0,
      rotation: 0,
      falling: false,
      onPlatform: true
    });
    
    // Trigger Honky Kong throw animation
    this.honkyKong.animation = 1;
  }
  
  updateFireballs() {
    if (this.gameState !== 'playing') return;
    
    // Update oil drum fire animation
    this.oilDrum.fire = (this.oilDrum.fire + 1) % 30;
    
    // Enhanced fireball spawning
    this.fireballSpawnTimer++;
    if (this.fireballSpawnTimer >= 400 && Math.random() < 0.25) {
      this.spawnFireball();
      this.fireballSpawnTimer = 0;
    }
    
    // Update fireballs with improved physics
    for (let i = this.fireballs.length - 1; i >= 0; i--) {
      let fireball = this.fireballs[i];
      fireball.x += fireball.vx;
      fireball.y += fireball.vy;
      fireball.vy += 0.25; // More realistic gravity
      fireball.animation = (fireball.animation + 1) % 20;
      
      // Smart platform bouncing
      for (let platform of this.platforms) {
        if (fireball.x < platform.x + platform.width &&
            fireball.x + fireball.width > platform.x &&
            fireball.y < platform.y + platform.height &&
            fireball.y + fireball.height > platform.y) {
          
          if (fireball.vy > 0) {
            fireball.vy = -Math.abs(fireball.vy) * 0.6;
            fireball.vx *= 0.9; // Slight friction
            fireball.bounces++;
          }
        }
      }
      
      // Remove spent fireballs
      if (fireball.bounces > 4 || fireball.y > this.canvas.height + 50) {
        this.fireballs.splice(i, 1);
      }
    }
  }
  
  spawnFireball() {
    this.fireballs.push({
      x: this.oilDrum.x + 8,
      y: this.oilDrum.y - 5,
      width: 12,
      height: 12,
      vx: (Math.random() > 0.5) ? 1.5 : -1.5,
      vy: -4,
      bounces: 0,
      animation: 0
    });
  }
  
  checkCollision(rect1, rect2) {
    // More precise collision detection
    return rect1.x + 2 < rect2.x + rect2.width - 2 &&
           rect1.x + rect1.width - 2 > rect2.x + 2 &&
           rect1.y + 2 < rect2.y + rect2.height - 2 &&
           rect1.y + rect1.height - 2 > rect2.y + 2;
  }
  
  playerHit() {
    this.lives--;
    this.sounds.death();
    
    // Death particles
    this.createParticles(this.player.x + this.player.width/2, this.player.y + this.player.height/2, 15, '#FF0000', 'explosion');
    this.createParticles(this.player.x + this.player.width/2, this.player.y + this.player.height/2, 10, '#FFFF00', 'spark');
    
    this.updateUI();
    
    if (this.lives <= 0) {
      this.gameOver();
    } else {
      this.resetLevel();
    }
  }
  
  levelComplete() {
    this.score += this.bonus; // Time bonus
    this.score += 3000; // Level completion bonus
    this.level++;
    this.sounds.levelComplete();
    
    // SPECTACULAR RESCUE CELEBRATION!
    this.gameState = 'celebrating';
    this.celebrationTimer = 0;
    this.celebrationDuration = 240; // 4 seconds at 60fps
    
    // Massive explosion of particles around princess
    this.createParticles(this.princess.x + this.princess.width/2, this.princess.y + this.princess.height/2, 50, '#FFD700', 'explosion');
    this.createParticles(this.princess.x + this.princess.width/2, this.princess.y + this.princess.height/2, 30, '#FF69B4', 'spark');
    this.createParticles(this.princess.x + this.princess.width/2, this.princess.y + this.princess.height/2, 25, '#FFFFFF', 'spark');
    this.createParticles(this.princess.x + this.princess.width/2, this.princess.y + this.princess.height/2, 20, '#FF0000', 'spark');
    this.createParticles(this.princess.x + this.princess.width/2, this.princess.y + this.princess.height/2, 15, '#00FF00', 'spark');
    
    // Particles around player too
    this.createParticles(this.player.x + this.player.width/2, this.player.y + this.player.height/2, 30, '#FFFF00', 'spark');
    this.createParticles(this.player.x + this.player.width/2, this.player.y + this.player.height/2, 20, '#FF6B35', 'explosion');
    
    // Award points for remaining hammers
    for (let hammer of this.hammers) {
      if (!hammer.collected) {
        this.score += 100;
      }
    }
    
    this.updateUI();
  }
  
  gameOver() {
    this.gameState = 'gameOver';
    
    if (this.gameOverElement) this.gameOverElement.classList.remove('game-over-hidden');
    if (this.finalScoreElement) this.finalScoreElement.textContent = this.score.toString().padStart(6, '0');
    if (this.startButton) this.startButton.disabled = false;
    if (this.pauseButton) this.pauseButton.disabled = true;
  }
  
  updateUI() {
    if (this.scoreElement) this.scoreElement.textContent = this.score.toString().padStart(6, '0');
    if (this.livesElement) this.livesElement.textContent = this.lives;
    if (this.levelElement) this.levelElement.textContent = this.level;
    if (this.bonusElement) this.bonusElement.textContent = this.bonus;
  }
  
  render() {
    // Clear canvas with authentic black background
    this.ctx.fillStyle = '#000000';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    
    // Draw simple rectangular platforms  
    for (let platform of this.platforms) {
      this.ctx.save();
      
      // Draw sloped platform as trapezoid
      if (platform.slope !== 0) {
        const slopeOffset = platform.slope * platform.width;
        
        this.ctx.beginPath();
        this.ctx.moveTo(platform.x, platform.y);
        this.ctx.lineTo(platform.x + platform.width, platform.y + slopeOffset);
        this.ctx.lineTo(platform.x + platform.width, platform.y + slopeOffset + platform.height);
        this.ctx.lineTo(platform.x, platform.y + platform.height);
        this.ctx.closePath();
        
        // Main girder body
        this.ctx.fillStyle = '#FF6B35';
        this.ctx.fill();
        
        // Shadow
        this.ctx.fillStyle = '#CC4A00';
        this.ctx.beginPath();
        this.ctx.moveTo(platform.x, platform.y + platform.height - 3);
        this.ctx.lineTo(platform.x + platform.width, platform.y + slopeOffset + platform.height - 3);
        this.ctx.lineTo(platform.x + platform.width, platform.y + slopeOffset + platform.height);
        this.ctx.lineTo(platform.x, platform.y + platform.height);
        this.ctx.closePath();
        this.ctx.fill();
      } else {
        // Flat platform
        this.ctx.fillStyle = '#FF6B35';
        this.ctx.fillRect(platform.x, platform.y, platform.width, platform.height);
        
        // Shadow
        this.ctx.fillStyle = '#CC4A00';
        this.ctx.fillRect(platform.x, platform.y + platform.height - 3, platform.width, 3);
      }
      
      this.ctx.restore();
    }
    
    // Draw professional ladders
    for (let ladder of this.ladders) {
      // Ladder rails
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.fillRect(ladder.x, ladder.y, 3, ladder.height);
      this.ctx.fillRect(ladder.x + 13, ladder.y, 3, ladder.height);
      
      // Ladder rungs with authentic spacing
      this.ctx.fillStyle = '#DDDD00';
      for (let y = ladder.y; y < ladder.y + ladder.height; y += 10) {
        this.ctx.fillRect(ladder.x, y, 16, 2);
      }
    }
    
    // Draw broken ladders with different styling
    for (let ladder of this.brokenLadders) {
      this.ctx.fillStyle = '#CCCC00';
      this.ctx.fillRect(ladder.x, ladder.y, 3, ladder.height);
      this.ctx.fillRect(ladder.x + 13, ladder.y, 3, ladder.height);
      
      // Broken rungs (some missing)
      this.ctx.fillStyle = '#AAAA00';
      for (let y = ladder.y; y < ladder.y + ladder.height; y += 15) {
        if (Math.random() > 0.3) { // Some rungs missing
          this.ctx.fillRect(ladder.x, y, 16, 2);
        }
      }
    }
    
    // Draw animated oil drum with fire
    this.ctx.fillStyle = '#333333';
    this.ctx.fillRect(this.oilDrum.x, this.oilDrum.y, this.oilDrum.width, this.oilDrum.height);
    
    // Oil drum bands
    this.ctx.fillStyle = '#555555';
    this.ctx.fillRect(this.oilDrum.x, this.oilDrum.y + 5, this.oilDrum.width, 3);
    this.ctx.fillRect(this.oilDrum.x, this.oilDrum.y + 15, this.oilDrum.width, 3);
    
    // Animated fire on drum
    if (this.oilDrum.fire < 15) {
      this.ctx.fillStyle = '#FF4444';
      this.ctx.fillRect(this.oilDrum.x + 3, this.oilDrum.y - 8, 18, 6);
      this.ctx.fillStyle = '#FFAA00';
      this.ctx.fillRect(this.oilDrum.x + 6, this.oilDrum.y - 5, 12, 3);
    }
    
    // Draw professional characters
    this.drawHonkyKong();
    this.drawPrincess();
    this.drawPlayer();
    this.drawHammers();
    this.drawBarrels();
    this.drawFireballs();
    
    // Draw game UI overlays
    this.drawGameStateOverlays();
    
    // Draw in-game HUD
    if (this.gameState === 'playing') {
      this.drawHUD();
    }
    
    // Draw professional sound effects and particles
    this.renderSoundEffects();
    this.renderParticles();
  }
  
  drawHonkyKong() {
    let kong = this.honkyKong;
    let state = 'normal';
    
    // Determine sprite state based on Kong's status
    if (kong.animation > 0) {
      state = 'throwing';
    } else if (kong.beating) {
      state = 'beating';
    }
    
    // Draw professional Donkey Kong sprite
    this.sprites.donkeyKong(kong.x, kong.y, state);
  }
  
  drawPrincess() {
    let princess = this.princess;
    
    // Determine sprite state based on animation
    let state = princess.helpTimer < 60 ? 'help' : 'normal';
    
    // Draw professional Princess sprite
    this.sprites.princess(princess.x, princess.y, state);
    
    // Animated help text
    if (princess.helpTimer < 60) {
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.font = 'bold 10px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.textBaseline = 'middle';
      this.ctx.strokeStyle = '#000000';
      this.ctx.lineWidth = 2;
      this.ctx.strokeText('HELP!', princess.x + 8, princess.y - 8);
      this.ctx.fillText('HELP!', princess.x + 8, princess.y - 8);
    }
  }
  
  drawPlayer() {
    let player = this.player;
    let state = 'normal';
    
    // Determine sprite state based on player status
    if (player.hasHammer) {
      state = 'hammer';
    } else if (player.climbingLadder) {
      state = 'climb';
    }
    
    // Flash player when hammer time is about to expire (last 5 seconds = 300 frames)
    let shouldFlash = false;
    if (player.hasHammer && player.hammerTimer >= 600) { // Last 5 seconds (900 - 300 = 600)
      shouldFlash = Math.floor(this.frameCounter / 10) % 2 === 0; // Flash every 10 frames
    }
    
    // Mirror the sprite based on direction
    this.ctx.save();
    
    // Apply flashing effect
    if (shouldFlash) {
      this.ctx.globalAlpha = 0.3; // Make player semi-transparent when flashing
    }
    
    if (player.direction < 0) {
      this.ctx.translate(player.x + player.width/2, player.y + player.height/2);
      this.ctx.scale(-1, 1);
      this.sprites.mario(-player.width/2, -player.height/2, state);
    } else {
      this.sprites.mario(player.x, player.y, state);
    }
    this.ctx.restore();
    
    // Jumping spark effect
    if (player.isJumping) {
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.fillRect(player.x + 7, player.y - 3, 2, 2);
    }
  }
  
  drawHammers() {
    for (let hammer of this.hammers) {
      if (!hammer.collected) {
        // Hammer handle
        this.ctx.fillStyle = '#8B4513';
        this.ctx.fillRect(hammer.x + 6, hammer.y - 2, 4, 12);
        
        // Hammer head
        this.ctx.fillStyle = '#666666';
        this.ctx.fillRect(hammer.x, hammer.y + 2, 16, 6);
        
        // Sparkling effect
        if (hammer.sparkle < 20) {
          this.ctx.fillStyle = '#FFFF00';
          this.ctx.fillRect(hammer.x - 2, hammer.y - 2, 2, 2);
          this.ctx.fillRect(hammer.x + 16, hammer.y + 8, 2, 2);
        }
        if (hammer.sparkle >= 20 && hammer.sparkle < 40) {
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.fillRect(hammer.x + 8, hammer.y - 3, 2, 2);
          this.ctx.fillRect(hammer.x - 1, hammer.y + 6, 2, 2);
        }
      }
    }
  }
  
  drawBarrels() {
    for (let barrel of this.barrels) {
      this.ctx.save();
      this.ctx.translate(barrel.x + barrel.width/2, barrel.y + barrel.height/2);
      this.ctx.rotate(barrel.rotation);
      
      // Barrel body
      this.ctx.fillStyle = '#8B4513';
      this.ctx.fillRect(-barrel.width/2, -barrel.height/2, barrel.width, barrel.height);
      
      // Barrel bands (authentic look)
      this.ctx.fillStyle = '#654321';
      this.ctx.fillRect(-barrel.width/2, -barrel.height/2 + 2, barrel.width, 1);
      this.ctx.fillRect(-barrel.width/2, -barrel.height/2 + barrel.height/2, barrel.width, 1);
      this.ctx.fillRect(-barrel.width/2, -barrel.height/2 + barrel.height - 3, barrel.width, 1);
      
      // Barrel highlight
      this.ctx.fillStyle = '#AA6633';
      this.ctx.fillRect(-barrel.width/2 + 1, -barrel.height/2 + 1, barrel.width - 2, 2);
      
      this.ctx.restore();
    }
  }
  
  drawFireballs() {
    for (let fireball of this.fireballs) {
      // Flame core
      this.ctx.fillStyle = '#FF4444';
      this.ctx.fillRect(fireball.x, fireball.y, fireball.width, fireball.height);
      
      // Flame center
      this.ctx.fillStyle = '#FFAA00';
      this.ctx.fillRect(fireball.x + 2, fireball.y + 2, fireball.width - 4, fireball.height - 4);
      
      // Flame hot center
      this.ctx.fillStyle = '#FFFF44';
      this.ctx.fillRect(fireball.x + 4, fireball.y + 4, fireball.width - 8, fireball.height - 8);
      
      // Animated flicker
      if (fireball.animation < 10) {
        this.ctx.fillStyle = '#FFFFFF';
        this.ctx.fillRect(fireball.x + 5, fireball.y + 5, 2, 2);
      }
    }
  }
  
  drawGameStateOverlays() {
    if (this.gameState === 'menu') {
      this.ctx.fillStyle = 'rgba(0, 0, 0, 0.85)';
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
      
      // Title with retro styling
      this.ctx.fillStyle = '#FF6B35';
      this.ctx.font = 'bold 48px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.fillText('HONKY PONG', this.canvas.width / 2, this.canvas.height / 2 - 120);
      
      // Subtitle
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.font = 'bold 24px monospace';
      this.ctx.fillText('Classic Arcade Adventure', this.canvas.width / 2, this.canvas.height / 2 - 80);
      
      // Instructions
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.font = '16px monospace';
      this.ctx.fillText('🎯 Rescue Princess Pauline from Honky Kong!', this.canvas.width / 2, this.canvas.height / 2 - 20);
      this.ctx.fillText('🪜 UP/DOWN arrows: Climb ladders between levels', this.canvas.width / 2, this.canvas.height / 2 + 10);
      this.ctx.fillText('🦘 SPACEBAR: Jump horizontally over barrels', this.canvas.width / 2, this.canvas.height / 2 + 40);
      this.ctx.fillText('🔨 Collect hammers to destroy barrels (15s timer)', this.canvas.width / 2, this.canvas.height / 2 + 70);
      
      this.ctx.fillStyle = '#FFAA00';
      this.ctx.font = '14px monospace';
      this.ctx.fillText('⌨️ CONTROLS: P=Pause • R=Restart • ESC=Pause', this.canvas.width / 2, this.canvas.height / 2 + 100);
      
      this.ctx.fillStyle = '#00FF00';
      this.ctx.font = 'bold 20px monospace';
      this.ctx.fillText('▶ PRESS SPACE or ENTER to start! ◀', this.canvas.width / 2, this.canvas.height / 2 + 140);
    } else if (this.gameState === 'paused') {
      this.ctx.fillStyle = 'rgba(0, 0, 0, 0.8)';
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
      
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.font = 'bold 48px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.fillText('⏸ PAUSED ⏸', this.canvas.width / 2, this.canvas.height / 2);
    } else if (this.gameState === 'celebrating') {
      // Spectacular celebration overlay
      this.ctx.fillStyle = 'rgba(255, 215, 0, 0.3)'; // Golden overlay
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
      
      // Pulsing celebration text
      const pulse = Math.sin(this.celebrationTimer * 0.3) * 0.5 + 0.5;
      const textSize = 32 + (pulse * 16);
      
      this.ctx.fillStyle = '#FF69B4';
      this.ctx.font = `bold ${textSize}px monospace`;
      this.ctx.textAlign = 'center';
      this.ctx.strokeStyle = '#FFFFFF';
      this.ctx.lineWidth = 2;
      this.ctx.strokeText('💖 PRINCESS RESCUED! 💖', this.canvas.width / 2, this.canvas.height / 2 - 60);
      this.ctx.fillText('💖 PRINCESS RESCUED! 💖', this.canvas.width / 2, this.canvas.height / 2 - 60);
      
      // Scrolling love message
      this.ctx.fillStyle = '#FFD700';
      this.ctx.font = 'bold 24px monospace';
      this.ctx.fillText('💕 True Love Conquers All! 💕', this.canvas.width / 2, this.canvas.height / 2 - 10);
      
      // Score celebration
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.font = 'bold 20px monospace';
      this.ctx.fillText(`🎉 LEVEL ${this.level - 1} COMPLETE! 🎉`, this.canvas.width / 2, this.canvas.height / 2 + 30);
      this.ctx.fillText(`⭐ BONUS: ${this.bonus} points! ⭐`, this.canvas.width / 2, this.canvas.height / 2 + 60);
      
      // Next level countdown
      const timeLeft = Math.ceil((this.celebrationDuration - this.celebrationTimer) / 60);
      this.ctx.fillStyle = '#00FF00';
      this.ctx.font = '16px monospace';
      this.ctx.fillText(`Next level in: ${timeLeft}s`, this.canvas.width / 2, this.canvas.height / 2 + 90);
    }
  }
  
  drawHUD() {
    // Lives indicator (Mario sprites)
    for (let i = 0; i < this.lives; i++) {
      let x = 20 + (i * 25);
      this.ctx.fillStyle = '#FF0000';
      this.ctx.fillRect(x, 15, 16, 20);
      this.ctx.fillStyle = '#FFE4B5';
      this.ctx.fillRect(x + 2, 17, 12, 8);
      this.ctx.fillStyle = '#8B4513';
      this.ctx.fillRect(x + 5, 22, 6, 2);
    }
    
    // Hammer indicator
    if (this.player.hasHammer) {
      let timeLeft = Math.ceil((900 - this.player.hammerTimer) / 60);
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.font = 'bold 14px monospace';
      this.ctx.textAlign = 'left';
      this.ctx.fillText(`🔨 ${timeLeft}s`, 20, 60);
    }
    
    // Current level indicator
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = 'bold 12px monospace';
    this.ctx.textAlign = 'right';
    this.ctx.fillText(`L-${this.level.toString().padStart(2, '0')}`, this.canvas.width - 20, 25);
  }
  
  gameLoop() {
    // Professional game loop with proper update ordering
    try {
      this.updateSoundEffects();
      this.updateParticles();
      this.updatePlayer();
      this.updateBarrels();
      this.updateFireballs();
      this.updatePrincess();
      this.render();
      
      // Professional performance monitoring
      this.updatePerformanceMetrics();
    } catch (error) {
      console.error('Game loop error:', error);
      // Graceful error handling - pause game on error
      if (this.gameState === 'playing') {
        this.gameState = 'paused';
      }
    }
    
    this.animationFrame = requestAnimationFrame(() => this.gameLoop());
  }
  
  updatePrincess() {
    // Animate princess calling for help
    this.princess.helpTimer = (this.princess.helpTimer + 1) % 120;
    this.princess.animation = (this.princess.animation + 1) % 60;
  }
  
  // Professional performance monitoring
  updatePerformanceMetrics() {
    if (this.performanceIndicator) {
      const fps = Math.round(1000 / (performance.now() - this.lastFrameTime));
      const memory = Math.round(performance.memory ? performance.memory.usedJSHeapSize / 1024 / 1024 : 0);
      const particles = this.particles.length;
      
      this.performanceIndicator.innerHTML = `
        <div class="fps-counter">FPS: ${fps}</div>
        <div class="memory-usage">Memory: ${memory}MB</div>
        <div class="particle-count">Particles: ${particles}</div>
      `;
    }
    this.lastFrameTime = performance.now();
  }
  
  // Professional cleanup method
  destroy() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
    
    // Clean up audio manager
    if (this.audioManager) {
      this.audioManager.destroy();
    }
    
    // Clean up event listeners
    if (this.keyDownHandler) {
      document.removeEventListener('keydown', this.keyDownHandler);
    }
    if (this.keyUpHandler) {
      document.removeEventListener('keyup', this.keyUpHandler);
    }
    if (this.blurHandler) {
      window.removeEventListener('blur', this.blurHandler);
    }
  }
  
  // Professional keyboard event handlers (for external access)
  handleKeyDown(event) {
    this.keyDownHandler(event);
  }
  
  handleKeyUp(event) {
    this.keyUpHandler(event);
  }
}