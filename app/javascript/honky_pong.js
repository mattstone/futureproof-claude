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
    
    // AUTHENTIC DONKEY KONG LEVEL SYSTEM
    this.currentLevelType = 1; // 1=Barrels, 2=Elevators, 3=Boss
    this.platforms = this.generateLevelPlatforms(this.currentLevelType);
    
    // Generate ladders dynamically based on platform positions
    this.ladders = this.generateLadders();
    
    // Generate hammer positions dynamically on middle platforms
    this.hammers = this.generateHammers();
    
    // Honky Kong (Donkey Kong) - on top platform (x=250, y=180, width=450)
    this.honkyKong = {
      x: 270,  // Left side of top platform (x=250 + 20 margin)
      y: 140,  // On top of platform (platform y=180 - kong height=40 = y=140)
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
      x: 620,  // Right side of top platform (x=250 + width=450 - 30 margin = 620) 
      y: 156,  // On top of platform (platform y=180 - princess height=24 = y=156)
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
    
    // Load authentic Donkey Kong sound files from data attributes
    this.soundPaths = {
      bacmusic: this.canvas.dataset.soundBacmusic,
      death: this.canvas.dataset.soundDeath,
      hammer: this.canvas.dataset.soundHammer,
      howhigh: this.canvas.dataset.soundHowhigh,
      intro: this.canvas.dataset.soundIntro,
      introLong: this.canvas.dataset.soundIntroLong,
      itemget: this.canvas.dataset.soundItemget,
      jump: this.canvas.dataset.soundJump,
      jumpbar: this.canvas.dataset.soundJumpbar,
      walking: this.canvas.dataset.soundWalking,
      win1: this.canvas.dataset.soundWin1,
      win2: this.canvas.dataset.soundWin2
    };
    
    // Initialize authentic sound system
    this.sounds = {};
    this.audioElements = {};
    this.loadSounds();
    
    // Professional sound system integration with authentic Donkey Kong sounds
    this.sounds = {
      walk: () => this.playSound("walking"),
      jump: () => this.playSound("jump"), 
      barrel: () => this.playSound("hammer"), // Use hammer sound for barrel destruction
      hammer: () => this.playSound("hammer"),
      death: () => this.playSound("death"),
      levelComplete: () => this.playSound("win1"),
      climb: () => this.playSound("walking"), // Use walking sound for climbing
      coin: () => this.playSound("itemget"), // Use itemget for points
      powerUp: () => this.playSound("itemget"), // Use itemget for hammer pickup
      backgroundMusic: () => this.playSound("bacmusic", true), // Background music with loop
      victory: () => this.playSound("win2"),
      jumpOverBarrel: () => this.playSound("jumpbar"), // Special jump over barrel sound
      howhigh: () => this.playSound("howhigh"), // High score/bonus sound
      intro: () => this.playSound("intro") // Game start sound
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
    // Load authentic Donkey Kong sprite sheets
    this.spriteSheets = {};
    this.spritesLoaded = 0;
    this.totalSprites = 4;
    
    // Load sprite sheets using Rails asset paths from data attributes
    const marioPath = this.canvas.dataset.marioSprite;
    const enemiesPath = this.canvas.dataset.enemiesSprite;
    const paulinePath = this.canvas.dataset.paulineSprite;
    const levelsPath = this.canvas.dataset.levelsSprite;
    
    if (marioPath && enemiesPath && paulinePath && levelsPath) {
      this.loadSpriteSheet('mario', marioPath);
      this.loadSpriteSheet('enemies', enemiesPath);
      this.loadSpriteSheet('pauline', paulinePath);
      this.loadSpriteSheet('levels', levelsPath);
    } else {
      console.warn('Sprite sheet paths not found in canvas data attributes');
    }
    
    // Initialize fallback sprites
    this.initializeFallbackSprites();
  }

  loadSpriteSheet(name, url) {
    const img = new Image();
    img.onload = () => {
      this.spriteSheets[name] = img;
      this.spritesLoaded++;
      console.log(`Loaded sprite sheet: ${name} (${this.spritesLoaded}/${this.totalSprites})`);
      
      if (this.spritesLoaded === this.totalSprites) {
        console.log('All Donkey Kong sprites loaded!');
        this.allSpritesLoaded = true;
        
        // Now that sprites are loaded, regenerate levels with authentic data
        // DISABLED: this.regenerateLevelsFromSprites(); // Claude: Using simple platforms instead
        console.log('🔥 CLAUDE: Sprite regeneration DISABLED - using simple platforms!');
      }
    };
    img.onerror = () => {
      console.warn(`Failed to load sprite sheet: ${name}`);
      this.spritesLoaded++; // Count as loaded to prevent hanging
    };
    img.src = url;
  }

  drawSprite(sheetName, sx, sy, sw, sh, dx, dy, dw = sw, dh = sh) {
    if (this.allSpritesLoaded && this.spriteSheets[sheetName]) {
      this.ctx.drawImage(
        this.spriteSheets[sheetName],
        sx, sy, sw, sh,
        dx, dy, dw, dh
      );
      return true;
    }
    return false;
  }

  initializeFallbackSprites() {
    
    // Authentic Donkey Kong sprite drawing functions
    this.sprites = {
      mario: (x, y, state = 'right') => {
        // Try to draw authentic Mario sprite first
        let spriteDrawn = false;
        
        if (this.allSpritesLoaded) {
          // Mario sprites - using exact pixel coordinates
          let sx = 0, sy = 0;
          let spriteW = 16; // Default width
          let spriteH = 16; // Default height
          
          switch (state) {
            // Left-facing states (top row)
            case 'dead-left':
              sx = 0; sy = 0; // Dead Mario facing left (0-15)
              break;
            case 'run-left-1':
              sx = 40; sy = 0; // Running left frame 1 (40-55)
              break;
            case 'run-left-2':
              sx = 80; sy = 0; // Running left frame 2 (80-95)
              break;
            case 'left':
            case 'stand-left':
              sx = 120; sy = 0; // Standing left (120-135)
              break;
              
            // Right-facing states (top row)
            case 'right':
            case 'stand-right':
              sx = 160; sy = 0; // Standing right (160-175)
              break;
            case 'run-right-1':
              sx = 200; sy = 0; // Running right frame 1 (200-215)
              break;
            case 'run-right-2':
              sx = 240; sy = 0; // Running right frame 2 (240-255)
              break;
            case 'dead-right':
              sx = 280; sy = 0; // Dead Mario facing right (280-295)
              break;
              
            // Climbing ladder states (second row, y: 40-55)
            case 'climb-bottom':
              sx = 0; sy = 40; // Mario at bottom of ladder (0-15, 40-55)
              break;
            case 'climb-1':
              sx = 40; sy = 40; // Climbing frame 1 (40-55, 40-55)
              break;
            case 'climb-2':
              sx = 80; sy = 40; // Climbing frame 2 (80-95, 40-55)
              break;
            case 'climb-3':
              sx = 120; sy = 40; // Climbing frame 3 (120-135, 40-55)
              break;
            case 'climb-4':
              sx = 160; sy = 40; // Climbing frame 4 (160-175, 40-55)
              break;
            case 'climb-5':
              sx = 200; sy = 40; // Climbing frame 5 (200-215, 40-55)
              break;
            case 'climb-6':
              sx = 240; sy = 40; // Climbing frame 6 (240-255, 40-55)
              break;
            case 'climb-top':
              sx = 280; sy = 40; // Mario at top of ladder (280-295, 40-55)
              break;
              
            // Hammer states (third row) - Left facing
            case 'hammer-left-up-1':
              sx = 0; sy = 65; spriteW = 16; spriteH = 40; // VR: Mario hammer up left (0-15, 65-105)
              break;
            case 'hammer-left-down-1':
              sx = 35; sy = 70; spriteW = 21; spriteH = 25; // HR: Mario hammer down left (35-55, 70-95)
              break;
            case 'hammer-left-up-2':
              sx = 80; sy = 65; spriteW = 16; spriteH = 40; // VR: Mario hammer up left (80-95, 65-105)
              break;
            case 'hammer-left-down-2':
              sx = 115; sy = 70; spriteW = 26; spriteH = 25; // HR: Mario hammer down left (115-140, 70-95)
              break;
              
            // Hammer states (third row) - Right facing
            case 'hammer-right-down-1':
              sx = 155; sy = 70; spriteW = 26; spriteH = 25; // HR: Mario hammer down right (155-180, 70-95)
              break;
            case 'hammer-right-up-1':
              sx = 200; sy = 65; spriteW = 16; spriteH = 40; // VR: Mario hammer up right (200-215, 65-105)
              break;
            case 'hammer-right-down-2':
              sx = 235; sy = 70; spriteW = 26; spriteH = 25; // HR: Mario hammer down right (235-260, 70-95)
              break;
            case 'hammer-right-up-2':
              sx = 280; sy = 65; spriteW = 16; spriteH = 40; // VR: Mario hammer up right (280-295, 65-105)
              break;
              
            // Death tumbling animation (fourth row, y: 120-135)
            case 'tumble-1':
              sx = 0; sy = 120; spriteW = 15; spriteH = 16; // Tumbling frame 1 (0-15, 120-135)
              break;
            case 'tumble-2':
              sx = 40; sy = 120; spriteW = 15; spriteH = 16; // Tumbling frame 2 (40-55, 120-135)
              break;
            case 'tumble-3':
              sx = 80; sy = 120; spriteW = 15; spriteH = 16; // Tumbling frame 3 (80-95, 120-135)
              break;
            case 'tumble-4':
              sx = 120; sy = 120; spriteW = 15; spriteH = 16; // Tumbling frame 4 (120-135, 120-135)
              break;
            case 'tumble-5':
              sx = 160; sy = 120; spriteW = 15; spriteH = 16; // Tumbling frame 5 (160-175, 120-135)
              break;
            case 'tumble-6':
              sx = 200; sy = 120; spriteW = 15; spriteH = 16; // Tumbling frame 6 (200-215, 120-135)
              break;
            case 'tumble-7':
              sx = 240; sy = 120; spriteW = 15; spriteH = 16; // Tumbling frame 7 (240-255, 120-135)
              break;
            case 'tumble-8':
              sx = 280; sy = 120; spriteW = 15; spriteH = 16; // Tumbling frame 8 (280-295, 120-135)
              break;
              
            // Default to standing right
            default:
              sx = 160; sy = 0;
          }
          
          // Scale to appropriate render size while maintaining aspect ratio
          const renderW = spriteH > 16 ? 16 : spriteW; // VR sprites render at 16 width
          const renderH = spriteH > 16 ? 32 : 16;      // VR sprites render taller
          spriteDrawn = this.drawSprite('mario', sx, sy, spriteW, spriteH, x, y, renderW, renderH);
        }
        
        // Fallback to drawn sprite if needed
        if (!spriteDrawn) {
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
        } // Close fallback sprite drawing
      },
      
      donkeyKong: (x, y, state = 'normal') => {
        // Try to draw authentic Donkey Kong sprite first
        let spriteDrawn = false;
        
        if (this.allSpritesLoaded) {
          // Donkey Kong sprites from enemies.png (bottom row has the big Kong sprites)
          let sx = 0, sy = 64; // Bottom row of enemies sprite sheet
          
          switch (state) {
            case 'normal':
              sx = 0; sy = 64; // First big Kong sprite
              break;
            case 'beating':
              sx = 32; sy = 64; // Second big Kong sprite (chest beating)
              break;
          }
          
          spriteDrawn = this.drawSprite('enemies', sx, sy, 32, 32, x, y, 48, 40);
        }
        
        // Fallback to drawn sprite if needed
        if (!spriteDrawn) {
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
        } // Close fallback sprite drawing
      },
      
      princess: (x, y, state = 'normal') => {
        // Try to draw authentic Pauline sprite first
        let spriteDrawn = false;
        
        if (this.allSpritesLoaded) {
          // Pauline sprites from pauline.png
          let sx = 0, sy = 0;
          
          switch (state) {
            case 'normal':
              sx = 0; sy = 0; // First Pauline sprite
              break;
            case 'help':
              sx = 16; sy = 0; // Second Pauline sprite (calling for help)
              break;
          }
          
          spriteDrawn = this.drawSprite('pauline', sx, sy, 16, 24, x, y, 16, 24);
        }
        
        // Fallback to drawn sprite if needed
        if (!spriteDrawn) {
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
        } // Close fallback sprite drawing
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
  
  generateLevelPlatforms(levelType) {
    switch(levelType) {
      case 1: return this.generateBarrelLevel();
      case 2: return this.generateElevatorLevel(); 
      case 3: return this.generateBossLevel();
      default: return this.generateBarrelLevel();
    }
  }

  generateBarrelLevel() {
    // Level 1: Classic Donkey Kong barrel level with slanted platforms
    // Extracted from authentic arcade level layout
    const platforms = [];
    
    // Bottom platform (ground level) - flat
    platforms.push({ x: 20, y: 620, width: 860, height: 20, slope: 0, color: '#FF69B4' });
    
    // Platform 2 - slanted up left to right  
    platforms.push({ x: 120, y: 540, width: 700, height: 20, slope: -0.02, color: '#FF69B4' });
    
    // Platform 3 - slanted down left to right
    platforms.push({ x: 20, y: 460, width: 700, height: 20, slope: 0.02, color: '#FF69B4' });
    
    // Platform 4 - slanted up left to right
    platforms.push({ x: 120, y: 380, width: 700, height: 20, slope: -0.02, color: '#FF69B4' });
    
    // Platform 5 - slanted down left to right  
    platforms.push({ x: 20, y: 300, width: 700, height: 20, slope: 0.02, color: '#FF69B4' });
    
    // Platform 6 - slanted up left to right
    platforms.push({ x: 120, y: 220, width: 600, height: 20, slope: -0.02, color: '#FF69B4' });
    
    // Top platform (Donkey Kong's platform) - flat
    platforms.push({ x: 250, y: 180, width: 450, height: 20, slope: 0, color: '#FF0000' });
    
    return platforms;
  }

  generateElevatorLevel() {
    // Level 2: Elevator level with moving platforms and conveyor belts
    const platforms = [];
    
    // Bottom platform
    platforms.push({ x: 20, y: 620, width: 860, height: 20, slope: 0, color: '#4169E1' });
    
    // Conveyor belt platforms (will add movement logic later)
    platforms.push({ x: 150, y: 520, width: 200, height: 20, slope: 0, color: '#FFD700' });
    platforms.push({ x: 550, y: 520, width: 200, height: 20, slope: 0, color: '#FFD700' });
    
    // Middle platforms
    platforms.push({ x: 50, y: 420, width: 300, height: 20, slope: 0, color: '#4169E1' });
    platforms.push({ x: 550, y: 420, width: 300, height: 20, slope: 0, color: '#4169E1' });
    
    // Upper platforms
    platforms.push({ x: 200, y: 320, width: 500, height: 20, slope: 0, color: '#4169E1' });
    
    // Top platform
    platforms.push({ x: 250, y: 180, width: 400, height: 20, slope: 0, color: '#FF0000' });
    
    return platforms;
  }

  generateBossLevel() {
    // Level 3: Final boss confrontation level
    const platforms = [];
    
    // Simple boss level layout
    platforms.push({ x: 50, y: 620, width: 800, height: 20, slope: 0, color: '#000000' });
    platforms.push({ x: 200, y: 500, width: 500, height: 20, slope: 0, color: '#000000' });
    platforms.push({ x: 150, y: 380, width: 600, height: 20, slope: 0, color: '#000000' });
    platforms.push({ x: 250, y: 260, width: 400, height: 20, slope: 0, color: '#000000' });
    platforms.push({ x: 300, y: 180, width: 300, height: 20, slope: 0, color: '#FF0000' });
    
    return platforms;
  }

  generateLadders() {
    const ladders = [];
    
    // SIMPLE WORKING LADDERS matching the new simple platform coordinates
    // Platform positions: Ground=620, L2=540, L3=460, L4=380, L5=300, Top=180
    
    // Ground (y=620) to Level 2 (y=540) - right side 
    ladders.push({
      x: 750,  // Right side for classic DK alternating pattern
      y: 540,
      width: 16, 
      height: 80, // 620 - 540 = 80
      type: 'full'
    });
    
    // Level 2 (y=540) to Level 3 (y=460) - left side
    ladders.push({
      x: 80,   // Left side 
      y: 460,
      width: 16,
      height: 80, // 540 - 460 = 80
      type: 'full'
    });
    
    // Level 3 (y=460) to Level 4 (y=380) - right side
    ladders.push({
      x: 750,  // Right side
      y: 380,
      width: 16,
      height: 80, // 460 - 380 = 80
      type: 'full'
    });
    
    // Level 4 (y=380) to Level 5 (y=300) - left side  
    ladders.push({
      x: 80,   // Left side
      y: 300,
      width: 16,
      height: 80, // 380 - 300 = 80
      type: 'full'
    });
    
    // Level 5 (y=300) to Top (y=180) - center
    ladders.push({
      x: 400,  // Center ladder to top platform
      y: 180,
      width: 16,
      height: 120, // 300 - 180 = 120
      type: 'full'
    });
    
    console.log(`✅ Generated ${ladders.length} simple ladders`);
    return ladders;
  }

  generateHammers() {
    const hammers = [];
    
    // Hammer on Level 3 (y=460) - account for slope 
    // Platform 3: x=20, y=460, width=700, slope=0.02
    const level3Platform = { x: 20, y: 460, slope: 0.02 };
    const hammerX = 300;
    const relativeX = hammerX - level3Platform.x;
    const slopedY = level3Platform.y + (relativeX * level3Platform.slope);
    hammers.push({
      x: hammerX,
      y: slopedY - 12, // Position on sloped surface
      width: 16,
      height: 12,
      collected: false,
      sparkle: 0
    });
    
    // Hammer on Level 5 (y=300) - account for slope  
    // Platform 5: x=20, y=300, width=700, slope=0.02
    const level5Platform = { x: 20, y: 300, slope: 0.02 };
    const hammerX2 = 400;
    const relativeX2 = hammerX2 - level5Platform.x;
    const slopedY2 = level5Platform.y + (relativeX2 * level5Platform.slope);
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
    
    // Play authentic intro sound and start background music
    this.sounds.intro();
    setTimeout(() => {
      this.sounds.backgroundMusic(); // Start background music after intro
    }, 500);
    
    if (this.startButton) this.startButton.disabled = true;
    if (this.pauseButton) this.pauseButton.disabled = false;
    if (this.gameOverElement) this.gameOverElement.classList.add('game-over-hidden');
    
    // CRITICAL DEBUG: Show current player and platform state
    console.log('🎮 GAME: Game started successfully, gameState:', this.gameState);
    console.log('🎮 CRITICAL DEBUG: Player positioning check...');
    this.debugPlayerPlatform();
  }
  
  togglePause() {
    if (this.gameState === 'playing') {
      this.gameState = 'paused';
      if (this.pauseButton) this.pauseButton.textContent = 'Resume';
      // Pause background music
      if (this.audioElements.bacmusic) {
        this.audioElements.bacmusic.pause();
      }
    } else if (this.gameState === 'paused') {
      this.gameState = 'playing';
      if (this.pauseButton) this.pauseButton.textContent = 'Pause';
      // Resume background music
      if (this.audioElements.bacmusic) {
        this.audioElements.bacmusic.play().catch(e => console.log('Background music resume failed:', e.name));
      }
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
    this.player.alive = true; // Reset Mario to alive
    this.player.deathTimer = undefined; // Clear death animation
    this.player.deathPhase = undefined; // Clear death phase
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
        this.level++;
        this.advanceToNextLevel();
        this.resetHammers();
        
        // Progressive difficulty
        this.barrelSpawnRate = Math.max(50, this.barrelSpawnRate - 8);
      }
      return;
    }
    
    this.frameCounter++;
    
    // Handle death animation sequence
    if (!this.player.alive && this.player.deathTimer !== undefined) {
      this.player.deathTimer++;
      
      if (this.player.deathPhase === 'tumbling') {
        // Apply physics during tumbling - Mario falls to ground (slower)
        this.player.x += this.player.vx;
        this.player.y += this.player.vy;
        this.player.vy += 0.2; // Slower gravity for more dramatic fall
        
        // Check if Mario hits the bottom platform (around y=620)
        const bottomPlatformY = 620;
        if (this.player.y >= bottomPlatformY - this.player.height) {
          // Hit the bottom platform - stop tumbling and become angel
          this.player.y = bottomPlatformY - this.player.height;
          this.player.vx = 0;
          this.player.vy = 0;
          this.player.deathPhase = 'dead';
          this.player.deathTimer = 0; // Reset timer for dead phase
        } else if (this.player.deathTimer > 120) {
          // Failsafe: if tumbling too long, force to dead phase
          this.player.deathPhase = 'dead';
          this.player.deathTimer = 0;
        }
      } else if (this.player.deathPhase === 'dead') {
        // Dead with halo phase: hold much longer for dramatic effect
        if (this.player.deathTimer > 120) { // Extended from 60 to 120 frames (2 full seconds)
          this.player.deathPhase = 'floating';
          this.player.deathTimer = 0; // Reset timer for floating phase
        }
      } else if (this.player.deathPhase === 'floating') {
        // Floating phase: slower float up and disappear
        if (this.player.deathTimer > 120) { // Extended from 60 to 120 frames (2 seconds)
          // Animation complete
          this.player.deathTimer = undefined;
          this.player.deathPhase = undefined;
        }
      }
      
      return; // Skip other player updates during death
    }
    
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
        this.sounds.jumpOverBarrel(); // Authentic jump over barrel sound
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
    
    // Boss fight mechanics for Level 3
    if (this.level === 3 && this.bossMode && this.player.hasHammer) {
      // Check if player can hit Kong with hammer
      const hammerReach = 40; // Extended reach for hammer attack
      const distanceToKong = Math.sqrt(
        Math.pow(this.player.x - this.honkyKong.x, 2) + 
        Math.pow(this.player.y - this.honkyKong.y, 2)
      );
      
      if (distanceToKong <= hammerReach && this.player.hammerTimer % 30 === 0) {
        // Hit Kong with hammer (only once per hammer swing cycle)
        if (!this.kongHitThisSwing) {
          this.kongHealth--;
          this.kongHitThisSwing = true;
          this.score += 1000; // Big points for hitting Kong
          
          // Massive explosion particles
          this.createParticles(this.honkyKong.x + 24, this.honkyKong.y + 20, 20, '#FF0000', 'explosion');
          this.createParticles(this.honkyKong.x + 24, this.honkyKong.y + 20, 15, '#FFFF00', 'spark');
          
          this.sounds.barrel(); // Kong hit sound
          this.updateUI();
          
          // Check if Kong is defeated
          if (this.kongHealth <= 0) {
            this.bossDefeated();
            return;
          }
        }
      } else {
        this.kongHitThisSwing = false; // Reset for next swing cycle
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
        
        // Apply conveyor belt movement for Level 2
        if (platform.conveyor && this.level === 2) {
          if (platform.conveyor === 'left') {
            this.player.x -= this.conveyorSpeed || 1;
          } else if (platform.conveyor === 'right') {
            this.player.x += this.conveyorSpeed || 1;
          }
        }
        
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
    
    // Start death animation sequence: tumbling → dead with halo → float up
    this.player.alive = false;
    this.player.deathTimer = 0;
    this.player.deathPhase = 'tumbling'; // tumbling, dead, floating
    this.player.vx = this.player.direction * 0.5; // Small horizontal drift while tumbling
    this.player.vy = 0; // Will start falling due to gravity
    
    this.updateUI();
    
    // Start death animation - will complete in update loop
    setTimeout(() => {
      if (this.lives <= 0) {
        this.gameOver();
      } else {
        this.resetLevel();
      }
    }, 2000); // 2 second death animation
  }
  
  levelComplete() {
    this.score += this.bonus; // Time bonus
    this.score += 3000; // Level completion bonus
    this.level++;
    this.sounds.levelComplete();
    
    // Play bonus sound for high score achievement
    if (this.bonus > 3000) {
      setTimeout(() => {
        this.sounds.howhigh(); // High bonus sound
      }, 800);
    }
    
    // Progress to next level type
    this.advanceToNextLevel();
    
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
    
    // Stop background music on game over
    this.stopSound('bacmusic');
    
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
        
        // Main girder body - use authentic colors
        this.ctx.fillStyle = platform.color || '#F24A8D'; // Authentic girder color
        this.ctx.fill();
        
        // Shadow
        this.ctx.fillStyle = platform.color === '#1F55FF' ? '#0F2F9F' : '#B03064'; // Authentic shadow colors
        this.ctx.beginPath();
        this.ctx.moveTo(platform.x, platform.y + platform.height - 3);
        this.ctx.lineTo(platform.x + platform.width, platform.y + slopeOffset + platform.height - 3);
        this.ctx.lineTo(platform.x + platform.width, platform.y + slopeOffset + platform.height);
        this.ctx.lineTo(platform.x, platform.y + platform.height);
        this.ctx.closePath();
        this.ctx.fill();
      } else {
        // Flat platform - use authentic colors
        this.ctx.fillStyle = platform.color || '#F24A8D'; // Authentic girder color
        this.ctx.fillRect(platform.x, platform.y, platform.width, platform.height);
        
        // Shadow
        this.ctx.fillStyle = platform.color === '#1F55FF' ? '#0F2F9F' : '#B03064'; // Authentic shadow colors
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
    
    // Don't draw Kong if he's defeated
    if (kong.defeated) {
      // Show victory particles instead
      if (kong.defeatTimer !== undefined) {
        kong.defeatTimer++;
        if (kong.defeatTimer % 10 === 0) {
          this.createParticles(kong.x + 24, kong.y + 20, 3, '#FFD700', 'victory');
        }
      }
      return;
    }
    
    let state = 'normal';
    
    // Determine sprite state based on Kong's status
    if (kong.animation > 0) {
      state = 'throwing';
    } else if (kong.beating) {
      state = 'beating';
    }
    
    // In boss mode (Level 3), show Kong's health
    if (this.level === 3 && this.bossMode) {
      // Draw Kong health indicator
      this.ctx.fillStyle = '#FF0000';
      this.ctx.fillRect(kong.x, kong.y - 15, 48, 8);
      this.ctx.fillStyle = '#00FF00';
      this.ctx.fillRect(kong.x + 2, kong.y - 13, (44 * this.kongHealth / 3), 4);
      
      // Show "BOSS" label
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.font = 'bold 12px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.fillText('BOSS', kong.x + 24, kong.y - 20);
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
    let state = 'right'; // Default state
    
    // Determine sprite state based on player status and direction
    if (!player.alive) {
      if (player.deathPhase === 'tumbling') {
        // Cycle through tumbling animation frames - slower animation
        const tumbleFrame = Math.floor(player.deathTimer / 15) % 8; // Changed from 8 to 15 frames per sprite
        state = `tumble-${tumbleFrame + 1}`;
      } else {
        // Dead Mario with floating halo (dead or floating phase)
        state = player.direction < 0 ? 'dead-left' : 'dead-right';
      }
    } else if (player.hasHammer) {
      // Cycle through all 4 hammer animation frames for each direction
      const hammerFrame = Math.floor(this.frameCounter / 12) % 4; // Slower animation, 12 frames per sprite
      
      if (player.direction < 0) {
        // Left-facing hammer animation: up1 -> down1 -> up2 -> down2
        switch (hammerFrame) {
          case 0: state = 'hammer-left-up-1'; break;
          case 1: state = 'hammer-left-down-1'; break;
          case 2: state = 'hammer-left-up-2'; break;
          case 3: state = 'hammer-left-down-2'; break;
        }
      } else {
        // Right-facing hammer animation: down1 -> up1 -> down2 -> up2
        switch (hammerFrame) {
          case 0: state = 'hammer-right-down-1'; break;
          case 1: state = 'hammer-right-up-1'; break;
          case 2: state = 'hammer-right-down-2'; break;
          case 3: state = 'hammer-right-up-2'; break;
        }
      }
    } else if (player.climbingLadder) {
      // Cycle through climbing animation frames (8 frames total)
      const climbFrame = Math.floor(this.frameCounter / 8) % 8;
      switch (climbFrame) {
        case 0: state = 'climb-bottom'; break;
        case 1: state = 'climb-1'; break;
        case 2: state = 'climb-2'; break;
        case 3: state = 'climb-3'; break;
        case 4: state = 'climb-4'; break;
        case 5: state = 'climb-5'; break;
        case 6: state = 'climb-6'; break;
        case 7: state = 'climb-top'; break;
        default: state = 'climb-1';
      }
    } else {
      // Running or standing based on movement and direction
      const isMoving = Math.abs(player.vx) > 0.1;
      
      if (player.direction < 0) {
        if (isMoving) {
          // Alternate between run frames for animation (every 10 frames)
          const runFrame = Math.floor(this.frameCounter / 10) % 2;
          state = runFrame === 0 ? 'run-left-1' : 'run-left-2';
        } else {
          state = 'stand-left';
        }
      } else {
        if (isMoving) {
          // Alternate between run frames for animation (every 10 frames)
          const runFrame = Math.floor(this.frameCounter / 10) % 2;
          state = runFrame === 0 ? 'run-right-1' : 'run-right-2';
        } else {
          state = 'stand-right';
        }
      }
    }
    
    // Render sprite (no more mirroring since we have directional sprites)
    this.ctx.save();
    
    // Handle death animation positioning
    let renderY = player.y;
    if (!player.alive && player.deathTimer !== undefined) {
      if (player.deathPhase === 'floating') {
        // Only float upward during the floating phase - slower and more graceful
        renderY -= player.deathTimer * 1.5; // Slower float upward (reduced from 3 to 1.5)
      }
      // Tumbling and dead phases stay at ground level
    }
    
    // Adjust Y position for hammer sprites to keep Mario at same ground level
    if (state.includes('hammer')) {
      if (state.includes('up')) {
        // VR sprites are taller (40px vs 16px), so move up less to keep feet grounded
        renderY -= 8; // Reduced adjustment - lets hammer extend up naturally
      } else {
        // HR sprites are different height (25px vs 16px), adjust slightly
        renderY -= 5; // Small adjustment for hammer-down sprites
      }
    }
    
    this.sprites.mario(player.x, renderY, state);
    
    // Hammer expiration warning - draw warning glow around Mario
    if (player.hasHammer && player.hammerTimer >= 600) { // Last 5 seconds (900 - 300 = 600)
      const pulseIntensity = Math.sin(this.frameCounter * 0.3) * 0.5 + 0.5; // Smooth pulsing
      const glowColor = `rgba(255, 255, 0, ${pulseIntensity * 0.4})`; // Yellow glow
      
      // Draw glow rings around Mario
      this.ctx.strokeStyle = glowColor;
      this.ctx.lineWidth = 2;
      this.ctx.beginPath();
      this.ctx.arc(player.x + player.width/2, renderY + player.height/2, 20 + pulseIntensity * 5, 0, Math.PI * 2);
      this.ctx.stroke();
      
      this.ctx.beginPath();
      this.ctx.arc(player.x + player.width/2, renderY + player.height/2, 25 + pulseIntensity * 8, 0, Math.PI * 2);
      this.ctx.stroke();
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
      // Try to draw authentic barrel sprite first
      let spriteDrawn = false;
      
      if (this.allSpritesLoaded) {
        // Barrel sprites from enemies.png (top row has barrels)
        const rotationFrame = Math.floor(barrel.rotation * 4 / (Math.PI * 2)) % 4;
        const sx = rotationFrame * 16; // Each barrel frame is 16px wide
        const sy = 0; // Top row
        
        spriteDrawn = this.drawSprite('enemies', sx, sy, 16, 16, barrel.x, barrel.y, barrel.width, barrel.height);
      }
      
      // Fallback to drawn sprite if needed
      if (!spriteDrawn) {
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
      } // Close fallback drawing
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
      
      if (this.level === 4 && this.honkyKong.defeated) {
        // Boss defeated - ultimate victory message
        this.ctx.fillText(`🏆 KONG DEFEATED! GAME COMPLETE! 🏆`, this.canvas.width / 2, this.canvas.height / 2 + 30);
        this.ctx.fillText(`⭐ VICTORY BONUS: ${this.bonus} points! ⭐`, this.canvas.width / 2, this.canvas.height / 2 + 60);
      } else {
        // Normal level completion
        this.ctx.fillText(`🎉 LEVEL ${this.level - 1} COMPLETE! 🎉`, this.canvas.width / 2, this.canvas.height / 2 + 30);
        this.ctx.fillText(`⭐ BONUS: ${this.bonus} points! ⭐`, this.canvas.width / 2, this.canvas.height / 2 + 60);
      }
      
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
  
  // SIMPLE WORKING DONKEY KONG PLATFORMS - Based on GROK pseudocode
  generateLevelPlatforms(levelType) {
    console.log('🔥 CLAUDE SIMPLE PLATFORMS FUNCTION CALLED! Level:', levelType);
    
    // Canvas dimensions: 900x700, using classic DK proportions
    const platforms = [];
    
    switch(levelType % 4) {
      case 1:
      default:
        // Level 1: Classic barrel level with 6 sloped girders
        // Using canvas coordinates where y=0 is top
        
        // Bottom platform (ground) - flat
        platforms.push({
          x: 20, y: 620, width: 860, height: 20, 
          slope: 0, color: '#F24A8D'
        });
        
        // Second girder - sloped up from left to right
        platforms.push({
          x: 120, y: 540, width: 700, height: 20, 
          slope: -0.02, color: '#F24A8D'  // Negative slope = up left to right
        });
        
        // Third girder - sloped down from left to right  
        platforms.push({
          x: 20, y: 460, width: 700, height: 20, 
          slope: 0.02, color: '#F24A8D'   // Positive slope = down left to right
        });
        
        // Fourth girder - sloped up from left to right
        platforms.push({
          x: 120, y: 380, width: 700, height: 20, 
          slope: -0.02, color: '#F24A8D'
        });
        
        // Fifth girder - sloped down from left to right
        platforms.push({
          x: 20, y: 300, width: 700, height: 20, 
          slope: 0.02, color: '#F24A8D'
        });
        
        // Top platform (DK's platform) - flat
        platforms.push({
          x: 250, y: 180, width: 450, height: 20, 
          slope: 0, color: '#FF0000'  // Red for DK platform
        });
        
        break;
    }
    
    console.log(`✅ Generated ${platforms.length} simple platforms for level ${levelType}`);
    return platforms;
  }
  
  // Authentic Donkey Kong Level Data (from specification)
  getAuthenticLevelData(levelNumber) {
    const levelPackage = {
      "meta": {
        "tileSizePx": 8,
        "cols": 32,
        "rows": 28,
        "palette": {
          "girder": "#F24A8D",
          "girderShadow": "#B03064",
          "bluePlatform": "#1F55FF",
          "ladder": "#36E2FF",
          "ladderRung": "#FFD048",
          "rivet": "#FFD048",
          "elevator": "#F0B600",
          "barrel": "#8B5A2B",
          "oil": "#5B3A16",
          "bg": "#000000"
        }
      },
      "levels": [
        {
          "name": "Level 1 — Girders & Barrels",
          "paletteHint": "girders",
          "segments": [
            { "x": 1,  "y": 26, "len": 30, "slope": "flat",       "step": 0  },
            { "x": 4,  "y": 22, "len": 24, "slope": "down_right", "step": 8  },
            { "x": 1,  "y": 18, "len": 24, "slope": "down_left",  "step": 8  },
            { "x": 4,  "y": 14, "len": 24, "slope": "down_right", "step": 8  },
            { "x": 1,  "y": 10, "len": 24, "slope": "down_left",  "step": 8  },
            { "x": 8,  "y": 6,  "len": 16, "slope": "flat",       "step": 0  }
          ],
          "ladders": [
            { "x": 26, "yTop": 22, "yBottom": 26, "brokenTop": 0 },
            { "x": 3,  "yTop": 18, "yBottom": 22, "brokenTop": 0 },
            { "x": 26, "yTop": 14, "yBottom": 18, "brokenTop": 0 },
            { "x": 3,  "yTop": 10, "yBottom": 14, "brokenTop": 0 },
            { "x": 6,  "yTop": 6,  "yBottom": 10, "brokenTop": 0 }
          ],
          "objects": {
            "S": { "x": 2,  "y": 25 },
            "K": { "x": 10, "y": 5  },
            "P": { "x": 20, "y": 5  },
            "B": { "x": 8,  "y": 5  },
            "O": { "x": 1,  "y": 26 },
            "H": [ { "x": 12, "y": 13 }, { "x": 12, "y": 17 } ]
          }
        },
        {
          "name": "Level 2 — Elevators",
          "paletteHint": "elevators",
          "segments": [
            { "x": 2,  "y": 25, "len": 28, "slope": "flat", "step": 0 },
            { "x": 3,  "y": 19, "len": 8,  "slope": "flat", "step": 0 },
            { "x": 21, "y": 19, "len": 8,  "slope": "flat", "step": 0 },
            { "x": 12, "y": 13, "len": 8,  "slope": "flat", "step": 0 },
            { "x": 3,  "y": 7,  "len": 8,  "slope": "flat", "step": 0 },
            { "x": 21, "y": 7,  "len": 8,  "slope": "flat", "step": 0 }
          ],
          "ladders": [
            { "x": 7,  "yTop": 6,  "yBottom": 19, "brokenTop": 0 },
            { "x": 24, "yTop": 6,  "yBottom": 19, "brokenTop": 0 },
            { "x": 16, "yTop": 12, "yBottom": 19, "brokenTop": 0 }
          ],
          "elevators": [
            { "x": 10, "yTop": 6,  "yBottom": 24, "speedTilesPerSec": 2.0, "dir": "down" },
            { "x": 14, "yTop": 6,  "yBottom": 24, "speedTilesPerSec": 2.0, "dir": "up"   },
            { "x": 18, "yTop": 6,  "yBottom": 24, "speedTilesPerSec": 2.0, "dir": "down" },
            { "x": 22, "yTop": 6,  "yBottom": 24, "speedTilesPerSec": 2.0, "dir": "up"   }
          ],
          "objects": {
            "S": { "x": 2,  "y": 24 },
            "K": { "x": 23, "y": 6  },
            "P": { "x": 6,  "y": 6  },
            "B": { "x": 22, "y": 6  },
            "O": { "x": 28, "y": 25 },
            "H": [ { "x": 13, "y": 12 } ]
          }
        },
        {
          "name": "Level 3 — Rivets",
          "paletteHint": "rivets",
          "segments": [
            { "x": 2,  "y": 25, "len": 28, "slope": "flat", "step": 0 },
            { "x": 2,  "y": 19, "len": 28, "slope": "flat", "step": 0 },
            { "x": 2,  "y": 13, "len": 28, "slope": "flat", "step": 0 },
            { "x": 2,  "y": 7,  "len": 28, "slope": "flat", "step": 0 }
          ],
          "ladders": [
            { "x": 6,  "yTop": 6,  "yBottom": 25, "brokenTop": 0 },
            { "x": 16, "yTop": 6,  "yBottom": 25, "brokenTop": 0 },
            { "x": 26, "yTop": 6,  "yBottom": 25, "brokenTop": 0 }
          ],
          "rivets": [
            { "x": 3,  "y": 25 }, { "x": 29, "y": 25 },
            { "x": 3,  "y": 19 }, { "x": 29, "y": 19 },
            { "x": 3,  "y": 13 }, { "x": 29, "y": 13 },
            { "x": 3,  "y": 7  }, { "x": 29, "y": 7  }
          ],
          "objects": {
            "S": { "x": 2,  "y": 24 },
            "K": { "x": 16, "y": 5  },
            "P": { "x": 16, "y": 3  },
            "H": [ { "x": 11, "y": 18 }, { "x": 21, "y": 18 } ]
          }
        }
      ]
    };
    
    return levelPackage.levels[levelNumber - 1];
  }
  
  // Build Algorithm (deterministic) - following specification exactly
  buildPlatformsFromLevelData(levelData) {
    console.log(`🎮 Building authentic ${levelData.name}`);
    
    // Step 1: Create empty 32×28 char grid filled with "."
    const grid = Array(28).fill(null).map(() => Array(32).fill('.'));
    
    // Step 2: For each "segment" - generate platform tiles
    for (const segment of levelData.segments) {
      let curX = segment.x;
      let curY = segment.y;
      
      for (let i = 0; i < segment.len; i++) {
        // Bounds check
        if (curX >= 0 && curX < 32 && curY >= 0 && curY < 28) {
          // tileType = ("=" if paletteHint=="rivets" else "#")
          const tileType = (levelData.paletteHint === "rivets") ? "=" : "#";
          grid[curY][curX] = tileType;
        }
        
        // Apply slope every "step" tiles
        if (segment.step > 0 && i > 0 && (i % segment.step === 0)) {
          if (segment.slope === "down_right") {
            curY = Math.min(curY + 1, 27);
          } else if (segment.slope === "down_left") {
            curY = Math.max(curY - 1, 0);
          }
        }
        
        curX += 1;
        if (curX >= 32) break; // Don't exceed grid bounds
      }
    }
    
    // Step 3: For each ladder
    for (const ladder of levelData.ladders) {
      const x = ladder.x;
      
      // Draw ladder body
      for (let y = ladder.yTop; y <= ladder.yBottom; y++) {
        if (x >= 0 && x < 32 && y >= 0 && y < 28) {
          grid[y][x] = "|";
        }
      }
      
      // Set ladder top cap
      if (ladder.yTop >= 0 && ladder.yTop < 28 && x >= 0 && x < 32) {
        grid[ladder.yTop][x] = "T";
      }
      
      // Handle broken top ladders
      if (ladder.brokenTop > 0) {
        for (let k = 0; k < ladder.brokenTop; k++) {
          const brokenY = ladder.yTop + k;
          if (brokenY >= 0 && brokenY < 28 && x >= 0 && x < 32) {
            grid[brokenY][x] = ".";
          }
        }
      }
    }
    
    // Step 6: Place rivets (level 3 only)
    if (levelData.rivets) {
      for (const rivet of levelData.rivets) {
        if (rivet.x >= 0 && rivet.x < 32 && rivet.y >= 0 && rivet.y < 28) {
          grid[rivet.y][rivet.x] = "R";
        }
      }
    }
    
    // Debug: Print the generated grid
    console.log(`🎮 ${levelData.name} Grid:`);
    grid.forEach((row, y) => {
      const rowStr = row.join('');
      console.log(`Row ${y.toString().padStart(2)}: ${rowStr}`);
    });
    
    // Convert the authentic grid to game platforms
    return this.convertAuthenticGridToPlatforms(grid, levelData);
  }
  
  // Convert authentic DK grid to game platforms
  convertAuthenticGridToPlatforms(grid, levelData) {
    const platforms = [];
    const tileSize = 8; // Authentic 8px tiles
    const gameWidth = 900;
    const gameHeight = 700;
    const cols = 32;
    const rows = 28;
    
    // Scale factors to fit 32×28 grid into game canvas
    const scaleX = gameWidth / (cols * tileSize);
    const scaleY = gameHeight / (rows * tileSize);
    
    console.log(`🎮 Converting ${cols}×${rows} authentic grid to ${gameWidth}×${gameHeight} canvas`);
    console.log(`🎮 Scale factors: ${scaleX.toFixed(2)}x horizontal, ${scaleY.toFixed(2)}x vertical`);
    
    // CRITICAL: Ensure platforms are visible by adding debug rectangles
    console.log(`🎮 Canvas dimensions: ${this.canvas.width}x${this.canvas.height}`);
    console.log(`🎮 Game area: ${gameWidth}x${gameHeight}`);
    
    // Scan for platform segments (# and = tiles)
    for (let y = 0; y < rows; y++) {
      let platformStart = -1;
      let platformType = null;
      
      for (let x = 0; x <= cols; x++) {
        const tile = (x < cols) ? grid[y][x] : '.';
        const isPlat = (tile === '#' || tile === '=');
        
        if (isPlat && platformStart === -1) {
          platformStart = x;
          platformType = tile;
        } else if (!isPlat && platformStart !== -1) {
          // End of platform segment - create platform
          const worldX = platformStart * tileSize * scaleX;
          const worldY = y * tileSize * scaleY;
          const width = (x - platformStart) * tileSize * scaleX;
          const height = tileSize * scaleY * 1.5; // Slightly thicker for better collision
          
          // Determine slope based on segment data
          let slope = 0;
          const segment = this.findSegmentForPosition(levelData.segments, platformStart, y);
          if (segment) {
            if (segment.slope === "down_right") slope = 0.02;
            else if (segment.slope === "down_left") slope = -0.02;
          }
          
          // Color based on platform type and palette
          let color = '#F24A8D'; // Authentic girder color
          if (platformType === '=') {
            color = '#1F55FF'; // Authentic blue platform color
          }
          
          console.log(`🎮 Platform: x=${worldX.toFixed(1)}, y=${worldY.toFixed(1)}, w=${width.toFixed(1)}, slope=${slope.toFixed(3)}, type=${platformType}`);
          
          platforms.push({
            x: worldX,
            y: worldY,
            width: width,
            height: height,
            color: color,
            slope: slope,
            type: platformType
          });
          
          platformStart = -1;
          platformType = null;
        }
      }
    }
    
    console.log(`🎮 Generated ${platforms.length} authentic platforms`);
    return platforms;
  }
  
  // Helper to find the segment that generated a platform tile
  findSegmentForPosition(segments, x, y) {
    for (const segment of segments) {
      let curX = segment.x;
      let curY = segment.y;
      
      for (let i = 0; i < segment.len; i++) {
        if (curX === x && curY === y) {
          return segment;
        }
        
        if (segment.step > 0 && i > 0 && (i % segment.step === 0)) {
          if (segment.slope === "down_right") curY = Math.min(curY + 1, 27);
          else if (segment.slope === "down_left") curY = Math.max(curY - 1, 0);
        }
        
        curX += 1;
        if (curX >= 32) break;
      }
    }
    return null;
  }
  
  // Extract object positions from authentic level data
  extractObjectPositions(levelData) {
    const positions = {};
    const tileSize = 8;
    const gameWidth = 900;
    const gameHeight = 700;
    const cols = 32;
    const rows = 28;
    
    // Scale factors
    const scaleX = gameWidth / (cols * tileSize);
    const scaleY = gameHeight / (rows * tileSize);
    
    if (levelData.objects) {
      const objects = levelData.objects;
      
      // Player start position (S)
      if (objects.S) {
        positions.player = {
          x: objects.S.x * tileSize * scaleX,
          y: objects.S.y * tileSize * scaleY
        };
      }
      
      // Kong position (K)
      if (objects.K) {
        positions.kong = {
          x: objects.K.x * tileSize * scaleX,
          y: objects.K.y * tileSize * scaleY
        };
      }
      
      // Princess position (P)
      if (objects.P) {
        positions.princess = {
          x: objects.P.x * tileSize * scaleX,
          y: objects.P.y * tileSize * scaleY
        };
      }
      
      // Hammer positions (H) - array
      if (objects.H && Array.isArray(objects.H)) {
        positions.hammers = objects.H.map(hammer => ({
          x: hammer.x * tileSize * scaleX,
          y: (hammer.y - 1) * tileSize * scaleY // Hammers float 1 tile above platform
        }));
      }
      
      // Barrel spawner (B)
      if (objects.B) {
        positions.barrelSpawn = {
          x: objects.B.x * tileSize * scaleX,
          y: objects.B.y * tileSize * scaleY
        };
      }
      
      // Oil drum (O)
      if (objects.O) {
        positions.oilDrum = {
          x: objects.O.x * tileSize * scaleX,
          y: objects.O.y * tileSize * scaleY
        };
      }
      
      console.log(`🎮 Extracted authentic object positions:`, Object.keys(positions));
    }
    
    return positions;
  }
  
  // Debug method to check player-platform alignment
  debugPlayerPlatform() {
    console.log(`🎮 DEBUG: Player at (${this.player.x}, ${this.player.y}), size: ${this.player.width}x${this.player.height}`);
    console.log(`🎮 DEBUG: Found ${this.platforms.length} platforms:`);
    
    for (let i = 0; i < this.platforms.length; i++) {
      const p = this.platforms[i];
      console.log(`  Platform ${i}: (${p.x.toFixed(1)}, ${p.y.toFixed(1)}) ${p.width.toFixed(1)}x${p.height.toFixed(1)} slope:${p.slope.toFixed(3)}`);
      
      // Check if player is near this platform
      const distance = Math.abs(this.player.y + this.player.height - p.y);
      if (distance < 50) {
        console.log(`    ⚠️ Player is ${distance.toFixed(1)}px from this platform`);
      }
    }
    
    console.log(`🎮 DEBUG: Found ${this.ladders.length} ladders:`);
    for (let i = 0; i < this.ladders.length; i++) {
      const l = this.ladders[i];
      console.log(`  Ladder ${i}: (${l.x.toFixed(1)}, ${l.y.toFixed(1)}) ${l.width.toFixed(1)}x${l.height.toFixed(1)}`);
    }
  }
  
  // Sprite-based level data extraction (legacy - now unused)
  getLevelDataFromSprites(levelNumber) {
    if (!this.spriteSheets.levels) {
      console.warn('Level sprite sheet not loaded, using fallback data');
      return this.getFallbackLevelData(levelNumber);
    }
    
    try {
      // Analyze the levels sprite sheet to extract authentic level data
      return this.analyzeLevelSprite(levelNumber);
    } catch (error) {
      console.warn('Sprite analysis failed, using fallback:', error);
      return this.getFallbackLevelData(levelNumber);
    }
  }
  
  analyzeLevelSprite(levelNumber) {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    const sprite = this.spriteSheets.levels;
    
    // Authentic Donkey Kong levels from sprite sheet analysis
    // The sprite sheet might have levels arranged differently
    const spriteWidth = sprite.width;
    const spriteHeight = sprite.height;
    
    console.log(`🎮 Full sprite sheet dimensions: ${spriteWidth}x${spriteHeight}`);
    
    // Try different level extraction strategies
    let levelWidth, levelHeight, startX;
    
    if (spriteWidth > spriteHeight * 2) {
      // Horizontal layout - levels side by side
      levelWidth = Math.floor(spriteWidth / 3);
      levelHeight = spriteHeight;
      startX = (levelNumber - 1) * levelWidth;
      console.log(`🎮 Using horizontal layout: ${levelWidth}x${levelHeight} per level`);
    } else {
      // Vertical layout - levels stacked
      levelWidth = spriteWidth;
      levelHeight = Math.floor(spriteHeight / 3);
      startX = 0;
      console.log(`🎮 Using vertical layout: ${levelWidth}x${levelHeight} per level`);
    }
    
    canvas.width = levelWidth;
    canvas.height = levelHeight;
    
    // Optimize canvas for frequent pixel reading
    ctx.willReadFrequently = true;
    
    // Extract the specific level section based on layout
    let startY = 0;
    if (spriteWidth <= spriteHeight * 2) {
      // Vertical layout - adjust Y position
      startY = (levelNumber - 1) * levelHeight;
      console.log(`🎮 Extracting level from Y position: ${startY}`);
    }
    
    ctx.drawImage(sprite, startX, startY, levelWidth, levelHeight, 0, 0, levelWidth, levelHeight);
    
    // Debug: Save the extracted level image for inspection
    console.log(`🎮 Level ${levelNumber} extracted section dimensions: ${levelWidth}x${levelHeight} from position ${startX}`);
    console.log(`🎮 Level ${levelNumber} canvas data URL:`, canvas.toDataURL());
    
    // Convert to grid using tile analysis
    const grid = this.convertSpriteToGrid(ctx, levelWidth, levelHeight);
    
    // Debug output for level analysis
    console.log(`🎮 Level ${levelNumber} Grid Analysis:`);
    grid.forEach((row, i) => {
      console.log(`Row ${i.toString().padStart(2)}: ${row}`);
    });
    
    return {
      level: levelNumber,
      width: Math.floor(levelWidth / 16), // 16-pixel tiles
      height: Math.floor(levelHeight / 16),
      grid: grid
    };
  }
  
  convertSpriteToGrid(ctx, width, height) {
    // Authentic Donkey Kong uses 8x8 pixel tiles with 32-pixel cell scaling
    const tileSize = 8; // Authentic 8x8 tiles
    const cellSize = 32; // Screen cell size
    const gridWidth = Math.floor(width / cellSize);
    const gridHeight = Math.floor(height / cellSize);
    const grid = [];
    
    console.log(`🎮 Using authentic 8x8 tiles with ${cellSize}px cells for ${gridWidth}x${gridHeight} grid`);
    
    for (let y = 0; y < gridHeight; y++) {
      let row = '';
      for (let x = 0; x < gridWidth; x++) {
        const cellX = x * cellSize;
        const cellY = y * cellSize;
        
        // Sample multiple 8x8 tiles within each 32x32 cell for better detection
        const symbol = this.classifyCell(ctx, cellX, cellY, cellSize, tileSize);
        row += symbol;
      }
      grid.push(row);
    }
    
    return grid;
  }
  
  classifyCell(ctx, cellX, cellY, cellSize, tileSize) {
    let platformTiles = 0;
    let ladderTiles = 0;
    let emptyTiles = 0;
    let totalTiles = 0;
    
    // Sample 8x8 tiles within the 32x32 cell
    const tilesPerCell = cellSize / tileSize; // 4x4 tiles per cell
    
    for (let tY = 0; tY < tilesPerCell; tY++) {
      for (let tX = 0; tX < tilesPerCell; tX++) {
        const tileX = cellX + (tX * tileSize);
        const tileY = cellY + (tY * tileSize);
        
        if (tileX < ctx.canvas.width && tileY < ctx.canvas.height) {
          const imageData = ctx.getImageData(tileX, tileY, tileSize, tileSize);
          const tileType = this.classifyTile(imageData, tileX, tileY);
          
          totalTiles++;
          if (tileType === 'P') platformTiles++;
          else if (tileType === 'L') ladderTiles++;
          else emptyTiles++;
        }
      }
    }
    
    // Determine cell type based on dominant tile types
    if (platformTiles > totalTiles * 0.3) return 'P'; // Platform cell
    if (ladderTiles > totalTiles * 0.2) return 'L'; // Ladder cell
    
    // Check for special positions (Kong, Princess) based on location and content
    if (cellY < cellSize * 2) { // Top 2 rows
      if (cellX < ctx.canvas.width * 0.3) return 'K'; // Kong area (left)
      if (cellX > ctx.canvas.width * 0.7 && (platformTiles > 0 || ladderTiles > 0)) return 'G'; // Princess area (right)
    }
    
    return '.'; // Empty cell
  }
  
  classifyTile(imageData, tileX, tileY) {
    const pixels = imageData.data;
    let redCount = 0, blueCount = 0, yellowCount = 0, blackCount = 0, pinkCount = 0;
    let totalPixels = 0;
    
    // Analyze pixel colors in the tile
    for (let i = 0; i < pixels.length; i += 4) {
      const r = pixels[i];
      const g = pixels[i + 1]; 
      const b = pixels[i + 2];
      const a = pixels[i + 3];
      
      if (a > 128) { // Skip transparent pixels
        totalPixels++;
        
        // Classify based on dominant colors in Donkey Kong
        if (r > 200 && g < 100 && b < 100) redCount++;        // Red platforms
        else if (r < 100 && g < 100 && b > 200) blueCount++;  // Blue platforms  
        else if (r > 200 && g > 200 && b < 100) yellowCount++; // Yellow ladders/items
        else if (r > 200 && g < 150 && b > 150) pinkCount++;  // Pink platforms
        else if (r < 50 && g < 50 && b < 50) blackCount++;    // Black/empty
      }
    }
    
    if (totalPixels < 8) return '.'; // Mostly empty tile
    
    const redRatio = redCount / totalPixels;
    const blueRatio = blueCount / totalPixels;
    const yellowRatio = yellowCount / totalPixels;
    const pinkRatio = pinkCount / totalPixels;
    
    // More sensitive classification for better detection
    if (redRatio > 0.1 || pinkRatio > 0.1) return 'P'; // Platform (red or pink girders)
    if (blueRatio > 0.1) return 'P'; // Blue platforms (conveyor belts)
    if (yellowRatio > 0.05) return 'L'; // Yellow ladders (more sensitive)
    
    // Special position-based classification for characters
    if (tileY < 64 && (redRatio > 0.05 || pinkRatio > 0.05 || yellowRatio > 0.05)) {
      if (tileX < 128) return 'K'; // Kong area (top-left)
      else return 'G'; // Princess area (top-right)  
    }
    
    // Look for any significant color activity that might be missed
    if (totalPixels > 64 && (redRatio + blueRatio + yellowRatio + pinkRatio) > 0.1) {
      return 'P'; // Probably a platform we missed
    }
    
    return '.'; // Empty space
  }
  
  getFallbackLevelData(levelNumber) {
    // Authentic Donkey Kong level layouts as backup
    const fallbackLevels = {
      1: {
        level: 1,
        width: 16,
        height: 16,
        grid: [
          "....K...........",
          "PPPPPPPPPPPPPPP",
          "..........L.....",
          "PPPPPPP....PPPP",
          ".....L.........",
          "PPPP....PPPPPPP",
          "...L...........P",
          "PP....PPPPPPPPP",
          ".L.............",
          "PPPPPPPPPPPPPPP",
          "...............",
          ".........G....."
        ]
      },
      2: {
        level: 2,
        width: 16,
        height: 16,
        grid: [
          "....K...........",
          "PPPPPPPPPPPPPPP",
          "..L.......L....",
          "PPPPP.....PPPPP",
          "....L.....L....",
          "PPPPP.....PPPPP",
          "..L.......L....",
          "PPPPPPPPPPPPPPP",
          "...............",
          "PPPPPPPPPPPPPPP",
          "...............",
          ".........G....."
        ]
      },
      3: {
        level: 3,
        width: 16,
        height: 16,
        grid: [
          ".........G.....",
          "PPPPPPPPPPPPPPP",
          "......K........",
          "PPPPPPPPPPPPPPP",
          "..L.......L....",
          "PPP.......PPPPP",
          "..L.......L....",
          "PPPPPPPPPPPPPPP",
          "...............",
          "PPPPPPPPPPPPPPP",
          "...............",
          "PPPPPPPPPPPPPPP"
        ]
      }
    };
    
    return fallbackLevels[levelNumber] || fallbackLevels[1];
  }
  
  convertGridToPlatforms(grid) {
    const platforms = [];
    
    // Use authentic Donkey Kong proportions
    const gameWidth = 900;
    const gameHeight = 700;
    const gridWidth = grid[0].length;
    const gridHeight = grid.length;
    
    console.log(`🎮 Converting ${gridWidth}x${gridHeight} grid to platforms`);
    
    // Create platforms with authentic Donkey Kong slopes and positioning
    for (let y = 0; y < grid.length; y++) {
      let platformStart = -1;
      let slopeDirection = 0; // -1 = down-left, 0 = flat, 1 = down-right
      
      for (let x = 0; x <= grid[y].length; x++) {
        const isPlat = (x < grid[y].length && grid[y][x] === 'P');
        
        if (isPlat && platformStart === -1) {
          platformStart = x;
          
          // Detect slope direction based on authentic Donkey Kong level patterns
          if (y % 2 === 1 && y < gridHeight - 2) { // Sloped platforms in DK
            slopeDirection = (y % 4 === 1) ? -1 : 1; // Alternate slope directions
          }
        } else if (!isPlat && platformStart !== -1) {
          // Create platform with authentic positioning and slopes
          const baseX = (platformStart / gridWidth) * gameWidth;
          const baseY = (y / gridHeight) * gameHeight;
          const width = ((x - platformStart) / gridWidth) * gameWidth;
          const height = (1.2 / gridHeight) * gameHeight; // Slightly thicker platforms
          
          // Apply authentic Donkey Kong slope calculation
          let slope = 0;
          if (slopeDirection !== 0) {
            slope = slopeDirection * 0.03; // Gentle slope like original DK
          }
          
          // Color based on level (authentic DK colors)
          let color = '#FF69B4'; // Pink girders (level 1)
          if (this.level === 2) color = '#4169E1'; // Blue girders (level 2) 
          if (this.level === 3) color = '#8B4513'; // Brown girders (level 3)
          
          console.log(`🎮 Platform: x=${baseX.toFixed(1)}, y=${baseY.toFixed(1)}, w=${width.toFixed(1)}, slope=${slope.toFixed(3)}`);
          
          platforms.push({
            x: baseX,
            y: baseY,
            width: width,
            height: height,
            color: color,
            slope: slope // Add slope for authentic DK physics
          });
          
          platformStart = -1;
          slopeDirection = 0;
        }
      }
    }
    
    // Add bottom platform if missing (authentic DK always has bottom platform)
    if (platforms.length === 0 || platforms[platforms.length - 1].y < gameHeight - 100) {
      platforms.push({
        x: 0,
        y: gameHeight - 50,
        width: gameWidth,
        height: 50,
        color: '#FF69B4',
        slope: 0
      });
      console.log(`🎮 Added missing bottom platform`);
    }
    
    console.log(`🎮 Generated ${platforms.length} authentic DK platforms`);
    return platforms;
  }
  
  generateBarrelLevel() {
    // Level 1: Barrel Level (Classic sloped platforms)
    return [
      // Bottom platform (full width)
      { x: 0, y: 650, width: 900, height: 20, color: '#FF69B4' },
      
      // Second level - sloped platforms
      { x: 100, y: 550, width: 150, height: 15, color: '#FF69B4' },
      { x: 300, y: 540, width: 200, height: 15, color: '#FF69B4' },
      { x: 550, y: 530, width: 200, height: 15, color: '#FF69B4' },
      { x: 780, y: 520, width: 120, height: 15, color: '#FF69B4' },
      
      // Third level - more sloped
      { x: 50, y: 450, width: 180, height: 15, color: '#FF69B4' },
      { x: 280, y: 440, width: 220, height: 15, color: '#FF69B4' },
      { x: 550, y: 430, width: 180, height: 15, color: '#FF69B4' },
      { x: 780, y: 420, width: 120, height: 15, color: '#FF69B4' },
      
      // Fourth level
      { x: 100, y: 350, width: 150, height: 15, color: '#FF69B4' },
      { x: 300, y: 340, width: 200, height: 15, color: '#FF69B4' },
      { x: 550, y: 330, width: 200, height: 15, color: '#FF69B4' },
      { x: 780, y: 320, width: 120, height: 15, color: '#FF69B4' },
      
      // Fifth level  
      { x: 50, y: 250, width: 180, height: 15, color: '#FF69B4' },
      { x: 280, y: 240, width: 220, height: 15, color: '#FF69B4' },
      { x: 550, y: 230, width: 180, height: 15, color: '#FF69B4' },
      { x: 780, y: 220, width: 120, height: 15, color: '#FF69B4' },
      
      // Sixth level
      { x: 100, y: 150, width: 150, height: 15, color: '#FF69B4' },
      { x: 300, y: 140, width: 200, height: 15, color: '#FF69B4' },
      { x: 550, y: 130, width: 200, height: 15, color: '#FF69B4' },
      { x: 780, y: 120, width: 120, height: 15, color: '#FF69B4' },
      
      // Top platform (Princess platform)
      { x: 350, y: 50, width: 200, height: 20, color: '#FFD700' }
    ];
  }
  
  generateElevatorLevel() {
    // Level 2: Elevator Level (Conveyors and elevators)
    return [
      // Bottom platform (full width)
      { x: 0, y: 650, width: 900, height: 20, color: '#00BFFF' },
      
      // Conveyor platforms (moving belts)
      { x: 50, y: 550, width: 200, height: 15, color: '#00BFFF', conveyor: 'left' },
      { x: 350, y: 550, width: 200, height: 15, color: '#00BFFF', conveyor: 'right' },
      { x: 650, y: 550, width: 200, height: 15, color: '#00BFFF', conveyor: 'left' },
      
      // Middle platforms with gaps for elevators
      { x: 100, y: 450, width: 150, height: 15, color: '#00BFFF' },
      { x: 400, y: 450, width: 100, height: 15, color: '#00BFFF' },
      { x: 650, y: 450, width: 150, height: 15, color: '#00BFFF' },
      
      // More conveyor belts
      { x: 0, y: 350, width: 180, height: 15, color: '#00BFFF', conveyor: 'right' },
      { x: 280, y: 350, width: 180, height: 15, color: '#00BFFF', conveyor: 'left' },
      { x: 560, y: 350, width: 180, height: 15, color: '#00BFFF', conveyor: 'right' },
      { x: 780, y: 350, width: 120, height: 15, color: '#00BFFF' },
      
      // Upper platforms
      { x: 100, y: 250, width: 150, height: 15, color: '#00BFFF' },
      { x: 350, y: 250, width: 200, height: 15, color: '#00BFFF', conveyor: 'left' },
      { x: 650, y: 250, width: 150, height: 15, color: '#00BFFF' },
      
      // Near-top platforms
      { x: 50, y: 150, width: 180, height: 15, color: '#00BFFF', conveyor: 'right' },
      { x: 330, y: 150, width: 240, height: 15, color: '#00BFFF' },
      { x: 670, y: 150, width: 180, height: 15, color: '#00BFFF', conveyor: 'left' },
      
      // Top platform (Princess platform)
      { x: 350, y: 50, width: 200, height: 20, color: '#FFD700' }
    ];
  }
  
  generateBossLevel() {
    // Level 3: Boss Level (Direct confrontation with Kong)
    return [
      // Bottom platform (full width)
      { x: 0, y: 650, width: 900, height: 20, color: '#8B4513' },
      
      // Large lower platforms for maneuvering
      { x: 50, y: 550, width: 300, height: 20, color: '#8B4513' },
      { x: 550, y: 550, width: 300, height: 20, color: '#8B4513' },
      
      // Middle level - wider platforms
      { x: 100, y: 450, width: 250, height: 20, color: '#8B4513' },
      { x: 450, y: 450, width: 250, height: 20, color: '#8B4513' },
      { x: 750, y: 450, width: 150, height: 20, color: '#8B4513' },
      
      // Upper level - fewer but strategic platforms
      { x: 0, y: 350, width: 200, height: 20, color: '#8B4513' },
      { x: 300, y: 350, width: 300, height: 20, color: '#8B4513' },
      { x: 700, y: 350, width: 200, height: 20, color: '#8B4513' },
      
      // Pre-boss platforms
      { x: 150, y: 250, width: 200, height: 20, color: '#8B4513' },
      { x: 450, y: 250, width: 200, height: 20, color: '#8B4513' },
      { x: 750, y: 250, width: 150, height: 20, color: '#8B4513' },
      
      // Kong's platform (larger and central)
      { x: 300, y: 150, width: 300, height: 25, color: '#8B0000' },
      
      // Top platform (Princess platform - final rescue)
      { x: 350, y: 50, width: 200, height: 20, color: '#FFD700' }
    ];
  }
  
  generateLevelLadders(levelType) {
    // Generate ladders from authentic JSON specification
    const levelData = this.getAuthenticLevelData(levelType);
    if (levelData) {
      return this.buildLaddersFromLevelData(levelData);
    }
    
    // Should never reach here with authentic data
    console.warn('⚠️ No authentic ladder data found, using emergency fallback');
    return this.generateBarrelLevelLadders();
  }
  
  // Build authentic ladders from level data
  buildLaddersFromLevelData(levelData) {
    const ladders = [];
    const tileSize = 8; // Authentic 8px tiles
    const gameWidth = 900;
    const gameHeight = 700;
    const cols = 32;
    const rows = 28;
    
    // Scale factors to fit 32×28 grid into game canvas
    const scaleX = gameWidth / (cols * tileSize);
    const scaleY = gameHeight / (rows * tileSize);
    
    console.log(`🎮 Building ${levelData.ladders.length} authentic ladders for ${levelData.name}`);
    
    for (const ladderData of levelData.ladders) {
      const x = ladderData.x;
      const yTop = ladderData.yTop;
      const yBottom = ladderData.yBottom;
      const brokenTop = ladderData.brokenTop || 0;
      
      // Calculate actual ladder start (accounting for broken top)
      const actualTop = yTop + brokenTop;
      
      // Convert to world coordinates
      const worldX = x * tileSize * scaleX;
      const worldY = actualTop * tileSize * scaleY;
      const width = tileSize * scaleX;
      const height = (yBottom - actualTop + 1) * tileSize * scaleY;
      
      console.log(`🎮 Ladder: x=${worldX.toFixed(1)}, y=${worldY.toFixed(1)}, h=${height.toFixed(1)}, broken=${brokenTop}`);
      
      ladders.push({
        x: worldX,
        y: worldY,
        width: width,
        height: height,
        originalData: ladderData // Keep original for reference
      });
    }
    
    console.log(`🎮 Generated ${ladders.length} authentic ladders`);
    return ladders;
  }
  
  convertGridToLadders(grid) {
    const ladders = [];
    
    // Direct mapping to game canvas coordinates
    const gameWidth = 900;
    const gameHeight = 700;
    const gridWidth = grid[0].length;
    const gridHeight = grid.length;
    
    console.log(`🎮 Converting grid to ladders: ${gridWidth}x${gridHeight} grid`);
    
    // Scan for ladder segments (vertical L sequences)
    for (let x = 0; x < grid[0].length; x++) {
      let ladderStart = -1;
      
      for (let y = 0; y <= grid.length; y++) {
        const isLadder = (y < grid.length && grid[y][x] === 'L');
        
        if (isLadder && ladderStart === -1) {
          ladderStart = y; // Start of ladder segment
        } else if (!isLadder && ladderStart !== -1) {
          // End of ladder segment - create ladder with proper scaling
          const worldX = (x / gridWidth) * gameWidth;
          const worldY = (ladderStart / gridHeight) * gameHeight;
          const width = (1 / gridWidth) * gameWidth; // One tile width
          const height = ((y - ladderStart) / gridHeight) * gameHeight;
          
          console.log(`🎮 Ladder: x=${worldX.toFixed(1)}, y=${worldY.toFixed(1)}, w=${width.toFixed(1)}, h=${height.toFixed(1)}`);
          
          ladders.push({
            x: worldX,
            y: worldY,
            width: width,
            height: height
          });
          
          ladderStart = -1;
        }
      }
    }
    
    console.log(`🎮 Generated ${ladders.length} ladders from grid`);
    return ladders;
  }
  
  // Extract special positions from grid (Kong, Princess, etc.)
  extractSpecialPositions(grid) {
    const positions = {};
    const tileSize = 16;
    const scaleX = 900 / (grid[0].length * tileSize);
    const scaleY = 700 / (grid.length * tileSize);
    
    for (let y = 0; y < grid.length; y++) {
      for (let x = 0; x < grid[y].length; x++) {
        const symbol = grid[y][x];
        
        if (symbol === 'K') {
          // Kong position
          positions.kong = {
            x: x * tileSize * scaleX,
            y: y * tileSize * scaleY
          };
        } else if (symbol === 'G') {
          // Princess/Goal position
          positions.princess = {
            x: x * tileSize * scaleX,
            y: y * tileSize * scaleY
          };
        } else if (symbol === 'B') {
          // Barrel spawn points
          if (!positions.barrelSpawns) positions.barrelSpawns = [];
          positions.barrelSpawns.push({
            x: x * tileSize * scaleX,
            y: y * tileSize * scaleY
          });
        }
      }
    }
    
    return positions;
  }
  
  // Regenerate current level with authentic sprite data
  regenerateLevelsFromSprites() {
    if (!this.allSpritesLoaded) return;
    
    console.log('🎮 Regenerating levels with authentic sprite data...');
    
    // Regenerate current level platforms and ladders
    this.platforms = this.generateLevelPlatforms(this.level || this.currentLevelType || 1);
    this.ladders = this.generateLevelLadders(this.level || this.currentLevelType || 1);
    
    // Update special positions if in an active game
    if (this.gameState === 'playing' || this.gameState === 'menu') {
      const levelData = this.getLevelDataFromSprites(this.level || this.currentLevelType || 1);
      if (levelData) {
        const specialPositions = this.extractSpecialPositions(levelData.grid);
        
        // Update Kong position if found in sprite data
        if (specialPositions.kong && this.honkyKong) {
          this.honkyKong.x = specialPositions.kong.x;
          this.honkyKong.y = specialPositions.kong.y;
          console.log('🦍 Updated Kong position from sprites:', specialPositions.kong);
        }
        
        // Update Princess position if found in sprite data
        if (specialPositions.princess && this.princess) {
          this.princess.x = specialPositions.princess.x;
          this.princess.y = specialPositions.princess.y;
          console.log('👸 Updated Princess position from sprites:', specialPositions.princess);
        }
        
        // Store barrel spawn points
        if (specialPositions.barrelSpawns) {
          this.barrelSpawns = specialPositions.barrelSpawns;
          console.log('🛢️ Updated barrel spawn points from sprites:', specialPositions.barrelSpawns.length, 'points');
        }
      }
    }
    
    console.log('✅ Level regeneration complete with authentic sprite data');
  }
  
  generateBarrelLevelLadders() {
    return [
      // Ladders connecting platforms (positioned to avoid sloped sections)
      { x: 80, y: 550, width: 15, height: 100 },
      { x: 280, y: 440, width: 15, height: 110 },
      { x: 520, y: 330, width: 15, height: 120 },
      { x: 780, y: 220, width: 15, height: 100 },
      { x: 480, y: 130, width: 15, height: 100 },
      { x: 180, y: 140, width: 15, height: 110 },
      { x: 680, y: 230, width: 15, height: 100 },
      
      // Final ladder to Princess
      { x: 420, y: 50, width: 15, height: 90 }
    ];
  }
  
  generateElevatorLevelLadders() {
    return [
      // Strategic ladders between conveyor sections
      { x: 30, y: 550, width: 15, height: 100 },
      { x: 250, y: 450, width: 15, height: 100 },
      { x: 600, y: 350, width: 15, height: 100 },
      { x: 180, y: 250, width: 15, height: 100 },
      { x: 750, y: 150, width: 15, height: 100 },
      { x: 320, y: 150, width: 15, height: 100 },
      { x: 580, y: 250, width: 15, height: 100 },
      
      // Final ladder to Princess
      { x: 420, y: 50, width: 15, height: 100 }
    ];
  }
  
  generateBossLevelLadders() {
    return [
      // Fewer but more strategic ladders for boss fight
      { x: 200, y: 550, width: 15, height: 100 },
      { x: 650, y: 450, width: 15, height: 100 },
      { x: 120, y: 350, width: 15, height: 100 },
      { x: 520, y: 250, width: 15, height: 100 },
      { x: 780, y: 250, width: 15, height: 100 },
      { x: 250, y: 150, width: 15, height: 100 },
      
      // Final ladder to Princess (boss confrontation)
      { x: 420, y: 50, width: 15, height: 100 }
    ];
  }
  
  advanceToNextLevel() {
    // Check if we've completed all 3 levels
    if (this.level > 3) {
      // Game completed - start over with increased difficulty
      this.level = 1;
      this.score += 10000; // Completion bonus
      this.lives = Math.min(this.lives + 1, 6); // Bonus life, max 6
    }
    
    // Generate new level layout
    this.platforms = this.generateLevelPlatforms(this.level);
    this.ladders = this.generateLevelLadders(this.level);
    
    // Extract authentic positions from JSON specification
    const levelData = this.getAuthenticLevelData(this.level);
    const objectPositions = levelData ? this.extractObjectPositions(levelData) : {};
    
    // Reset player to authentic starting position
    if (objectPositions.player) {
      this.player.x = objectPositions.player.x;
      this.player.y = objectPositions.player.y - 25; // Place player ON TOP of platform, not inside it
      console.log(`🎮 Player positioned at authentic coordinates: ${this.player.x}, ${this.player.y}`);
    } else {
      this.player.x = 100;
      this.player.y = 630;
      console.log(`🎮 Player positioned at fallback coordinates: ${this.player.x}, ${this.player.y}`);
    }
    
    // CRITICAL DEBUG: Show if player is on a valid platform
    this.debugPlayerPlatform();
    this.player.vx = 0;
    this.player.vy = 0;
    this.player.hasHammer = false;
    this.player.hammerTimer = 0;
    this.player.isClimbing = false;
    this.player.animation = 'stand-right';
    
    // Position Princess based on authentic object data
    if (objectPositions.princess) {
      this.princess.x = objectPositions.princess.x;
      this.princess.y = objectPositions.princess.y;
    } else {
      this.princess.x = 450;
      this.princess.y = 30;
    }
    
    // Clear all barrels and fireballs
    this.barrels = [];
    this.fireballs = [];
    
    // Position Kong based on authentic object data
    if (objectPositions.kong) {
      this.honkyKong.x = objectPositions.kong.x;
      this.honkyKong.y = objectPositions.kong.y;
    } else {
      this.honkyKong.x = 200;
      this.honkyKong.y = 30;
    }
    
    // Store authentic hammer positions
    if (objectPositions.hammers) {
      this.authenticHammers = objectPositions.hammers;
      console.log(`🎮 Level ${this.level} has ${this.authenticHammers.length} authentic hammer positions`);
    }
    
    // Store other object positions for reference
    this.authenticObjects = objectPositions;
    
    // Level-specific adjustments
    if (this.level === 2) {
      // Elevator level - add moving platform mechanics
      this.conveyorSpeed = 1;
      this.elevatorPositions = [
        { x: 275, y: 500, direction: 1 }, // Moving elevator
        { x: 525, y: 400, direction: -1 }
      ];
      this.bossMode = false;
    } else if (this.level === 3) {
      // Boss level - direct confrontation mode
      this.bossMode = true;
      this.kongHealth = 3; // Kong takes 3 hammer hits
      this.kongHitThisSwing = false;
      this.honkyKong.defeated = false;
    } else {
      // Level 1 - normal barrel level
      this.bossMode = false;
    }
    
    // Reset bonus timer
    this.bonus = 5000;
    this.bonusTimer = 0;
    
    // Start new level
    this.gameState = 'playing';
  }
  
  bossDefeated() {
    // Kong defeated - ultimate victory!
    this.gameState = 'celebrating';
    this.celebrationTimer = 0;
    this.celebrationDuration = 360; // Extra long celebration for boss victory
    
    // Award massive bonus points
    this.score += 5000;
    this.bonus += 2000;
    this.updateUI();
    
    // Ultra spectacular particle effects
    this.createParticles(this.honkyKong.x + 24, this.honkyKong.y + 20, 50, '#FFD700', 'spark');
    this.createParticles(this.honkyKong.x + 24, this.honkyKong.y + 20, 30, '#FF0000', 'explosion');
    this.createParticles(this.player.x + 8, this.player.y + 10, 25, '#00FF00', 'victory');
    
    // Stop background music and play ultimate victory sound
    this.stopSound('bacmusic');
    this.sounds.victory();
    
    // Make Kong disappear (defeated animation)
    this.honkyKong.defeated = true;
    this.honkyKong.defeatTimer = 0;
  }

  // Authentic Donkey Kong sound system
  loadSounds() {
    for (let [soundName, soundPath] of Object.entries(this.soundPaths)) {
      if (soundPath) {
        try {
          const audio = new Audio();
          audio.src = soundPath;
          audio.preload = 'auto';
          
          // Configure for game audio
          audio.volume = 0.3; // Reasonable default volume
          
          // Special configuration for background music
          if (soundName === 'bacmusic') {
            audio.loop = true;
            audio.volume = 0.15; // Lower volume for background
          }
          
          this.audioElements[soundName] = audio;
          
          // Handle loading errors gracefully
          audio.addEventListener('error', (e) => {
            console.warn(`Could not load sound: ${soundName} from ${soundPath}`);
          });
          
        } catch (error) {
          console.warn(`Error creating audio element for ${soundName}:`, error);
        }
      }
    }
  }
  
  playSound(soundName, loop = false) {
    try {
      const audio = this.audioElements[soundName];
      if (audio) {
        // Reset to beginning if already playing
        audio.currentTime = 0;
        
        // Set loop if specified
        if (loop) {
          audio.loop = true;
        }
        
        // Play with promise handling for better browser compatibility
        const playPromise = audio.play();
        if (playPromise !== undefined) {
          playPromise.catch(error => {
            // Handle autoplay restrictions gracefully
            console.log(`Audio play prevented for ${soundName}:`, error.name);
          });
        }
      }
    } catch (error) {
      console.warn(`Error playing sound ${soundName}:`, error);
    }
  }
  
  stopSound(soundName) {
    try {
      const audio = this.audioElements[soundName];
      if (audio) {
        audio.pause();
        audio.currentTime = 0;
      }
    } catch (error) {
      console.warn(`Error stopping sound ${soundName}:`, error);
    }
  }
  
  setVolume(soundName, volume) {
    try {
      const audio = this.audioElements[soundName];
      if (audio) {
        audio.volume = Math.max(0, Math.min(1, volume)); // Clamp between 0 and 1
      }
    } catch (error) {
      console.warn(`Error setting volume for ${soundName}:`, error);
    }
  }

  // Professional cleanup method
  destroy() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
    
    // Clean up audio elements
    for (let audio of Object.values(this.audioElements)) {
      if (audio) {
        audio.pause();
        audio.src = '';
      }
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