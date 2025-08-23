// Hackman Game - Professional High-End Pac-Man Clone
import { AudioManager } from "audio_manager"

export class HackmanGame {
  constructor(options = {}) {
    // Professional dependency injection
    this.canvas = options.canvas || document.getElementById('gameCanvas');
    this.scoreElement = options.scoreElement || document.getElementById('score');
    this.livesElement = options.livesElement || document.getElementById('lives');
    this.levelElement = options.levelElement || document.getElementById('level');
    this.startButton = options.startButton || document.getElementById('startButton');
    this.gameOverElement = options.gameOverElement || document.getElementById('gameOver');
    this.finalScoreElement = options.finalScoreElement || document.getElementById('finalScore');
    this.restartButton = options.restartButton || document.getElementById('restartButton');
    
    if (!this.canvas) {
      throw new Error('Game canvas not found!');
    }
    
    this.ctx = this.canvas.getContext('2d');
    this.gameState = 'menu'; // menu, playing, paused, gameOver, victory
    
    // High-end graphics configuration
    this.TILE_SIZE = 20;
    this.MAZE_WIDTH = 28;
    this.MAZE_HEIGHT = 31;
    this.canvas.width = this.MAZE_WIDTH * this.TILE_SIZE;
    this.canvas.height = this.MAZE_HEIGHT * this.TILE_SIZE + 60; // Extra space for HUD
    
    // Game state
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.frameCounter = 0;
    this.gameSpeed = 10; // Ticks per second (higher number = slower game)
    this.lastMoveTime = 0;
    
    // Hackman (player) state
    this.hackman = {
      x: 14, // Maze center
      y: 23,
      direction: 0, // 0=right, 1=down, 2=left, 3=up
      mouthAnimation: 0,
      isMoving: false
    };
    
    // Jeans (ghosts) state  
    this.jeans = [
      { name: 'Levi', x: 14, y: 11, direction: 0, mode: 'chase', color: '#FF0000', targetX: 0, targetY: 0, inPen: false, releaseTimer: 0 },
      { name: 'Wrangler', x: 14, y: 14, direction: 0, mode: 'chase', color: '#FFB8FF', targetX: 27, targetY: 0, inPen: true, releaseTimer: 60 },
      { name: 'Lee', x: 14, y: 14, direction: 0, mode: 'chase', color: '#00FFFF', targetX: 0, targetY: 30, inPen: true, releaseTimer: 120 },
      { name: 'Diesel', x: 14, y: 14, direction: 0, mode: 'scatter', color: '#FFB852', targetX: 27, targetY: 30, inPen: true, releaseTimer: 180 }
    ];
    
    // Game timers
    this.modeTimer = 0;
    this.modePhase = 'chase'; // 'chase' or 'scatter'
    this.frightenedTimer = 0;
    this.frightenedMode = false;
    this.ghostEatenMultiplier = 200;
    
    // Initialize maze and items
    this.maze = [];
    this.bitcoins = new Set();
    this.powerBitcoins = new Set();
    this.totalBitcoins = 0;
    
    // Controls
    this.keys = {};
    
    // Professional audio system
    this.audioManager = new AudioManager();
    this.sounds = {
      chomp: () => this.audioManager.playSound("coin"),
      powerUp: () => this.audioManager.playSound("powerUp"),
      eatGhost: () => this.audioManager.playSound("barrel"),
      death: () => this.audioManager.playSound("death"),
      victory: () => this.audioManager.playSound("levelComplete")
    };
    
    // High-end visual effects
    this.particles = [];
    this.maxParticles = 100;
    this.scorePopups = [];
    
    this.initializeMaze();
    this.init();
  }
  
