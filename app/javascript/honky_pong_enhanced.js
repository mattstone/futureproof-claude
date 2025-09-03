// Enhanced HonkyPong with Precise Sprite System
// Uses all the sprite extraction data we've built

export class HonkyPongGame {
  constructor(options = {}) {
    console.log('🚀 DEBUG: HonkyPongGame Enhanced Version Loading!', new Date().toISOString());
    this.canvas = options.canvas;
    this.ctx = this.canvas.getContext('2d');
    
    // Game dimensions - classic arcade resolution
    this.width = this.canvas.width;
    this.height = this.canvas.height;
    
    // Load sprites and sounds with proper asset paths
    this.sprites = {};
    this.sounds = {};
    this.audioContext = null;
    this.loadAssets();
    
    // Game state
    this.gameState = 'loading';
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.animationFrame = 0;
    this.gameTime = 0;
    
    // Mario with animation states
    this.mario = {
      x: 50,
      y: this.height - 100,
      width: 24,
      height: 24,
      vx: 0,
      vy: 0,
      speed: 3,
      onGround: false,
      onLadder: false,
      facing: 'right',
      state: 'standing', // standing, running, climbing, jumping, death, hammer, tumbling
      animFrame: 0,
      animSpeed: 0.15,
      hasHammer: false,
      hammerTimer: 0
    };
    
    // Donkey Kong with animations
    this.donkeyKong = {
      x: this.width - 100,
      y: 50,
      width: 48,
      height: 32,
      state: 'chest_beating', // chest_beating, throwing_barrel
      animFrame: 0,
      animSpeed: 0.1,
      throwTimer: 0
    };
    
    // Princess Pauline
    this.pauline = {
      x: this.width / 2,
      y: 30,
      width: 15,
      height: 22,
      state: 'help', // help, rescued
      animFrame: 0,
      animSpeed: 0.2
    };
    
    // Game objects
    this.barrels = [];
    this.hammers = [];
    this.fireballs = [];
    this.platforms = [];
    this.ladders = [];
    
    // Create level structure using our tile system
    this.createLevel();
    
    // Input
    this.keys = {};
    this.setupControls();
    
    // UI elements
    this.scoreElement = options.scoreElement;
    this.livesElement = options.livesElement;
    this.levelElement = options.levelElement;
    this.bonusElement = options.bonusElement;
    this.startButton = options.startButton;
    this.pauseButton = options.pauseButton;
    this.gameOverElement = options.gameOverElement;
    this.finalScoreElement = options.finalScoreElement;
    this.restartButton = options.restartButton;
    
    if (this.startButton) {
      this.startButton.addEventListener('click', () => this.startGame());
    }
    if (this.restartButton) {
      this.restartButton.addEventListener('click', () => this.restartGame());
    }
  }
  
  async loadAssets() {
    console.log('🎮 Enhanced HonkyPong: Loading assets...');
    console.log('Canvas dataset:', this.canvas.dataset);
    
    // Initialize audio context for better browser compatibility
    try {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    } catch (error) {
      console.warn('Audio context not available:', error);
    }
    
    // Load sprites from canvas data attributes
    const spritePaths = {
      mario: this.canvas.dataset.marioSprite,
      enemies: this.canvas.dataset.enemiesSprite,
      pauline: this.canvas.dataset.paulineSprite,
      levels: '/sprites/levels.png'  // Load levels.png for authentic sprites
    };
    
    // Load sounds from canvas data attributes  
    const soundPaths = {
      bacmusic: this.canvas.dataset.soundBacmusic,
      death: this.canvas.dataset.soundDeath,
      hammer: this.canvas.dataset.soundHammer,
      howhigh: this.canvas.dataset.soundHowhigh,
      intro: this.canvas.dataset.soundIntro,
      itemget: this.canvas.dataset.soundItemget,
      jump: this.canvas.dataset.soundJump,
      jumpbar: this.canvas.dataset.soundJumpbar,
      walking: this.canvas.dataset.soundWalking,
      win1: this.canvas.dataset.soundWin1,
      win2: this.canvas.dataset.soundWin2
    };
    
    // Load sprites
    for (const [key, path] of Object.entries(spritePaths)) {
      if (path) {
        try {
          const img = new Image();
          await new Promise((resolve, reject) => {
            img.onload = resolve;
            img.onerror = () => {
              console.warn(`Failed to load ${key} sprite at ${path}`);
              resolve(); // Continue even if image fails
            };
            img.src = path;
          });
          this.sprites[key] = img;
          console.log(`✅ Loaded ${key} sprite`);
        } catch (error) {
          console.warn(`❌ Failed to load ${key} sprite:`, error);
        }
      }
    }
    
    // Load sounds
    for (const [key, path] of Object.entries(soundPaths)) {
      if (path) {
        try {
          const audio = new Audio();
          await new Promise((resolve) => {
            audio.addEventListener('canplaythrough', resolve, { once: true });
            audio.addEventListener('error', () => {
              console.warn(`Failed to load ${key} sound at ${path}`);
              resolve(); // Continue even if sound fails
            }, { once: true });
            audio.src = path;
            audio.preload = 'auto';
          });
          this.sounds[key] = audio;
          console.log(`🔊 Loaded ${key} sound`);
        } catch (error) {
          console.warn(`❌ Failed to load ${key} sound:`, error);
        }
      }
    }
    
    this.gameState = 'ready';
    console.log('🎮 Enhanced HonkyPong ready to start!');
  }
  
  // Sound system
  playSound(soundName, volume = 0.5) {
    if (!this.sounds[soundName]) {
      console.warn(`Sound ${soundName} not available`);
      return;
    }
    
    try {
      // Resume audio context if needed (browser autoplay policy)
      if (this.audioContext && this.audioContext.state === 'suspended') {
        this.audioContext.resume();
      }
      
      const sound = this.sounds[soundName].cloneNode();
      sound.volume = Math.max(0, Math.min(1, volume));
      sound.currentTime = 0;
      sound.play().catch(error => {
        console.warn(`Failed to play sound ${soundName}:`, error);
      });
    } catch (error) {
      console.warn(`Error playing sound ${soundName}:`, error);
    }
  }
  
  playBackgroundMusic() {
    if (this.sounds.bacmusic) {
      try {
        this.sounds.bacmusic.loop = true;
        this.sounds.bacmusic.volume = 0.3;
        this.sounds.bacmusic.play().catch(error => {
          console.warn('Background music failed to play:', error);
        });
      } catch (error) {
        console.warn('Background music error:', error);
      }
    }
  }
  
  stopBackgroundMusic() {
    if (this.sounds.bacmusic) {
      this.sounds.bacmusic.pause();
      this.sounds.bacmusic.currentTime = 0;
    }
  }
  
  createLevel() {
    const canvasWidth = this.width;
    const canvasHeight = this.height;

    this.platforms = [];
    this.ladders = [];
    this.girders = [];

    // Extracted Sprite Coordinates from Level Image - Level 1 coordinates
    const spriteCoords = {
      "long-girder": { x: 18, y: 195, width: 48, height: 8 },   // Use actual Level 1 coordinates  
      "short-girder": { x: 107, y: 219, width: 24, height: 8 }, // Use actual Level 1 coordinates
      "ladder": { x: 101, y: 200, width: 16, height: 30 }       // Use actual Level 1 coordinates
    };

    // Store sprite coordinates for rendering
    this.spriteCoords = spriteCoords;

    // Sprite-based Girders (using extracted authentic sprites)
    this.girders.push({ 
      type: 'sprite',
      spriteType: 'long-girder',
      gameX: 164, gameY: 504,
      width: 48, height: 8,
      color: '#FF6B47'
    });
    this.girders.push({ 
      type: 'sprite',
      spriteType: 'long-girder',
      gameX: 225, gameY: 503,
      width: 48, height: 8,
      color: '#FF6B47'
    });
    this.girders.push({ 
      type: 'sprite',
      spriteType: 'long-girder',
      gameX: 285, gameY: 504,
      width: 48, height: 8,
      color: '#FF6B47'
    });
    this.girders.push({ // long girder
      startX: 345, startY: 504, endX: 393, endY: 504,
      color: '#FF6B47',
      segments: this.createGirderSegments(345, 504, 393, 504)
    });
    this.girders.push({ // short girder
      startX: 406, startY: 504, endX: 430, endY: 504,
      color: '#FF6B47',
      segments: this.createGirderSegments(406, 504, 430, 504)
    });
    this.girders.push({ // long girder
      startX: 329, startY: 547, endX: 377, endY: 547,
      color: '#FF6B47',
      segments: this.createGirderSegments(329, 547, 377, 547)
    });
    this.girders.push({ // long girder
      startX: 389, startY: 566, endX: 437, endY: 566,
      color: '#FF6B47',
      segments: this.createGirderSegments(389, 566, 437, 566)
    });
    this.girders.push({ // long girder
      startX: 451, startY: 566, endX: 499, endY: 566,
      color: '#FF6B47',
      segments: this.createGirderSegments(451, 566, 499, 566)
    });
    this.girders.push({ // long girder
      startX: 452, startY: 502, endX: 500, endY: 502,
      color: '#FF6B47',
      segments: this.createGirderSegments(452, 502, 500, 502)
    });
    this.girders.push({ // long girder
      startX: 514, startY: 499, endX: 562, endY: 499,
      color: '#FF6B47',
      segments: this.createGirderSegments(514, 499, 562, 499)
    });
    this.girders.push({ // long girder
      startX: 576, startY: 496, endX: 624, endY: 496,
      color: '#FF6B47',
      segments: this.createGirderSegments(576, 496, 624, 496)
    });
    this.girders.push({ // long girder
      startX: 636, startY: 496, endX: 684, endY: 496,
      color: '#FF6B47',
      segments: this.createGirderSegments(636, 496, 684, 496)
    });
    this.girders.push({ // long girder
      startX: 207, startY: 417, endX: 255, endY: 417,
      color: '#FF6B47',
      segments: this.createGirderSegments(207, 417, 255, 417)
    });
    this.girders.push({ // long girder
      startX: 267, startY: 420, endX: 315, endY: 420,
      color: '#FF6B47',
      segments: this.createGirderSegments(267, 420, 315, 420)
    });
    this.girders.push({ // long girder
      startX: 328, startY: 422, endX: 376, endY: 422,
      color: '#FF6B47',
      segments: this.createGirderSegments(328, 422, 376, 422)
    });
    this.girders.push({ // long girder
      startX: 391, startY: 425, endX: 439, endY: 425,
      color: '#FF6B47',
      segments: this.createGirderSegments(391, 425, 439, 425)
    });
    this.girders.push({ // long girder
      startX: 452, startY: 427, endX: 500, endY: 427,
      color: '#FF6B47',
      segments: this.createGirderSegments(452, 427, 500, 427)
    });
    this.girders.push({ // long girder
      startX: 513, startY: 430, endX: 561, endY: 430,
      color: '#FF6B47',
      segments: this.createGirderSegments(513, 430, 561, 430)
    });
    this.girders.push({ // long girder
      startX: 575, startY: 432, endX: 623, endY: 432,
      color: '#FF6B47',
      segments: this.createGirderSegments(575, 432, 623, 432)
    });
    this.girders.push({ // long girder
      startX: 635, startY: 435, endX: 683, endY: 435,
      color: '#FF6B47',
      segments: this.createGirderSegments(635, 435, 683, 435)
    });
    this.girders.push({ // short girder
      startX: 697, startY: 436, endX: 721, endY: 436,
      color: '#FF6B47',
      segments: this.createGirderSegments(697, 436, 721, 436)
    });
    this.girders.push({ // long girder
      startX: 207, startY: 358, endX: 255, endY: 358,
      color: '#FF6B47',
      segments: this.createGirderSegments(207, 358, 255, 358)
    });
    this.girders.push({ // short girder
      startX: 166, startY: 360, endX: 190, endY: 360,
      color: '#FF6B47',
      segments: this.createGirderSegments(166, 360, 190, 360)
    });
    this.girders.push({ // long girder
      startX: 267, startY: 355, endX: 315, endY: 355,
      color: '#FF6B47',
      segments: this.createGirderSegments(267, 355, 315, 355)
    });
    this.girders.push({ // long girder
      startX: 328, startY: 352, endX: 376, endY: 352,
      color: '#FF6B47',
      segments: this.createGirderSegments(328, 352, 376, 352)
    });
    this.girders.push({ // long girder
      startX: 390, startY: 351, endX: 438, endY: 351,
      color: '#FF6B47',
      segments: this.createGirderSegments(390, 351, 438, 351)
    });
    this.girders.push({ // long girder
      startX: 452, startY: 347, endX: 500, endY: 347,
      color: '#FF6B47',
      segments: this.createGirderSegments(452, 347, 500, 347)
    });
    this.girders.push({ // long girder
      startX: 514, startY: 345, endX: 562, endY: 345,
      color: '#FF6B47',
      segments: this.createGirderSegments(514, 345, 562, 345)
    });
    this.girders.push({ // long girder
      startX: 576, startY: 342, endX: 624, endY: 342,
      color: '#FF6B47',
      segments: this.createGirderSegments(576, 342, 624, 342)
    });
    this.girders.push({ // long girder
      startX: 637, startY: 340, endX: 685, endY: 340,
      color: '#FF6B47',
      segments: this.createGirderSegments(637, 340, 685, 340)
    });
    this.girders.push({ // long girder
      startX: 207, startY: 263, endX: 255, endY: 263,
      color: '#FF6B47',
      segments: this.createGirderSegments(207, 263, 255, 263)
    });
    this.girders.push({ // long girder
      startX: 267, startY: 265, endX: 315, endY: 265,
      color: '#FF6B47',
      segments: this.createGirderSegments(267, 265, 315, 265)
    });
    this.girders.push({ // long girder
      startX: 328, startY: 267, endX: 376, endY: 267,
      color: '#FF6B47',
      segments: this.createGirderSegments(328, 267, 376, 267)
    });
    this.girders.push({ // long girder
      startX: 389, startY: 270, endX: 437, endY: 270,
      color: '#FF6B47',
      segments: this.createGirderSegments(389, 270, 437, 270)
    });
    this.girders.push({ // long girder
      startX: 450, startY: 273, endX: 498, endY: 273,
      color: '#FF6B47',
      segments: this.createGirderSegments(450, 273, 498, 273)
    });
    this.girders.push({ // long girder
      startX: 512, startY: 275, endX: 560, endY: 275,
      color: '#FF6B47',
      segments: this.createGirderSegments(512, 275, 560, 275)
    });
    this.girders.push({ // long girder
      startX: 574, startY: 278, endX: 622, endY: 278,
      color: '#FF6B47',
      segments: this.createGirderSegments(574, 278, 622, 278)
    });
    this.girders.push({ // long girder
      startX: 636, startY: 281, endX: 684, endY: 281,
      color: '#FF6B47',
      segments: this.createGirderSegments(636, 281, 684, 281)
    });
    this.girders.push({ // short girder
      startX: 697, startY: 282, endX: 721, endY: 282,
      color: '#FF6B47',
      segments: this.createGirderSegments(697, 282, 721, 282)
    });
    this.girders.push({ // short girder
      startX: 165, startY: 207, endX: 189, endY: 207,
      color: '#FF6B47',
      segments: this.createGirderSegments(165, 207, 189, 207)
    });
    this.girders.push({ // long girder
      startX: 207, startY: 204, endX: 255, endY: 204,
      color: '#FF6B47',
      segments: this.createGirderSegments(207, 204, 255, 204)
    });
    this.girders.push({ // long girder
      startX: 269, startY: 201, endX: 317, endY: 201,
      color: '#FF6B47',
      segments: this.createGirderSegments(269, 201, 317, 201)
    });
    this.girders.push({ // long girder
      startX: 328, startY: 199, endX: 376, endY: 199,
      color: '#FF6B47',
      segments: this.createGirderSegments(328, 199, 376, 199)
    });
    this.girders.push({ // long girder
      startX: 391, startY: 198, endX: 439, endY: 198,
      color: '#FF6B47',
      segments: this.createGirderSegments(391, 198, 439, 198)
    });
    this.girders.push({ // long girder
      startX: 453, startY: 193, endX: 501, endY: 193,
      color: '#FF6B47',
      segments: this.createGirderSegments(453, 193, 501, 193)
    });
    this.girders.push({ // long girder
      startX: 515, startY: 191, endX: 563, endY: 191,
      color: '#FF6B47',
      segments: this.createGirderSegments(515, 191, 563, 191)
    });
    this.girders.push({ // long girder
      startX: 576, startY: 189, endX: 624, endY: 189,
      color: '#FF6B47',
      segments: this.createGirderSegments(576, 189, 624, 189)
    });
    this.girders.push({ // long girder
      startX: 636, startY: 186, endX: 684, endY: 186,
      color: '#FF6B47',
      segments: this.createGirderSegments(636, 186, 684, 186)
    });
    this.girders.push({ // long girder
      startX: 146, startY: 114, endX: 194, endY: 114,
      color: '#FF6B47',
      segments: this.createGirderSegments(146, 114, 194, 114)
    });
    this.girders.push({ // long girder
      startX: 206, startY: 114, endX: 254, endY: 114,
      color: '#FF6B47',
      segments: this.createGirderSegments(206, 114, 254, 114)
    });
    this.girders.push({ // long girder
      startX: 267, startY: 115, endX: 315, endY: 115,
      color: '#FF6B47',
      segments: this.createGirderSegments(267, 115, 315, 115)
    });
    this.girders.push({ // long girder
      startX: 328, startY: 115, endX: 376, endY: 115,
      color: '#FF6B47',
      segments: this.createGirderSegments(328, 115, 376, 115)
    });
    this.girders.push({ // long girder
      startX: 389, startY: 114, endX: 437, endY: 114,
      color: '#FF6B47',
      segments: this.createGirderSegments(389, 114, 437, 114)
    });
    this.girders.push({ // long girder
      startX: 451, startY: 117, endX: 499, endY: 117,
      color: '#FF6B47',
      segments: this.createGirderSegments(451, 117, 499, 117)
    });
    this.girders.push({ // long girder
      startX: 512, startY: 118, endX: 560, endY: 118,
      color: '#FF6B47',
      segments: this.createGirderSegments(512, 118, 560, 118)
    });
    this.girders.push({ // long girder
      startX: 576, startY: 123, endX: 624, endY: 123,
      color: '#FF6B47',
      segments: this.createGirderSegments(576, 123, 624, 123)
    });
    this.girders.push({ // long girder
      startX: 637, startY: 124, endX: 685, endY: 124,
      color: '#FF6B47',
      segments: this.createGirderSegments(637, 124, 685, 124)
    });
    this.girders.push({ // long girder
      startX: 698, startY: 126, endX: 746, endY: 126,
      color: '#FF6B47',
      segments: this.createGirderSegments(698, 126, 746, 126)
    });

    // Sprite-based Ladders (using extracted authentic sprites)  
    this.ladders.push({
      type: 'sprite',
      spriteType: 'ladder',
      x: 329, y: 508, width: 16, height: 25
    });
    this.ladders.push({
      type: 'sprite', 
      spriteType: 'ladder',
      x: 370, y: 507, width: 16, height: 25
    });
    this.ladders.push({
      type: 'sprite',
      spriteType: 'ladder', 
      x: 390, y: 471, width: 16, height: 25
    });
    this.ladders.push({
      x: 390, y: 426, width: 16, height: 25
    });
    this.ladders.push({
      x: 348, y: 358, width: 16, height: 50
    });
    this.ladders.push({
      x: 329, y: 276, width: 16, height: 25
    });
    this.ladders.push({
      x: 495, y: 503, width: 16, height: 50
    });
    this.ladders.push({
      x: 329, y: 553, width: 16, height: 80
    });
    this.ladders.push({
      x: 369, y: 554, width: 16, height: 80
    });
    this.ladders.push({
      x: 635, y: 433, width: 16, height: 50
    });
    this.ladders.push({
      x: 454, y: 282, width: 16, height: 50
    });
    this.ladders.push({
      x: 370, y: 160, width: 16, height: 25
    });
    this.ladders.push({
      x: 369, y: 118, width: 16, height: 25
    });
    this.ladders.push({
      x: 595, y: 340, width: 16, height: 25
    });
    this.ladders.push({
      x: 329, y: 324, width: 16, height: 25
    });
    this.ladders.push({
      x: 595, y: 407, width: 16, height: 25
    });
    this.ladders.push({
      x: 248, y: 360, width: 16, height: 50
    });
    this.ladders.push({
      x: 410, y: 205, width: 16, height: 50
    });
    this.ladders.push({
      x: 636, y: 281, width: 16, height: 50
    });
    this.ladders.push({
      x: 247, y: 206, width: 16, height: 50
    });
    this.ladders.push({
      x: 636, y: 126, width: 16, height: 50
    });
  }
  