  // Professional maze generation with authentic Pac-Man layout
  initializeMaze() {
    // Create classic Pac-Man maze layout
    const mazeLayout = [
      "############################",
      "#............##............#",
      "#.####.#####.##.#####.####.#",
      "#*####.#####.##.#####.####*#",
      "#.####.#####.##.#####.####.#",
      "#..........................#",
      "#.####.##.########.##.####.#",
      "#.####.##.########.##.####.#",
      "#......##....##....##......#",
      "######.##### ## #####.######",
      "######.##### ## #####.######",
      "######.##          ##.######",
      "######.## ###--### ##.######",
      "######.## #      # ##.######",
      "      .   #      #   .      ",
      "######.## #      # ##.######",
      "######.## ######## ##.######",
      "######.##          ##.######",
      "######.## ######## ##.######",
      "######.## ######## ##.######",
      "#............##............#",
      "#.####.#####.##.#####.####.#",
      "#.####.#####.##.#####.####.#",
      "#*..##................##..*#",
      "###.##.##.########.##.##.###",
      "###.##.##.########.##.##.###",
      "#......##....##....##......#",
      "#.##########.##.##########.#",
      "#.##########.##.##########.#",
      "#..........................#",
      "############################"
    ];
    
    this.maze = [];
    this.bitcoins.clear();
    this.powerBitcoins.clear();
    
    for (let y = 0; y < this.MAZE_HEIGHT; y++) {
      this.maze[y] = [];
      for (let x = 0; x < this.MAZE_WIDTH; x++) {
        const char = mazeLayout[y] ? mazeLayout[y][x] : '#';
        
        switch (char) {
          case '#':
            this.maze[y][x] = 'wall';
            break;
          case '.':
            this.maze[y][x] = 'path';
            this.bitcoins.add(`${x},${y}`);
            break;
          case '*':
            this.maze[y][x] = 'path';
            this.powerBitcoins.add(`${x},${y}`);
            break;
          case '-':
            this.maze[y][x] = 'door'; // Ghost pen door
            break;
          case ' ':
            this.maze[y][x] = 'path';
            break;
          default:
            this.maze[y][x] = 'path';
        }
      }
    }
    
    this.totalBitcoins = this.bitcoins.size + this.powerBitcoins.size;
  }
  
  init() {
    this.setupControls();
    this.setupButtons();
    this.gameLoop();
  }
  
  setupControls() {
    this.keyDownHandler = (e) => {
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'KeyW', 'KeyA', 'KeyS', 'KeyD', 'Space', 'Enter'].includes(e.code)) {
        e.preventDefault();
      }
      
      const wasPressed = this.keys[e.code];
      this.keys[e.code] = true;
      
      // No need to set direction here for continuous movement
      
      if ((e.code === 'Enter' || e.code === 'Space') && this.gameState === 'menu') {
        this.startGame();
      }
    };
    
    this.keyUpHandler = (e) => {
      this.keys[e.code] = false;
    };
    
    document.addEventListener('keydown', this.keyDownHandler);
    document.addEventListener('keyup', this.keyUpHandler);
    
    this.canvas.setAttribute('tabindex', '0');
    this.canvas.focus();
  }
  
  setupButtons() {
    if (this.startButton) {
      this.startButton.addEventListener('click', () => {
        this.startGame();
      });
    }
    
    if (this.restartButton) {
      this.restartButton.addEventListener('click', () => {
        this.restartGame();
      });
    }
  }
  
  startGame() {
    this.gameState = 'playing';
    this.resetLevel();
    this.updateUI();
  }
  
  resetLevel() {
    // Reset Hackman position
    this.hackman.x = 14;
    this.hackman.y = 23;
    this.hackman.direction = 0;
    this.hackman.mouthAnimation = 0;
    
    // Reset ghosts - start all ghosts outside for now to test
    for (let i = 0; i < this.jeans.length; i++) {
      this.jeans[i].x = 14;
      this.jeans[i].y = 11;
      this.jeans[i].direction = 0;
      this.jeans[i].inPen = false;
      this.jeans[i].releaseTimer = 0;
      this.jeans[i].mode = i === 3 ? 'scatter' : 'chase'; // Diesel starts in scatter
    }
    
    // Reset game state
    this.modeTimer = 0;
    this.modePhase = 'chase';
    this.frightenedTimer = 0;
    this.frightenedMode = false;
    this.ghostEatenMultiplier = 200;
    this.frameCounter = 0;
  }
  
  restartGame() {
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.initializeMaze();
    this.resetLevel();
    this.updateUI();
    this.startGame();
  }
  
  // High-end rendering system
  render() {
    // Clear with professional black background
    this.ctx.fillStyle = '#000000';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    
    this.renderMaze();
    this.renderItems();
    this.renderHackman();
    this.renderJeans();
    this.renderParticles();
    this.renderScorePopups();
    this.renderGameStateOverlays();
    this.renderHUD();
  }
  
  renderMaze() {
    for (let y = 0; y < this.MAZE_HEIGHT; y++) {
      for (let x = 0; x < this.MAZE_WIDTH; x++) {
        if (this.maze[y][x] === 'wall') {
          this.renderWall(x, y);
        }
      }
    }
  }
  
  // Professional wall rendering with 3D effect
  renderWall(x, y) {
    const px = x * this.TILE_SIZE;
    const py = y * this.TILE_SIZE;
    
    // Main wall body - classic blue
    this.ctx.fillStyle = '#2121FF';
    this.ctx.fillRect(px, py, this.TILE_SIZE, this.TILE_SIZE);
    
    // 3D highlights
    this.ctx.fillStyle = '#4A4AFF';
    this.ctx.fillRect(px, py, this.TILE_SIZE, 2);
    this.ctx.fillRect(px, py, 2, this.TILE_SIZE);
    
    // 3D shadows
    this.ctx.fillStyle = '#1010AA';
    this.ctx.fillRect(px, py + this.TILE_SIZE - 2, this.TILE_SIZE, 2);
    this.ctx.fillRect(px + this.TILE_SIZE - 2, py, 2, this.TILE_SIZE);
  }
  
  renderItems() {
    // Render Bitcoins
    for (let pos of this.bitcoins) {
      const [x, y] = pos.split(',').map(Number);
      this.renderBitcoin(x, y);
    }
    
    // Render Power Bitcoins
    for (let pos of this.powerBitcoins) {
      const [x, y] = pos.split(',').map(Number);
      this.renderPowerBitcoin(x, y);
    }
  }
  
  // Professional Bitcoin rendering
  renderBitcoin(x, y) {
    const px = x * this.TILE_SIZE + this.TILE_SIZE / 2;
    const py = y * this.TILE_SIZE + this.TILE_SIZE / 2;
    
    this.ctx.fillStyle = '#FFD700';
    this.ctx.beginPath();
    this.ctx.arc(px, py, 2, 0, Math.PI * 2);
    this.ctx.fill();
    
    // Glow effect
    this.ctx.shadowColor = '#FFD700';
    this.ctx.shadowBlur = 4;
    this.ctx.beginPath();
    this.ctx.arc(px, py, 2, 0, Math.PI * 2);
    this.ctx.fill();
    this.ctx.shadowBlur = 0;
  }
  
  // Professional Power Bitcoin with pulsing effect
  renderPowerBitcoin(x, y) {
    const px = x * this.TILE_SIZE + this.TILE_SIZE / 2;
    const py = y * this.TILE_SIZE + this.TILE_SIZE / 2;
    
    const pulse = Math.sin(this.frameCounter * 0.2) * 0.3 + 0.7;
    const radius = 6 * pulse;
    
    this.ctx.fillStyle = '#FFD700';
    this.ctx.beginPath();
    this.ctx.arc(px, py, radius, 0, Math.PI * 2);
    this.ctx.fill();
    
    // Intense glow effect
    this.ctx.shadowColor = '#FFD700';
    this.ctx.shadowBlur = 12 * pulse;
    this.ctx.beginPath();
    this.ctx.arc(px, py, radius, 0, Math.PI * 2);
    this.ctx.fill();
    this.ctx.shadowBlur = 0;
  }
  
  renderHackman() {
    const px = this.hackman.x * this.TILE_SIZE + this.TILE_SIZE / 2;
    const py = this.hackman.y * this.TILE_SIZE + this.TILE_SIZE / 2;
    
    this.ctx.save();
    this.ctx.translate(px, py);
    this.ctx.rotate(this.hackman.direction * Math.PI / 2);
    
    // Mouth animation
    const mouthAngle = Math.sin(this.hackman.mouthAnimation * 0.5) * 0.8 + 0.2;
    
    // Flashing effect when power mode is about to expire (classic Pac-Man style)
    let hackmanColor = '#FFFF00';
    if (this.frightenedMode && this.frightenedTimer <= 120) { // Last 12 seconds at 10 fps
      const flashSpeed = this.frightenedTimer <= 60 ? 3 : 6; // Flash faster in last 6 seconds
      if (this.frightenedTimer % flashSpeed < flashSpeed / 2) {
        hackmanColor = '#FFFFFF'; // Flash white
      }
    }
    
    // Body
    this.ctx.fillStyle = hackmanColor;
    this.ctx.beginPath();
    this.ctx.arc(0, 0, 8, mouthAngle, Math.PI * 2 - mouthAngle);
    this.ctx.lineTo(0, 0);
    this.ctx.closePath();
    this.ctx.fill();
    
    // Glow effect
    this.ctx.shadowColor = hackmanColor;
    this.ctx.shadowBlur = 8;
    this.ctx.beginPath();
    this.ctx.arc(0, 0, 8, mouthAngle, Math.PI * 2 - mouthAngle);
    this.ctx.lineTo(0, 0);
    this.ctx.closePath();
    this.ctx.fill();
    this.ctx.shadowBlur = 0;
    
    this.ctx.restore();
    
    if (this.hackman.isMoving) {
      this.hackman.mouthAnimation += 0.5;
    }
  }
  
  renderJeans() {
    for (let jean of this.jeans) {
      // Debug: Show Levi's status
      if (jean.name === 'Levi' && this.frameCounter % 60 === 0) {
        console.log(`Levi status: x=${jean.x}, y=${jean.y}, inPen=${jean.inPen}, releaseTimer=${jean.releaseTimer}`);
      }
      // Render all ghosts, whether in pen or not
      
      const px = jean.x * this.TILE_SIZE + this.TILE_SIZE / 2;
      const py = jean.y * this.TILE_SIZE + this.TILE_SIZE / 2;
      
      let color = jean.color;
      if (this.frightenedMode) {
        if (this.frightenedTimer <= 120) {
          // Flash faster as time runs out
          const flashSpeed = this.frightenedTimer <= 60 ? 5 : 10;
          if (this.frightenedTimer % flashSpeed < flashSpeed/2) {
            color = '#FFFFFF'; // Flash white when frightened mode ending
          } else {
            color = '#0000FF'; // Blue when frightened
          }
        } else {
          color = '#0000FF'; // Blue when frightened
        }
      }
      
      // Ghost body
      this.ctx.fillStyle = color;
      this.ctx.beginPath();
      this.ctx.arc(px, py - 2, 8, Math.PI, 0);
      this.ctx.rect(px - 8, py - 2, 16, 12);
      this.ctx.fill();
      
      // Ghost bottom with wavy effect
      this.ctx.beginPath();
      for (let i = 0; i < 4; i++) {
        const wave = Math.sin((this.frameCounter + i * 2) * 0.3) * 2;
        this.ctx.lineTo(px - 8 + i * 4, py + 10 + wave);
        this.ctx.lineTo(px - 6 + i * 4, py + 6 + wave);
      }
      this.ctx.lineTo(px + 8, py + 10);
      this.ctx.lineTo(px + 8, py - 2);
      this.ctx.closePath();
      this.ctx.fill();
      
      // Eyes
      if (!this.frightenedMode) {
        this.ctx.fillStyle = '#FFFFFF';
        this.ctx.fillRect(px - 5, py - 5, 3, 4);
        this.ctx.fillRect(px + 2, py - 5, 3, 4);
        
        this.ctx.fillStyle = '#000000';
        this.ctx.fillRect(px - 4, py - 4, 1, 2);
        this.ctx.fillRect(px + 3, py - 4, 1, 2);
      } else {
        // Frightened eyes
        this.ctx.fillStyle = '#FF0000';
        this.ctx.fillRect(px - 3, py - 3, 2, 2);
        this.ctx.fillRect(px + 1, py - 3, 2, 2);
      }
      
      // Glow effect
      this.ctx.shadowColor = color;
      this.ctx.shadowBlur = 6;
      this.ctx.fillStyle = color;
      this.ctx.globalAlpha = 0.5;
      this.ctx.beginPath();
      this.ctx.arc(px, py, 10, 0, Math.PI * 2);
      this.ctx.fill();
      this.ctx.globalAlpha = 1;
      this.ctx.shadowBlur = 0;
    }
  }
  
  renderParticles() {
    for (let particle of this.particles) {
      let alpha = particle.life / particle.maxLife;
      this.ctx.save();
      this.ctx.globalAlpha = alpha;
      this.ctx.fillStyle = particle.color;
      
      this.ctx.beginPath();
      this.ctx.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2);
      this.ctx.fill();
      
      this.ctx.restore();
    }
  }
  
  renderGameStateOverlays() {
    if (this.gameState === 'menu') {
      this.ctx.fillStyle = 'rgba(0, 0, 0, 0.8)';
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
      
      // Title
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.font = 'bold 36px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.fillText('HACKMAN', this.canvas.width / 2, this.canvas.height / 2 - 60);
      
      // Subtitle
      this.ctx.fillStyle = '#FFD700';
      this.ctx.font = 'bold 18px monospace';
      this.ctx.fillText('Eat the Bitcoin, Avoid the Jeans!', this.canvas.width / 2, this.canvas.height / 2 - 20);
      
      // Instructions
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.font = '14px monospace';
      this.ctx.fillText('Use ARROW KEYS or WASD to move', this.canvas.width / 2, this.canvas.height / 2 + 20);
      
      this.ctx.fillStyle = '#00FF00';
      this.ctx.font = 'bold 16px monospace';
      this.ctx.fillText('PRESS SPACE or ENTER to start!', this.canvas.width / 2, this.canvas.height / 2 + 60);
    }
  }
  
  renderHUD() {
    const hudY = this.canvas.height - 50;
    
    // Score
    this.ctx.fillStyle = '#FFFF00';
    this.ctx.font = 'bold 16px monospace';
    this.ctx.textAlign = 'left';
    this.ctx.fillText(`SCORE: ${this.score}`, 10, hudY);
    
    // Lives
    this.ctx.fillText(`LIVES: ${this.lives}`, 10, hudY + 20);
    
    // Level
    this.ctx.textAlign = 'center';
    this.ctx.fillText(`LEVEL ${this.level}`, this.canvas.width / 2, hudY);
    
    // Remaining items
    const remaining = this.bitcoins.size + this.powerBitcoins.size;
    this.ctx.fillText(`BITCOIN LEFT: ${remaining}`, this.canvas.width / 2, hudY + 20);
    
    // Mode indicator
    if (this.frightenedMode) {
      this.ctx.fillStyle = '#0000FF';
      this.ctx.textAlign = 'right';
      this.ctx.fillText(`POWER MODE: ${Math.ceil(this.frightenedTimer / 10)}s`, this.canvas.width - 10, hudY);
    }
  }
  
  updateUI() {
    if (this.scoreElement) this.scoreElement.textContent = this.score.toString().padStart(6, '0');
    if (this.livesElement) this.livesElement.textContent = this.lives;
    if (this.levelElement) this.levelElement.textContent = this.level;
  }
  
  gameLoop() {
    this.frameCounter++;
    
    if (this.gameState === 'playing') {
      // Game logic at reduced speed
      if (this.frameCounter % this.gameSpeed === 0) {
        this.updateGame();
      }
      
      this.updateParticles();
      this.updateScorePopups();
    }
    
    this.render();
    
    requestAnimationFrame(() => this.gameLoop());
  }
  
  updateGame() {
    // Update mode timers
    this.updateModeTimers();
    
    // Move Hackman
    this.moveHackman();
    
    // Move Jeans
    this.moveJeans();
    
    // Check collisions
    this.checkCollisions();
    
    // Check win condition
    if (this.bitcoins.size === 0 && this.powerBitcoins.size === 0) {
      this.victory();
    }
  }
  
  updateModeTimers() {
    // Frightened mode timer
    if (this.frightenedMode) {
      this.frightenedTimer--;
      if (this.frightenedTimer <= 0) {
        console.log('Frightened mode ending');
        this.frightenedMode = false;
        this.ghostEatenMultiplier = 200;
        
        // Reset ghost modes
        for (let jean of this.jeans) {
          if (!jean.inPen) {
            jean.mode = this.modePhase;
            console.log(`Reset ${jean.name} to ${this.modePhase} mode`);
          }
        }
      }
    }
    
    // Chase/Scatter mode timer
    this.modeTimer++;
    const phaseLength = this.modePhase === 'chase' ? 1200 : 420; // 20s chase, 7s scatter
    
    if (this.modeTimer >= phaseLength) {
      this.modeTimer = 0;
      this.modePhase = this.modePhase === 'chase' ? 'scatter' : 'chase';
      
      // Update ghost modes
      for (let jean of this.jeans) {
        if (!this.frightenedMode) {
          jean.mode = this.modePhase;
        }
      }
    }
  }
  
  moveHackman() {
    let newDirection = this.hackman.direction;
    
    // Check for currently held direction keys
    if (this.keys['ArrowUp'] || this.keys['KeyW']) {
      newDirection = 3; // Up
    } else if (this.keys['ArrowDown'] || this.keys['KeyS']) {
      newDirection = 1; // Down
    } else if (this.keys['ArrowLeft'] || this.keys['KeyA']) {
      newDirection = 2; // Left
    } else if (this.keys['ArrowRight'] || this.keys['KeyD']) {
      newDirection = 0; // Right
    }
    
    // Try to change direction if requested
    if (newDirection !== this.hackman.direction && this.canMove(this.hackman.x, this.hackman.y, newDirection)) {
      this.hackman.direction = newDirection;
    }
    
    // Move in current direction if possible and if any movement key is held
    const anyMovementKeyHeld = this.keys['ArrowUp'] || this.keys['ArrowDown'] || 
                              this.keys['ArrowLeft'] || this.keys['ArrowRight'] ||
                              this.keys['KeyW'] || this.keys['KeyA'] || 
                              this.keys['KeyS'] || this.keys['KeyD'];
    
    if (anyMovementKeyHeld && this.canMove(this.hackman.x, this.hackman.y, this.hackman.direction)) {
      const [dx, dy] = this.getDirectionVector(this.hackman.direction);
      this.hackman.x += dx;
      this.hackman.y += dy;
      this.hackman.isMoving = true;
      
      // Handle tunnel wrapping
      if (this.hackman.x < 0) this.hackman.x = this.MAZE_WIDTH - 1;
      if (this.hackman.x >= this.MAZE_WIDTH) this.hackman.x = 0;
    } else {
      this.hackman.isMoving = false;
    }
  }
  
  moveJeans() {
    // Slow down ghosts for level 1 - only move every other frame
    if (this.frameCounter % 2 !== 0) return;
    
    for (let jean of this.jeans) {
      // Handle release timer
      if (jean.inPen && jean.releaseTimer > 0) {
        jean.releaseTimer--;
        continue;
      }
      
      if (jean.inPen && jean.releaseTimer <= 0) {
        jean.inPen = false;
        jean.x = 14; // Center exit
        jean.y = 11; // Exit pen to maze area
      }
      
      // Determine target based on mode
      this.setGhostTarget(jean);
      
      // Move towards target (simplified AI)
      if (jean.name === 'Levi' && this.frameCounter % 120 === 0) {
        console.log(`Levi trying to move: target=(${jean.targetX},${jean.targetY})`);
      }
      this.moveGhostTowardsTarget(jean);
      
      // Handle tunnel wrapping
      if (jean.x < 0) jean.x = this.MAZE_WIDTH - 1;
      if (jean.x >= this.MAZE_WIDTH) jean.x = 0;
    }
  }
  
  setGhostTarget(jean) {
    if (this.frightenedMode) {
      // Random movement when frightened
      jean.targetX = Math.floor(Math.random() * this.MAZE_WIDTH);
      jean.targetY = Math.floor(Math.random() * this.MAZE_HEIGHT);
      return;
    }
    
    switch (jean.name) {
      case 'Levi':
        // Direct pursuit
        jean.targetX = this.hackman.x;
        jean.targetY = this.hackman.y;
        break;
      case 'Wrangler':
        // 4 tiles ahead of Hackman
        const [dx, dy] = this.getDirectionVector(this.hackman.direction);
        jean.targetX = this.hackman.x + dx * 4;
        jean.targetY = this.hackman.y + dy * 4;
        break;
      case 'Lee':
        // Opposite vector relative to Levi
        const levi = this.jeans[0];
        const vectorX = this.hackman.x - levi.x;
        const vectorY = this.hackman.y - levi.y;
        jean.targetX = this.hackman.x + vectorX;
        jean.targetY = this.hackman.y + vectorY;
        break;
      case 'Diesel':
        // Random behavior with occasional direct chase
        if (Math.abs(jean.x - this.hackman.x) + Math.abs(jean.y - this.hackman.y) < 8) {
          jean.targetX = this.hackman.x;
          jean.targetY = this.hackman.y;
        } else {
          jean.targetX = jean.targetX || Math.floor(Math.random() * this.MAZE_WIDTH);
          jean.targetY = jean.targetY || Math.floor(Math.random() * this.MAZE_HEIGHT);
        }
        break;
    }
    
    // In scatter mode, go to corners
    if (jean.mode === 'scatter') {
      jean.targetX = jean.name === 'Levi' ? 0 : jean.name === 'Wrangler' ? 27 : jean.name === 'Lee' ? 0 : 27;
      jean.targetY = jean.name === 'Levi' ? 0 : jean.name === 'Wrangler' ? 0 : jean.name === 'Lee' ? 30 : 30;
    }
  }
  
  moveGhostTowardsTarget(jean) {
    const possibleMoves = [];
    
    for (let dir = 0; dir < 4; dir++) {
      if (this.canMove(jean.x, jean.y, dir)) {
        const [dx, dy] = this.getDirectionVector(dir);
        const newX = jean.x + dx;
        const newY = jean.y + dy;
        const distance = Math.abs(newX - jean.targetX) + Math.abs(newY - jean.targetY);
        possibleMoves.push({ direction: dir, distance: distance });
      }
    }
    
    if (possibleMoves.length > 0) {
      // Sort by distance and pick best move
      possibleMoves.sort((a, b) => a.distance - b.distance);
      jean.direction = possibleMoves[0].direction;
      
      const [dx, dy] = this.getDirectionVector(jean.direction);
      jean.x += dx;
      jean.y += dy;
    }
  }
  
  canMove(x, y, direction) {
    const [dx, dy] = this.getDirectionVector(direction);
    const newX = x + dx;
    const newY = y + dy;
    
    // Handle tunnel wrapping
    if (newX < 0 || newX >= this.MAZE_WIDTH) return true;
    if (newY < 0 || newY >= this.MAZE_HEIGHT) return false;
    
    const tile = this.maze[newY][newX];
    return tile === 'path' || tile === 'door';
  }
  
  getDirectionVector(direction) {
    switch (direction) {
      case 0: return [1, 0];  // Right
      case 1: return [0, 1];  // Down
      case 2: return [-1, 0]; // Left
      case 3: return [0, -1]; // Up
      default: return [0, 0];
    }
  }
  
  checkCollisions() {
    // Check Bitcoin collection
    const pos = `${this.hackman.x},${this.hackman.y}`;
    if (this.bitcoins.has(pos)) {
      this.bitcoins.delete(pos);
      this.score += 10;
      this.sounds.chomp();
      this.createParticles(this.hackman.x * this.TILE_SIZE + 10, this.hackman.y * this.TILE_SIZE + 10, 2, '#FFD700');
      this.updateUI();
    }
    
    // Check Power Bitcoin collection
    if (this.powerBitcoins.has(pos)) {
      console.log('Power Bitcoin collected! Activating frightened mode');
      this.powerBitcoins.delete(pos);
      this.score += 50;
      this.frightenedMode = true;
      this.frightenedTimer = 100; // Shorter for testing - about 10 seconds
      this.ghostEatenMultiplier = 200;
      this.sounds.powerUp();
      this.createParticles(this.hackman.x * this.TILE_SIZE + 10, this.hackman.y * this.TILE_SIZE + 10, 20, '#FFD700');
      
      console.log(`Frightened mode set: ${this.frightenedMode}, Timer: ${this.frightenedTimer}`);
      
      // Set all ghosts to frightened
      for (let jean of this.jeans) {
        jean.mode = 'frightened';
        console.log(`Set ${jean.name} to frightened mode (was in pen: ${jean.inPen})`);
      }
      
      this.updateUI();
    }
    
    // Check ghost collisions
    for (let jean of this.jeans) {
      if (jean.inPen) continue;
      
      if (jean.x === this.hackman.x && jean.y === this.hackman.y) {
        console.log(`Collision with ${jean.name}! Frightened mode: ${this.frightenedMode}, Ghost mode: ${jean.mode}`);
        if (this.frightenedMode) {
          // Eat ghost
          console.log(`Eating ghost ${jean.name}!`);
          const points = this.ghostEatenMultiplier;
          this.score += points;
          this.ghostEatenMultiplier *= 2;
          this.sounds.eatGhost();
          this.createParticles(jean.x * this.TILE_SIZE + 10, jean.y * this.TILE_SIZE + 10, 25, jean.color);
          
          // Show score popup
          this.showScorePopup(jean.x, jean.y, points);
          
          // Return ghost to pen
          jean.x = 14;
          jean.y = 14;
          jean.inPen = true;
          jean.releaseTimer = 300; // 5 second delay
          jean.mode = 'chase';
          
          this.updateUI();
        } else {
          // Ghost caught Hackman
          console.log(`Ghost ${jean.name} caught Hackman!`);
          this.playerDeath();
          return;
        }
      }
    }
  }
  
  createParticles(x, y, count, color) {
    // Make bitcoin collection particles subtle
    const isBitcoinCollection = count <= 2 && color === '#FFD700';
    
    for (let i = 0; i < count && this.particles.length < this.maxParticles; i++) {
      this.particles.push({
        x: x + (Math.random() - 0.5) * (isBitcoinCollection ? 4 : 10),
        y: y + (Math.random() - 0.5) * (isBitcoinCollection ? 4 : 10),
        vx: (Math.random() - 0.5) * (isBitcoinCollection ? 2 : 4),
        vy: (Math.random() - 0.5) * (isBitcoinCollection ? 2 : 4) - 1,
        color: color,
        life: isBitcoinCollection ? 20 : 60,
        maxLife: isBitcoinCollection ? 20 : 60,
        size: isBitcoinCollection ? 1 + Math.random() : 2 + Math.random() * 2
      });
    }
  }
  
  updateParticles() {
    for (let i = this.particles.length - 1; i >= 0; i--) {
      let particle = this.particles[i];
      
      particle.x += particle.vx;
      particle.y += particle.vy;
      particle.vy += 0.1; // gravity
      particle.life--;
      
      if (particle.life <= 0) {
        this.particles.splice(i, 1);
      }
    }
  }
  
  showScorePopup(x, y, points) {
    this.scorePopups.push({
      x: x * this.TILE_SIZE + this.TILE_SIZE / 2,
      y: y * this.TILE_SIZE + this.TILE_SIZE / 2,
      points: points,
      life: 120,
      maxLife: 120
    });
  }
  
  renderScorePopups() {
    for (let popup of this.scorePopups) {
      const alpha = popup.life / popup.maxLife;
      this.ctx.save();
      this.ctx.globalAlpha = alpha;
      this.ctx.fillStyle = '#FFFF00';
      this.ctx.font = 'bold 14px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.fillText(popup.points.toString(), popup.x, popup.y);
      this.ctx.restore();
    }
  }
  
  updateScorePopups() {
    for (let i = this.scorePopups.length - 1; i >= 0; i--) {
      let popup = this.scorePopups[i];
      popup.y -= 0.5; // Float upward
      popup.life--;
      
      if (popup.life <= 0) {
        this.scorePopups.splice(i, 1);
      }
    }
  }
  
  playerDeath() {
    this.lives--;
    this.sounds.death();
    this.createParticles(this.hackman.x * this.TILE_SIZE + 10, this.hackman.y * this.TILE_SIZE + 10, 30, '#FF0000');
    
    this.updateUI();
    
    if (this.lives <= 0) {
      this.gameOver();
    } else {
      this.resetLevel();
    }
  }
  
  victory() {
    this.gameState = 'victory';
    this.sounds.victory();
    // Progress to next level would go here
  }
  
  gameOver() {
    this.gameState = 'gameOver';
    if (this.gameOverElement) this.gameOverElement.classList.remove('game-over-hidden');
    if (this.finalScoreElement) this.finalScoreElement.textContent = this.score.toString().padStart(6, '0');
  }
  
  // Professional cleanup
  destroy() {
    if (this.keyDownHandler) {
      document.removeEventListener('keydown', this.keyDownHandler);
    }
    if (this.keyUpHandler) {
      document.removeEventListener('keyup', this.keyUpHandler);
    }
    if (this.audioManager) {
      this.audioManager.destroy();
    }
  }
}