  // Helper function to create collision segments along angled girders
  createGirderSegments(startX, startY, endX, endY) {
    const segments = [];
    const numSegments = 20; // Create 20 collision segments along each girder
    const stepX = (endX - startX) / numSegments;
    const stepY = (endY - startY) / numSegments;
    
    for (let i = 0; i < numSegments; i++) {
      segments.push({
        x: startX + (stepX * i),
        y: startY + (stepY * i),
        width: Math.abs(stepX) + 8, // Slightly overlap segments
        height: 20
      });
    }
    
    return segments;
  }
  
  setupControls() {
    // Handled by Stimulus controller
  }
  
  startGame() {
    if (this.gameState !== 'ready') return;
    
    this.gameState = 'playing';
    this.gameTime = 0;
    
    // Play intro sound and start background music
    this.playSound('intro', 0.7);
    setTimeout(() => this.playBackgroundMusic(), 1000);
    
    this.gameLoop();
    
    if (this.startButton) this.startButton.disabled = true;
    if (this.pauseButton) this.pauseButton.disabled = false;
  }
  
  restartGame() {
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.mario.x = 50;
    this.mario.y = this.height - 100;
    this.mario.state = 'standing';
    this.mario.hasHammer = false;
    this.barrels = [];
    this.fireballs = [];
    this.createLevel();
    
    if (this.gameOverElement) {
      this.gameOverElement.classList.add('game-over-hidden');
    }
    
    this.startGame();
  }
  
  gameLoop() {
    if (this.gameState !== 'playing') return;
    
    try {
      this.gameTime++;
      this.animationFrame++;
      
      this.update();
      this.render();
      this.updateUI();
      
      // Performance monitoring
      if (this.gameTime % 60 === 0) { // Every second at 60fps
        this.updatePerformanceMetrics();
      }
      
      requestAnimationFrame(() => this.gameLoop());
    } catch (error) {
      console.error('Game loop error:', error);
      this.handleGameError(error);
    }
  }
  
  updatePerformanceMetrics() {
    if (window.performance && window.performance.memory) {
      const memory = Math.round(window.performance.memory.usedJSHeapSize / 1048576); // MB
      const particles = this.barrels.length + this.fireballs.length;
      
      // You can emit this data to the controller if needed
      if (this.performanceCallback) {
        this.performanceCallback({
          fps: 60, // Assuming 60fps for now
          memory: memory,
          particles: particles
        });
      }
    }
  }
  
  handleGameError(error) {
    console.error('Critical game error:', error);
    this.gameState = 'error';
    this.stopBackgroundMusic();
    
    // Display user-friendly error message
    this.ctx.fillStyle = '#FF0000';
    this.ctx.font = '24px monospace';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('GAME ERROR - PLEASE REFRESH', this.width/2, this.height/2);
    this.ctx.font = '16px monospace';
    this.ctx.fillText('Press R to restart', this.width/2, this.height/2 + 40);
  }
  
  update() {
    this.updateMario();
    this.updateDonkeyKong();
    this.updateBarrels();
    this.updateFireballs();
    this.checkCollisions();
  }
  
  updateMario() {
    const prevState = this.mario.state;
    
    // Handle hammer timer
    if (this.mario.hasHammer) {
      this.mario.hammerTimer--;
      if (this.mario.hammerTimer <= 0) {
        this.mario.hasHammer = false;
      }
    }
    
    // Horizontal movement
    if (this.keys['ArrowLeft'] && !this.mario.onLadder) {
      this.mario.vx = -this.mario.speed;
      this.mario.facing = 'left';
      this.mario.state = this.mario.hasHammer ? 'hammer' : 'running';
      
      // Walking sound effect
      if (this.mario.onGround && this.gameTime % 20 === 0) {
        this.playSound('walking', 0.2);
      }
    } else if (this.keys['ArrowRight'] && !this.mario.onLadder) {
      this.mario.vx = this.mario.speed;
      this.mario.facing = 'right';
      this.mario.state = this.mario.hasHammer ? 'hammer' : 'running';
      
      // Walking sound effect
      if (this.mario.onGround && this.gameTime % 20 === 0) {
        this.playSound('walking', 0.2);
      }
    } else if (!this.mario.onLadder) {
      this.mario.vx = 0;
      this.mario.state = this.mario.hasHammer ? 'hammer' : 'standing';
    }
    
    // Vertical movement (ladders)
    if (this.keys['ArrowUp'] && this.isOnLadder()) {
      this.mario.onLadder = true;
      this.mario.vy = -this.mario.speed;
      this.mario.state = 'climbing';
      this.mario.vx = 0;
    } else if (this.keys['ArrowDown'] && this.isOnLadder()) {
      this.mario.onLadder = true;
      this.mario.vy = this.mario.speed;
      this.mario.state = 'climbing';
      this.mario.vx = 0;
    } else if (this.mario.onLadder) {
      this.mario.vy = 0;
      if (!this.isOnLadder()) {
        this.mario.onLadder = false;
      }
    }
    
    // Apply movement
    this.mario.x += this.mario.vx;
    
    // Gravity (only if not on ladder)
    if (!this.mario.onLadder) {
      this.mario.vy += 0.8;
    }
    this.mario.y += this.mario.vy;
    
    // Platform collisions (flat platforms)
    this.mario.onGround = false;
    for (const platform of this.platforms) {
      if (this.mario.x + this.mario.width > platform.x && 
          this.mario.x < platform.x + platform.width &&
          this.mario.y + this.mario.height > platform.y &&
          this.mario.y + this.mario.height < platform.y + platform.height + 10 &&
          this.mario.vy >= 0) {
        this.mario.y = platform.y - this.mario.height;
        this.mario.vy = 0;
        this.mario.onGround = true;
        break;
      }
    }
    
    // Angled girder collisions
    if (!this.mario.onGround) {
      for (const girder of this.girders) {
        if (girder.type === 'sprite') {
          // Simple collision for sprite-based girders
          if (this.mario.x + this.mario.width > girder.gameX && 
              this.mario.x < girder.gameX + girder.width &&
              this.mario.y + this.mario.height > girder.gameY &&
              this.mario.y + this.mario.height < girder.gameY + girder.height + 10 &&
              this.mario.vy >= 0) {
            this.mario.y = girder.gameY - this.mario.height;
            this.mario.vy = 0;
            this.mario.onGround = true;
            break;
          }
        } else if (girder.segments) {
          // Segment-based collision for traditional girders
          for (const segment of girder.segments) {
            if (this.mario.x + this.mario.width > segment.x && 
                this.mario.x < segment.x + segment.width &&
                this.mario.y + this.mario.height > segment.y &&
                this.mario.y + this.mario.height < segment.y + segment.height + 10 &&
                this.mario.vy >= 0) {
              this.mario.y = segment.y - this.mario.height;
              this.mario.vy = 0;
              this.mario.onGround = true;
              break;
            }
          }
        }
        if (this.mario.onGround) break;
      }
    }
    
    // Screen boundaries
    this.mario.x = Math.max(0, Math.min(this.width - this.mario.width, this.mario.x));
    
    // Update animation
    if (prevState !== this.mario.state || this.mario.vx !== 0 || this.mario.vy !== 0) {
      this.mario.animFrame += this.mario.animSpeed;
    }
  }
  
  updateDonkeyKong() {
    // Throw barrels periodically
    this.donkeyKong.throwTimer++;
    if (this.donkeyKong.throwTimer > 180) { // ~3 seconds at 60fps
      this.throwBarrel();
      this.donkeyKong.throwTimer = 0;
      this.donkeyKong.state = 'throwing_barrel';
    }
    
    if (this.donkeyKong.state === 'throwing_barrel') {
      this.donkeyKong.animFrame += 0.3;
      if (this.donkeyKong.animFrame >= 2) {
        this.donkeyKong.state = 'chest_beating';
        this.donkeyKong.animFrame = 0;
      }
    } else {
      this.donkeyKong.animFrame += 0.1;
    }
  }
  
  throwBarrel() {
    this.barrels.push({
      x: this.donkeyKong.x + 20,
      y: this.donkeyKong.y + 40,
      width: 16,
      height: 16,
      vx: -2 - Math.random(),
      vy: 0,
      onGround: false,
      animFrame: 0
    });
    
    // Barrel throw sound
    this.playSound('jumpbar', 0.4);
  }
  
  updateBarrels() {
    for (let i = this.barrels.length - 1; i >= 0; i--) {
      const barrel = this.barrels[i];
      
      // Update position
      barrel.x += barrel.vx;
      barrel.vy += 0.5; // gravity
      barrel.y += barrel.vy;
      barrel.animFrame += 0.2;
      
      // Platform and girder collisions
      barrel.onGround = false;
      
      // Check flat platforms first
      for (const platform of this.platforms) {
        if (barrel.x + barrel.width > platform.x && 
            barrel.x < platform.x + platform.width &&
            barrel.y + barrel.height > platform.y &&
            barrel.y + barrel.height < platform.y + platform.height + 10 &&
            barrel.vy >= 0) {
          barrel.y = platform.y - barrel.height;
          barrel.vy = 0;
          barrel.onGround = true;
          break;
        }
      }
      
      // Check angled girders if not on platform
      if (!barrel.onGround) {
        for (const girder of this.girders) {
          if (girder.type === 'sprite') {
            // Simple collision for sprite-based girders
            if (barrel.x + barrel.width > girder.gameX && 
                barrel.x < girder.gameX + girder.width &&
                barrel.y + barrel.height > girder.gameY &&
                barrel.y + barrel.height < girder.gameY + girder.height + 10 &&
                barrel.vy >= 0) {
              barrel.y = girder.gameY - barrel.height;
              barrel.vy = 0;
              barrel.onGround = true;
              break;
            }
          } else if (girder.segments) {
            // Segment-based collision for traditional girders
            for (const segment of girder.segments) {
              if (barrel.x + barrel.width > segment.x && 
                  barrel.x < segment.x + segment.width &&
                  barrel.y + barrel.height > segment.y &&
                  barrel.y + barrel.height < segment.y + segment.height + 10 &&
                  barrel.vy >= 0) {
                barrel.y = segment.y - barrel.height;
                barrel.vy = 0;
                barrel.onGround = true;
                // Add slight horizontal acceleration when rolling on angled girder
                if (girder.angle < 0) {
                  barrel.vx += -0.1; // Roll faster down left-to-right slopes
                } else {
                  barrel.vx += 0.1; // Roll faster down right-to-left slopes
                }
                break;
              }
            }
          }
          if (barrel.onGround) break;
        }
      }
      
      // Remove off-screen barrels
      if (barrel.x < -50 || barrel.y > this.height + 50) {
        this.barrels.splice(i, 1);
      }
    }
  }
  
  updateFireballs() {
    // Add fireballs occasionally from oil fires
    if (Math.random() < 0.005) {
      this.fireballs.push({
        x: Math.random() * this.width,
        y: this.height - 80,
        width: 8,
        height: 8,
        vx: (Math.random() - 0.5) * 2,
        vy: -Math.random() * 3,
        animFrame: 0,
        type: Math.floor(Math.random() * 3) // 0, 1, or 2 for different fireball types
      });
    }
    
    // Update fireballs
    for (let i = this.fireballs.length - 1; i >= 0; i--) {
      const fireball = this.fireballs[i];
      fireball.x += fireball.vx;
      fireball.y += fireball.vy;
      fireball.animFrame += 0.3;
      
      if (fireball.x < -20 || fireball.x > this.width + 20 || fireball.y > this.height + 20) {
        this.fireballs.splice(i, 1);
      }
    }
  }
  
  isOnLadder() {
    for (const ladder of this.ladders) {
      if (this.mario.x + this.mario.width/2 > ladder.x && 
          this.mario.x + this.mario.width/2 < ladder.x + ladder.width &&
          this.mario.y + this.mario.height > ladder.y &&
          this.mario.y < ladder.y + ladder.height) {
        return true;
      }
    }
    return false;
  }
  
  checkCollisions() {
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
          this.playSound('hammer', 0.6);
        } else {
          // Mario dies
          this.mario.state = 'death';
          this.lives--;
          this.playSound('death', 0.8);
          this.resetMarioPosition();
          if (this.lives <= 0) {
            this.gameOver();
          }
        }
      }
    }
    
    // Mario vs Hammers
    for (const hammer of this.hammers) {
      if (hammer.active &&
          this.mario.x < hammer.x + hammer.width &&
          this.mario.x + this.mario.width > hammer.x &&
          this.mario.y < hammer.y + hammer.height &&
          this.mario.y + this.mario.height > hammer.y) {
        hammer.active = false;
        this.mario.hasHammer = true;
        this.mario.hammerTimer = 600; // 10 seconds
        this.score += 100;
        this.playSound('itemget', 0.5);
      }
    }
    
    // Mario vs Pauline (win condition)
    if (this.mario.x < this.pauline.x + this.pauline.width &&
        this.mario.x + this.mario.width > this.pauline.x &&
        this.mario.y < this.pauline.y + this.pauline.height &&
        this.mario.y + this.mario.height > this.pauline.y) {
      this.score += 5000;
      this.level++;
      this.playSound('win1', 0.8);
      setTimeout(() => this.playSound('howhigh', 0.6), 500);
      this.nextLevel();
    }
  }
  
  resetMarioPosition() {
    this.mario.x = 50;
    this.mario.y = this.height - 100;
    this.mario.vx = 0;
    this.mario.vy = 0;
    this.mario.hasHammer = false;
    this.mario.state = 'standing';
  }
  
  nextLevel() {
    this.createLevel();
    this.resetMarioPosition();
    this.barrels = [];
    this.fireballs = [];
  }
  
  gameOver() {
    this.gameState = 'gameOver';
    this.stopBackgroundMusic();
    this.playSound('death', 0.8);
    
    if (this.gameOverElement) {
      this.gameOverElement.classList.remove('game-over-hidden');
    }
    if (this.finalScoreElement) {
      this.finalScoreElement.textContent = this.score.toString().padStart(6, '0');
    }
  }
  
  jump() {
    if (this.mario.onGround && !this.mario.onLadder) {
      this.mario.vy = -15;
      this.mario.onGround = false;
      this.mario.state = 'jumping';
      this.playSound('jump', 0.4);
    }
  }
  
  render() {
    try {
      // Clear screen with classic black background
      this.ctx.fillStyle = '#000000';
      this.ctx.fillRect(0, 0, this.width, this.height);
      
      if (this.gameState === 'loading') {
        this.renderLoading();
        return;
      }
      
      if (this.gameState === 'error') {
        return; // Error already rendered in handleGameError
      }
      
      // Render level structure
      this.renderLevel();
      
      // Render game objects
      this.renderDonkeyKong();
      this.renderPauline();
      this.renderBarrels();
      this.renderFireballs();
      this.renderHammers();
      
      // Render Mario last (on top)
      this.renderMario();
      
      // Debug info
      if (this.gameState === 'ready') {
        this.ctx.textAlign = 'center';
        this.ctx.fillStyle = '#FFFF00';
        this.ctx.font = '20px monospace';
        this.ctx.fillText('CLICK START TO PLAY', this.width/2, this.height/2);
        
        // Browser compatibility info
        this.renderCompatibilityInfo();
      }
    } catch (error) {
      console.error('Render error:', error);
      this.handleRenderError(error);
    }
  }
  
  renderCompatibilityInfo() {
    // Show browser compatibility status
    const features = this.checkBrowserCompatibility();
    let y = this.height - 100;
    
    this.ctx.font = '12px monospace';
    this.ctx.fillStyle = '#888888';
    this.ctx.textAlign = 'left';
    
    if (!features.canvas) {
      this.ctx.fillStyle = '#FF0000';
      this.ctx.fillText('⚠ Canvas not supported', 10, y);
    } else if (!features.audio) {
      this.ctx.fillStyle = '#FFAA00';  
      this.ctx.fillText('⚠ Audio limited', 10, y);
    } else {
      this.ctx.fillStyle = '#00FF00';
      this.ctx.fillText('✓ Full compatibility', 10, y);
    }
  }
  
  checkBrowserCompatibility() {
    return {
      canvas: !!this.ctx,
      audio: !!(window.Audio && window.AudioContext || window.webkitAudioContext),
      requestAnimationFrame: !!window.requestAnimationFrame,
      performance: !!(window.performance && window.performance.memory)
    };
  }
  
  handleRenderError(error) {
    console.error('Critical render error:', error);
    
    try {
      this.ctx.fillStyle = '#FF0000';
      this.ctx.font = '16px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.fillText('RENDER ERROR', this.width/2, this.height/2);
      this.ctx.fillText('Please refresh browser', this.width/2, this.height/2 + 25);
    } catch (e) {
      console.error('Cannot render error message:', e);
    }
  }
  
  renderLoading() {
    this.ctx.fillStyle = '#FFFF00';
    this.ctx.font = '24px monospace';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('🎮 LOADING HONKY PONG...', this.width/2, this.height/2);
  }
  
  renderLevel() {
    try {
      // Render flat platforms (ground and top)
      this.ctx.fillStyle = '#FF6B47'; // Classic DK red/orange girder color
      for (const platform of this.platforms) {
        this.ctx.fillRect(platform.x, platform.y, platform.width, platform.height);
        
        // Add girder rivets/details
        this.ctx.fillStyle = '#8B4513';
        for (let x = platform.x + 10; x < platform.x + platform.width - 10; x += 20) {
          this.ctx.fillRect(x, platform.y + 2, 3, 3);
          this.ctx.fillRect(x, platform.y + platform.height - 5, 3, 3);
        }
        this.ctx.fillStyle = '#FF6B47'; // Reset color
      }
      
      // Render angled girders (authentic DK look from sprites)
      this.ctx.lineWidth = 18; // Slightly thinner for authenticity
      
      for (const girder of this.girders) {
        if (girder.type === 'sprite') {
          if (!this.sprites.levels) {
            console.warn('❌ levels.png sprite not loaded yet');
          } else {
            // Render using authentic extracted sprite
            const spriteData = this.spriteCoords[girder.spriteType];
            if (spriteData) {
              this.ctx.drawImage(
                this.sprites.levels,
                spriteData.x, spriteData.y, spriteData.width, spriteData.height, // Source from sprite
                girder.gameX, girder.gameY, girder.width, girder.height // Destination on game canvas
              );
              console.log(`🎨 Rendered authentic ${girder.spriteType} sprite at (${girder.gameX}, ${girder.gameY})`);
            } else {
              console.warn(`❌ No sprite data for ${girder.spriteType}`);
            }
          }
        } else {
          // Fallback to line rendering for non-sprite girders
          const girderColor = girder.color || '#FF6B47';
          this.ctx.strokeStyle = girderColor;
          this.ctx.fillStyle = girderColor;
          
          // Draw main angled girder line with authentic thickness
          this.ctx.beginPath();
          this.ctx.moveTo(girder.startX, girder.startY);
          this.ctx.lineTo(girder.endX, girder.endY);
          this.ctx.stroke();
        }
        
        // Add authentic girder rivets/supports
        const girderLength = Math.sqrt(
          Math.pow(girder.endX - girder.startX, 2) + 
          Math.pow(girder.endY - girder.startY, 2)
        );
        const numSupports = Math.max(6, Math.floor(girderLength / 100));
        const stepX = (girder.endX - girder.startX) / numSupports;
        const stepY = (girder.endY - girder.startY) / numSupports;
        
        // Draw support rivets in darker color
        this.ctx.fillStyle = '#8B4513';
        
        for (let i = 1; i < numSupports; i++) {
          const supportX = girder.startX + (stepX * i);
          const supportY = girder.startY + (stepY * i);
          
          // Draw small rectangular rivets above and below girder line
          this.ctx.fillRect(supportX - 2, supportY - 12, 4, 4);
          this.ctx.fillRect(supportX - 2, supportY + 8, 4, 4);
        }
      }
      
      // Render ladders with authentic look
      this.ctx.fillStyle = '#DAA520';
      this.ctx.strokeStyle = '#B8860B';
      this.ctx.lineWidth = 2;
      
      for (const ladder of this.ladders) {
        if (ladder.type === 'sprite' && this.sprites.levels) {
          // Render using authentic extracted ladder sprite
          const spriteData = this.spriteCoords[ladder.spriteType];
          if (spriteData) {
            // Tile the ladder sprite to fill the required height
            const spriteHeight = spriteData.height;
            let currentY = ladder.y;
            
            while (currentY < ladder.y + ladder.height) {
              const remainingHeight = (ladder.y + ladder.height) - currentY;
              const drawHeight = Math.min(spriteHeight, remainingHeight);
              
              this.ctx.drawImage(
                this.sprites.levels,
                spriteData.x, spriteData.y, spriteData.width, drawHeight, // Source from sprite
                ladder.x, currentY, ladder.width, drawHeight // Destination on game canvas
              );
              
              currentY += spriteHeight;
            }
            console.log(`🪜 Rendered authentic ladder sprite at (${ladder.x}, ${ladder.y})`);
          }
        } else {
          // Fallback to line rendering for non-sprite ladders
          // Draw ladder sides
          this.ctx.beginPath();
          this.ctx.moveTo(ladder.x + 2, ladder.y);
          this.ctx.lineTo(ladder.x + 2, ladder.y + ladder.height);
          this.ctx.moveTo(ladder.x + 14, ladder.y);
          this.ctx.lineTo(ladder.x + 14, ladder.y + ladder.height);
          this.ctx.stroke();
          
          // Draw ladder rungs
          for (let y = ladder.y + 8; y < ladder.y + ladder.height - 8; y += 12) {
            this.ctx.beginPath();
            this.ctx.moveTo(ladder.x + 2, y);
            this.ctx.lineTo(ladder.x + 14, y);
            this.ctx.stroke();
          }
        }
      }
      
      // Oil fires at bottom with flame effect
      this.ctx.fillStyle = '#FF4500';
      const flameFlicker = Math.sin(this.gameTime * 0.3) * 3;
      
      // Left oil fire
      this.ctx.fillRect(20, this.height - 30, 16, 20);
      this.ctx.fillStyle = '#FF6600';
      this.ctx.fillRect(22, this.height - 35 + flameFlicker, 12, 10);
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.fillRect(26, this.height - 40 + flameFlicker, 4, 8);
      
      // Right oil fire  
      this.ctx.fillStyle = '#FF4500';
      this.ctx.fillRect(this.width - 40, this.height - 30, 16, 20);
      this.ctx.fillStyle = '#FF6600';
      this.ctx.fillRect(this.width - 38, this.height - 35 + flameFlicker, 12, 10);
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.fillRect(this.width - 34, this.height - 40 + flameFlicker, 4, 8);
      
    } catch (error) {
      console.warn('Level render error:', error);
      // Simple fallback
      this.ctx.fillStyle = '#FF6B47';
      this.ctx.fillRect(0, this.height - 40, this.width, 40);
    }
  }
  
  renderMario() {
    try {
      // Power-up glow effect for hammer
      if (this.mario.hasHammer) {
        const glowSize = 8 + Math.sin(this.gameTime * 0.2) * 2;
        this.ctx.shadowBlur = glowSize;
        this.ctx.shadowColor = '#FFFF00';
      }
      
      if (!this.sprites.mario) {
        // Fallback rendering
        this.ctx.fillStyle = this.mario.hasHammer ? '#FF0000' : '#0000FF';
        this.ctx.fillRect(this.mario.x, this.mario.y, this.mario.width, this.mario.height);
        this.ctx.shadowBlur = 0;
        return;
      }
      
      // Use our precise sprite extraction data
      let sourceX = 0, sourceY = 0;
      const frameIndex = Math.floor(this.mario.animFrame) % 4;
      
      switch (this.mario.state) {
        case 'standing':
          sourceY = 0; // Row 1
          sourceX = this.mario.facing === 'left' ? 120 : 160; // Stand frames
          break;
        case 'running':
          sourceY = 0; // Row 1  
          sourceX = this.mario.facing === 'left' ? 
                    [40, 80][frameIndex % 2] :   // Left running frames
                    [200, 240][frameIndex % 2];  // Right running frames
          break;
        case 'climbing':
          sourceY = 40; // Row 2 - ladder climbing
          sourceX = Math.min(frameIndex * 40, 280); // 8 climbing frames
          break;
        case 'hammer':
          sourceY = 80; // Row 3 - with hammer
          sourceX = this.mario.facing === 'left' ? 
                    frameIndex * 40 : // Left hammer frames  
                    160 + (frameIndex * 40); // Right hammer frames
          break;
        case 'death':
        case 'tumbling':
          sourceY = 120; // Row 4 - tumbling
          sourceX = frameIndex * 40;
          break;
      }
      
      this.ctx.drawImage(
        this.sprites.mario,
        sourceX, sourceY, 24, 24, // Source
        this.mario.x, this.mario.y, this.mario.width, this.mario.height // Destination
      );
      
      // Reset shadow
      this.ctx.shadowBlur = 0;
      
    } catch (error) {
      console.warn('Mario render error:', error);
      // Simple fallback
      this.ctx.fillStyle = '#0000FF';
      this.ctx.fillRect(this.mario.x, this.mario.y, this.mario.width, this.mario.height);
    }
  }
  
  renderDonkeyKong() {
    if (!this.sprites.enemies) {
      this.ctx.fillStyle = '#8B4513';
      this.ctx.fillRect(this.donkeyKong.x, this.donkeyKong.y, this.donkeyKong.width, this.donkeyKong.height);
      return;
    }
    
    // Use DK sprites from enemies sheet
    let sourceX = 1, sourceY = 57; // DK Row 2 coordinates
    const frameIndex = Math.floor(this.donkeyKong.animFrame) % 5;
    
    if (this.donkeyKong.state === 'throwing_barrel') {
      sourceX = 1; // Rolling barrel left
    } else {
      // Chest beating cycle
      const poses = [50, 103, 150]; // Left arm, both arms, right arm
      sourceX = poses[frameIndex % 3];
    }
    
    this.ctx.drawImage(
      this.sprites.enemies,
      sourceX, sourceY, 46, 31, // Source (widest DK sprite)
      this.donkeyKong.x, this.donkeyKong.y, this.donkeyKong.width, this.donkeyKong.height
    );
  }
  
  renderPauline() {
    if (!this.sprites.pauline) {
      this.ctx.fillStyle = '#FF69B4';
      this.ctx.fillRect(this.pauline.x, this.pauline.y, this.pauline.width, this.pauline.height);
      return;
    }
    
    // Pauline calling for help
    const frameIndex = Math.floor(this.pauline.animFrame) % 2;
    const sourceX = frameIndex === 0 ? 0 : 50; // Left running frames for animation
    
    this.ctx.drawImage(
      this.sprites.pauline,
      sourceX, 0, 15, 22, // Source
      this.pauline.x, this.pauline.y, this.pauline.width, this.pauline.height
    );
    
    // Help text
    this.ctx.fillStyle = '#FFFF00';
    this.ctx.font = '12px monospace';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('HELP!', this.pauline.x + this.pauline.width/2, this.pauline.y - 5);
  }
  
  renderBarrels() {
    if (!this.sprites.enemies) {
      this.ctx.fillStyle = '#8B4513';
      for (const barrel of this.barrels) {
        this.ctx.fillRect(barrel.x, barrel.y, barrel.width, barrel.height);
      }
      return;
    }
    
    for (const barrel of this.barrels) {
      // Use barrel sprites (2x2 grid)
      const frame = Math.floor(barrel.animFrame) % 4;
      const sourceX = frame % 2 === 0 ? 5 : 5; // Top/bottom barrel sprites
      const sourceY = frame < 2 ? 7 : 27; // Left/right position
      
      this.ctx.drawImage(
        this.sprites.enemies,
        sourceX, sourceY, 15, 10, // Barrel sprite size
        barrel.x, barrel.y, barrel.width, barrel.height
      );
    }
  }
  
  renderFireballs() {
    if (!this.sprites.enemies) {
      this.ctx.fillStyle = '#FF4500';
      for (const fireball of this.fireballs) {
        this.ctx.fillRect(fireball.x, fireball.y, fireball.width, fireball.height);
      }
      return;
    }
    
    for (const fireball of this.fireballs) {
      // Use different fireball sprites based on type
      let sourceX = 102, sourceY = 7; // Default fireball position
      
      switch (fireball.type) {
        case 0: sourceX = 102; sourceY = 7; break;   // Fireballs 1
        case 1: sourceX = 153; sourceY = 7; break;   // Fireballs 2  
        case 2: sourceX = 204; sourceY = 7; break;   // Blue fireballs
      }
      
      const frame = Math.floor(fireball.animFrame) % 4;
      sourceX += (frame % 2) * 25;
      sourceY += Math.floor(frame / 2) * 20;
      
      this.ctx.drawImage(
        this.sprites.enemies,
        sourceX, sourceY, 10, 10,
        fireball.x, fireball.y, fireball.width, fireball.height
      );
    }
  }
  
  renderHammers() {
    if (!this.sprites.enemies) {
      this.ctx.fillStyle = '#FFD700';
      for (const hammer of this.hammers) {
        if (hammer.active) {
          this.ctx.fillRect(hammer.x, hammer.y, hammer.width, hammer.height);
        }
      }
      return;
    }
    
    for (const hammer of this.hammers) {
      if (hammer.active) {
        // Use hammer sprite
        this.ctx.drawImage(
          this.sprites.enemies,
          269, 54, 7, 15, // Hammer coordinates
          hammer.x, hammer.y, hammer.width, hammer.height
        );
      }
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
  }
  
  // Controller interface methods
  handleKeyDown(event) {
    console.log('🎮 DEBUG: Key pressed:', event.code, 'Keys object:', this.keys);
    this.keys[event.code] = true;
    
    // Prevent default browser behavior for game controls
    if (event.code === 'Space' || 
        event.code === 'ArrowUp' || 
        event.code === 'ArrowDown' || 
        event.code === 'ArrowLeft' || 
        event.code === 'ArrowRight') {
      console.log('🚫 DEBUG: Preventing default for:', event.code);
      event.preventDefault();
    }
    
    if (event.code === 'Space') {
      console.log('🦘 DEBUG: Jump triggered!');
      this.jump();
    }
    
    if (event.code === 'KeyR' && this.gameState === 'gameOver') {
      this.restartGame();
    }
  }
  
  handleKeyUp(event) {
    this.keys[event.code] = false;
  }
  
  destroy() {
    this.gameState = 'destroyed';
  }
}