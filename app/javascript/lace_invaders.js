// Lace Invaders — sneaker-themed Space Invaders homage
// Procedural WebAudio, 2-frame pixel sprites, UFO mystery score, in-canvas HUD.

// ============================================================
// Audio — procedural, WebAudio, no external assets
// ============================================================
export class LaceInvadersAudio {
  constructor() {
    this.ctx = null;
    this.master = null;
    this.enabled = true;
    this.volume = 0.35;
    this.marchStep = 0;
    this.ufoNodes = null;
  }

  ensure() {
    if (this.ctx) return;
    try {
      const Ctor = window.AudioContext || window.webkitAudioContext;
      if (!Ctor) { this.enabled = false; return; }
      this.ctx = new Ctor();
      this.master = this.ctx.createGain();
      this.master.gain.value = this.volume;
      this.master.connect(this.ctx.destination);
    } catch (e) {
      console.warn('Audio init failed:', e);
      this.enabled = false;
    }
  }

  resume() {
    if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume();
  }

  // Classic descending 4-note heartbeat. Caller advances one note per invader step.
  march() {
    this.ensure();
    if (!this.enabled || !this.ctx) return;
    const notes = [92.5, 87.3, 82.4, 77.8]; // F#2, F2, E2, D#2
    const f = notes[this.marchStep % 4];
    this.marchStep++;
    this._tone(f, 0.11, 'square', 0.45);
  }

  shoot() {
    this.ensure();
    if (!this.enabled || !this.ctx) return;
    const t = this.ctx.currentTime;
    const o = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    o.type = 'square';
    o.frequency.setValueAtTime(1400, t);
    o.frequency.exponentialRampToValueAtTime(180, t + 0.14);
    g.gain.setValueAtTime(0.25, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.14);
    o.connect(g); g.connect(this.master);
    o.start(t); o.stop(t + 0.16);
  }

  invaderHit() {
    this.ensure();
    if (!this.enabled || !this.ctx) return;
    const t = this.ctx.currentTime;
    // Short noise burst
    const dur = 0.22;
    const n = this._noise(dur);
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(0.3, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    n.connect(g); g.connect(this.master);
    n.start(t);
    // Pitched thump
    const o = this.ctx.createOscillator();
    const og = this.ctx.createGain();
    o.type = 'sawtooth';
    o.frequency.setValueAtTime(220, t);
    o.frequency.exponentialRampToValueAtTime(40, t + 0.2);
    og.gain.setValueAtTime(0.2, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.2);
    o.connect(og); og.connect(this.master);
    o.start(t); o.stop(t + 0.22);
  }

  playerDeath() {
    this.ensure();
    if (!this.enabled || !this.ctx) return;
    const t = this.ctx.currentTime;
    const o = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    o.type = 'sawtooth';
    o.frequency.setValueAtTime(420, t);
    o.frequency.exponentialRampToValueAtTime(50, t + 0.9);
    g.gain.setValueAtTime(0.3, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.9);
    const lfo = this.ctx.createOscillator();
    const lfoGain = this.ctx.createGain();
    lfo.frequency.value = 14;
    lfoGain.gain.value = 60;
    lfo.connect(lfoGain); lfoGain.connect(o.frequency);
    o.connect(g); g.connect(this.master);
    o.start(t); o.stop(t + 1.0);
    lfo.start(t); lfo.stop(t + 1.0);
  }

  ufoStart() {
    this.ensure();
    if (!this.enabled || !this.ctx || this.ufoNodes) return;
    const t = this.ctx.currentTime;
    const o = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    o.type = 'sine';
    o.frequency.value = 720;
    g.gain.value = 0.14;
    const lfo = this.ctx.createOscillator();
    const lfoGain = this.ctx.createGain();
    lfo.frequency.value = 9;
    lfoGain.gain.value = 140;
    lfo.connect(lfoGain); lfoGain.connect(o.frequency);
    o.connect(g); g.connect(this.master);
    o.start(t); lfo.start(t);
    this.ufoNodes = { o, g, lfo };
  }

  ufoStop() {
    if (!this.ufoNodes || !this.ctx) return;
    const { o, g, lfo } = this.ufoNodes;
    const t = this.ctx.currentTime;
    g.gain.cancelScheduledValues(t);
    g.gain.setValueAtTime(g.gain.value, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
    o.stop(t + 0.15);
    lfo.stop(t + 0.15);
    this.ufoNodes = null;
  }

  ufoExplode() {
    this.ensure();
    if (!this.enabled || !this.ctx) return;
    const t = this.ctx.currentTime;
    const n = this._noise(0.55);
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(0.4, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.55);
    n.connect(g); g.connect(this.master);
    n.start(t);
  }

  _tone(freq, dur, type = 'square', amp = 0.25) {
    const t = this.ctx.currentTime;
    const o = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    o.type = type;
    o.frequency.value = freq;
    g.gain.setValueAtTime(amp, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(g); g.connect(this.master);
    o.start(t); o.stop(t + dur + 0.02);
  }

  _noise(dur) {
    const size = Math.max(1, Math.floor(this.ctx.sampleRate * dur));
    const buf = this.ctx.createBuffer(1, size, this.ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < size; i++) {
      const t = i / size;
      data[i] = (Math.random() * 2 - 1) * (1 - t);
    }
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    return src;
  }

  destroy() {
    this.ufoStop();
    if (this.ctx && this.ctx.close) {
      try { this.ctx.close(); } catch (e) {}
    }
  }
}

// ============================================================
// Pixel sprites (1 = on, 0 = off). Two-frame animation per invader.
// ============================================================
// Type 1 — low-top sneaker (10 pts)
const LOW_A = [
  "0000111111110000",
  "0011111111111100",
  "0111111111111110",
  "1111001111001111",
  "1111111111111111",
  "0011111111111100",
  "0110001001000110",
  "1100000000000011",
];
const LOW_B = [
  "0000111111110000",
  "0011111111111100",
  "0111111111111110",
  "1111001111001111",
  "1111111111111111",
  "0011111111111100",
  "1100010010001100",
  "0011000000001100",
];

// Type 2 — athletic sneaker (20 pts)
const ATH_A = [
  "0000011111100000",
  "0001111111111000",
  "0111111111111110",
  "1111111111111111",
  "1100111111110011",
  "1111111111111111",
  "0011100110011100",
  "0110010000100110",
  "0100000000000010",
];
const ATH_B = [
  "0000011111100000",
  "0001111111111000",
  "0111111111111110",
  "1111111111111111",
  "1100111111110011",
  "1111111111111111",
  "0011001001001100",
  "0010010110010100",
  "1100000000000011",
];

// Type 3 — high-top sneaker / boot (30 pts)
const HT_A = [
  "0000001111000000",
  "0000011111100000",
  "0011111111111100",
  "0111111111111110",
  "1111001001001111",
  "1111111111111111",
  "0111111111111110",
  "0110000000000110",
  "1100011001100011",
  "0011000000000110",
];
const HT_B = [
  "0000001111000000",
  "0000011111100000",
  "0011111111111100",
  "0111111111111110",
  "1111001001001111",
  "1111111111111111",
  "0111111111111110",
  "1100000000000011",
  "0011000110001100",
  "1100011000011011",
];

// Player — shoe cannon
const PLAYER = [
  "0000000110000000",
  "0000001111000000",
  "0000011111100000",
  "0001111111111000",
  "0111111111111110",
  "1111111111111111",
  "1111111111111111",
  "1111111111111111",
];

// UFO — mystery saucer
const UFO = [
  "0000011111100000000",
  "0001111111111110000",
  "0111111111111111110",
  "1111001100110011111",
  "1111111111111111111",
  "0011111111111111100",
  "0000111101111010000",
];

// Invader explosion — single splat frame
const BOOM = [
  "0010010000100100",
  "1001000100010010",
  "0100100010001001",
  "0010000101000100",
  "0100101010100010",
  "0010100010001001",
  "1001001000100100",
  "0100010010010010",
];

// Player explosion — jagged frame
const PLAYER_BOOM = [
  "0100010010000100",
  "0010100101001001",
  "1001010010100100",
  "0110001001010010",
  "0011110110111100",
  "1111111111111111",
  "1011011101110111",
  "0101100110011010",
];

function parsePixels(rows) {
  return rows.map(r => Array.from(r).map(c => c === '1'));
}

const SPRITES = {
  lowA: parsePixels(LOW_A),
  lowB: parsePixels(LOW_B),
  athA: parsePixels(ATH_A),
  athB: parsePixels(ATH_B),
  htA: parsePixels(HT_A),
  htB: parsePixels(HT_B),
  player: parsePixels(PLAYER),
  ufo: parsePixels(UFO),
  boom: parsePixels(BOOM),
  playerBoom: parsePixels(PLAYER_BOOM),
};

// ============================================================
// Game
// ============================================================
export class LaceInvadersGame {
  constructor(options) {
    this.canvas = options.canvas;
    this.ctx = this.canvas.getContext('2d');
    this.ctx.imageSmoothingEnabled = false;

    this.scoreElement = options.scoreElement;
    this.livesElement = options.livesElement;
    this.levelElement = options.levelElement;
    this.startButton = options.startButton;
    this.gameOverElement = options.gameOverElement;
    this.finalScoreElement = options.finalScoreElement;
    this.restartButton = options.restartButton;

    // Layout
    this.SCALE = 2;
    this.GROUND_Y = this.canvas.height - 40;
    this.HUD_H = 50;

    // Game state
    this.gameState = 'menu';
    this.score = 0;
    this.hiScore = this._loadHiScore();
    this.lives = 3;
    this.level = 1;
    this.frameCounter = 0;
    this.shotCount = 0;
    this.playerDeathTimer = 0;
    this.levelCompleteTimer = 0;

    // Input
    this.keys = {};
    this.keyPressed = {};

    // Player
    this.player = {
      x: this.canvas.width / 2 - 16,
      y: this.GROUND_Y - 20,
      width: 32,
      height: 16,
      speed: 4,
      shootCooldown: 0,
      alive: true,
    };

    // Game objects
    this.invaders = [];
    this.playerLaces = [];
    this.invaderLaces = [];
    this.barriers = [];
    this.particles = [];
    this.explosions = [];
    this.ufo = null;
    this.ufoCooldown = 1500; // ~25s at 60fps

    // March state (two-frame toggle + tempo)
    this.invaderDirection = 1;
    this.invaderDropDistance = 18;
    this.lastInvaderMoveTime = 0;
    this.invaderMoveInterval = 520;
    this.marchFrame = 0;

    // Screen shake — bumped on player hit, decays each frame.
    this.shake = 0;

    // Audio
    this.audio = new LaceInvadersAudio();

    // Seeded starfield — twinkles on the menu
    this.stars = [];
    for (let i = 0; i < 70; i++) {
      this.stars.push({
        x: Math.floor(((i * 9301 + 49297) % 233280) / 233280 * this.canvas.width),
        y: this.HUD_H + Math.floor(((i * 5923 + 91277) % 233280) / 233280 * (this.canvas.height - this.HUD_H - 40)),
        phase: Math.random() * Math.PI * 2,
        speed: 0.02 + Math.random() * 0.05,
        big: i % 11 === 0,
      });
    }

    // Attract-mode demo state for the menu
    this.attract = this._newAttract();

    this.initializeLevel();
    this.setupEventListeners();
    this.gameLoop();

    console.log('🎮 Lace Invaders ready');
  }

  _loadHiScore() {
    try {
      const v = parseInt(window.localStorage.getItem('laceInvadersHiScore') || '0', 10);
      return Number.isFinite(v) ? v : 0;
    } catch (e) { return 0; }
  }

  _saveHiScore() {
    try { window.localStorage.setItem('laceInvadersHiScore', String(this.hiScore)); } catch (e) {}
  }

  initializeLevel() {
    this.invaders = [];
    const startX = 60;
    const startY = this.HUD_H + 60 + Math.min((this.level - 1) * 20, 120);
    const spacingX = 56;
    const spacingY = 46;

    const widthFor = (type) => type === 3 ? 32 : type === 2 ? 32 : 32;
    const heightFor = (type) => type === 3 ? 20 : type === 2 ? 18 : 16;

    for (let row = 0; row < 5; row++) {
      for (let col = 0; col < 11; col++) {
        let type = 1;
        if (row === 0) type = 3;
        else if (row <= 2) type = 2;

        this.invaders.push({
          x: startX + col * spacingX,
          y: startY + row * spacingY,
          width: widthFor(type),
          height: heightFor(type),
          type,
          points: type === 3 ? 30 : type === 2 ? 20 : 10,
          alive: true,
          dying: 0,
        });
      }
    }

    this.barriers = [];
    const shieldY = this.GROUND_Y - 100;
    for (let i = 0; i < 4; i++) {
      this.barriers.push({
        x: 120 + i * 165,
        y: shieldY,
        width: 66,
        height: 48,
        damage: new Set(),
      });
    }

    this.playerLaces = [];
    this.invaderLaces = [];
    this.particles = [];
    this.explosions = [];
    this.ufo = null;
    this.ufoCooldown = 1200 + Math.random() * 600;
    this.invaderMoveInterval = Math.max(140, 520 - (this.level - 1) * 40);
    this.marchFrame = 0;
    this.audio.marchStep = 0;
  }

  setupEventListeners() {
    this.keyDownHandler = (e) => {
      if (['ArrowLeft','ArrowRight','KeyA','KeyD','Space','KeyP','KeyM'].includes(e.code)) {
        e.preventDefault();
      }
      this.keys[e.code] = true;
      if (!this.keyPressed[e.code]) {
        this.keyPressed[e.code] = true;
        this.audio.resume();
        if (e.code === 'Space') {
          if (this.gameState === 'menu') this.startGame();
          else if (this.gameState === 'playing') this.shootPlayerLace();
          else if (this.gameState === 'gameOver') this.restartGame();
        } else if (e.code === 'KeyP') {
          this.togglePause();
        } else if (e.code === 'KeyM') {
          this.audio.enabled = !this.audio.enabled;
          if (!this.audio.enabled) this.audio.ufoStop();
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
    this.shotCount = 0;
    this.initializeLevel();
    this.updateUI();
  }

  restartGame() {
    this.startGame();
    if (this.gameOverElement) this.gameOverElement.classList.add('game-over-hidden');
  }

  togglePause() {
    if (this.gameState === 'playing') {
      this.gameState = 'paused';
      this.audio.ufoStop();
    } else if (this.gameState === 'paused') {
      this.gameState = 'playing';
    }
  }

  shootPlayerLace() {
    if (this.playerLaces.length > 0) return; // classic one-bullet-at-a-time
    if (this.player.shootCooldown > 0 || !this.player.alive) return;
    this.playerLaces.push({
      x: this.player.x + this.player.width / 2 - 2,
      y: this.player.y - 8,
      width: 4,
      height: 12,
      speed: 10,
    });
    this.player.shootCooldown = 8;
    this.shotCount++;
    this.audio.shoot();
  }

  update() {
    this.frameCounter++;

    if (this.gameState === 'menu') {
      this._updateAttract();
      return;
    }

    if (this.gameState !== 'playing') {
      // Keep explosion particles animating even on pause/over so they finish if mid-flight
      return;
    }

    // Player motion
    if (this.player.alive) {
      if (this.keys['ArrowLeft'] || this.keys['KeyA']) {
        this.player.x = Math.max(8, this.player.x - this.player.speed);
      }
      if (this.keys['ArrowRight'] || this.keys['KeyD']) {
        this.player.x = Math.min(this.canvas.width - this.player.width - 8, this.player.x + this.player.speed);
      }
    }
    if (this.player.shootCooldown > 0) this.player.shootCooldown--;

    // Player death respawn delay
    if (!this.player.alive) {
      this.playerDeathTimer--;
      if (this.playerDeathTimer <= 0) {
        if (this.lives > 0) {
          this.player.alive = true;
          this.player.x = this.canvas.width / 2 - 16;
          this.invaderLaces = [];
        } else {
          this._endGame();
        }
      }
      this.updateInvaders(); // invaders keep marching during the brief freeze
      this.updateUFO();
      this.updateExplosions();
      this.updateParticles();
      return;
    }

    this.updateInvaders();
    this.updateInvaderShooting();
    this.updateUFO();

    // Player laces
    for (let i = this.playerLaces.length - 1; i >= 0; i--) {
      const lace = this.playerLaces[i];
      lace.y -= lace.speed;
      if (lace.y < this.HUD_H - 20) this.playerLaces.splice(i, 1);
    }

    // Invader laces
    for (let i = this.invaderLaces.length - 1; i >= 0; i--) {
      const lace = this.invaderLaces[i];
      lace.y += lace.speed;
      if (lace.y > this.GROUND_Y + 10) this.invaderLaces.splice(i, 1);
    }

    this.updateExplosions();
    this.updateParticles();
    this.checkCollisions();
    this.checkLevelCompletion();
  }

  updateInvaders() {
    const now = Date.now();
    const alive = this.invaders.filter(i => i.alive);
    if (alive.length === 0) return;

    // Linear speedup as invaders die — the core "march" acceleration.
    const totalPositions = 55;
    const ratio = alive.length / totalPositions;
    const base = 520 - (this.level - 1) * 40;
    const fast = 60;
    const interval = Math.max(fast, Math.round(fast + (base - fast) * ratio));
    this.invaderMoveInterval = interval;

    if (now - this.lastInvaderMoveTime < this.invaderMoveInterval) return;

    let shouldDrop = false;
    for (const inv of alive) {
      if (this.invaderDirection === 1 && inv.x + inv.width >= this.canvas.width - 10) { shouldDrop = true; break; }
      if (this.invaderDirection === -1 && inv.x <= 10) { shouldDrop = true; break; }
    }

    const step = 10;
    for (const inv of alive) {
      if (shouldDrop) inv.y += this.invaderDropDistance;
      else inv.x += this.invaderDirection * step;
    }
    if (shouldDrop) this.invaderDirection *= -1;

    this.marchFrame = 1 - this.marchFrame; // toggle 2-frame animation
    this.audio.march();                    // one note per step
    this.lastInvaderMoveTime = now;
  }

  updateInvaderShooting() {
    const alive = this.invaders.filter(i => i.alive);
    if (alive.length === 0) return;
    // Difficulty ramps with level — both rate of fire and projectile speed scale.
    const rate = Math.min(0.035, 0.009 + (this.level - 1) * 0.004);
    if (Math.random() > rate) return;

    // Prefer the front-row invader of a random column
    const columns = {};
    for (const inv of alive) {
      const key = Math.round(inv.x);
      if (!columns[key] || inv.y > columns[key].y) columns[key] = inv;
    }
    const shooters = Object.values(columns);
    const shooter = shooters[Math.floor(Math.random() * shooters.length)];
    this.invaderLaces.push({
      x: shooter.x + shooter.width / 2 - 1.5,
      y: shooter.y + shooter.height,
      width: 3,
      height: 10,
      speed: Math.min(8, 4.5 + (this.level - 1) * 0.7),
    });
  }

  updateUFO() {
    if (this.ufo) {
      this.ufo.x += this.ufo.speed * this.ufo.dir;
      if ((this.ufo.dir === 1 && this.ufo.x > this.canvas.width + 30) ||
          (this.ufo.dir === -1 && this.ufo.x + this.ufo.width < -30)) {
        this.ufo = null;
        this.audio.ufoStop();
      }
      return;
    }
    this.ufoCooldown--;
    if (this.ufoCooldown <= 0 && this.invaders.filter(i => i.alive).length > 6) {
      const dir = Math.random() < 0.5 ? 1 : -1;
      this.ufo = {
        x: dir === 1 ? -40 : this.canvas.width + 10,
        y: this.HUD_H + 8,
        width: 38,
        height: 14,
        dir,
        speed: 1.8,
        alive: true,
      };
      this.audio.ufoStart();
      this.ufoCooldown = 1400 + Math.random() * 800;
    }
  }

  updateExplosions() {
    for (let i = this.explosions.length - 1; i >= 0; i--) {
      const e = this.explosions[i];
      e.ttl--;
      if (e.ttl <= 0) this.explosions.splice(i, 1);
    }
  }

  updateParticles() {
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.x += p.vx; p.y += p.vy;
      p.vy += 0.15; // gentle gravity
      p.life--;
      if (p.life <= 0) this.particles.splice(i, 1);
    }
  }

  checkCollisions() {
    // Player laces vs invaders
    for (let i = this.playerLaces.length - 1; i >= 0; i--) {
      const lace = this.playerLaces[i];
      let hit = false;
      for (const inv of this.invaders) {
        if (!inv.alive) continue;
        if (this._collide(lace, inv)) {
          inv.alive = false;
          this.score += inv.points;
          this._addExplosion(inv.x, inv.y, 'invader');
          this.audio.invaderHit();
          this.playerLaces.splice(i, 1);
          hit = true;
          break;
        }
      }
      if (hit) continue;

      // vs UFO
      if (this.ufo && this._collide(lace, this.ufo)) {
        const pts = this._mysteryScore();
        this.score += pts;
        this._addExplosion(this.ufo.x, this.ufo.y, 'ufo', pts);
        this.audio.ufoStop();
        this.audio.ufoExplode();
        this.ufo = null;
        this.playerLaces.splice(i, 1);
        continue;
      }

      // vs shields
      for (const shield of this.barriers) {
        if (this._collide(lace, shield)) {
          this._damageShield(shield, lace.x - shield.x, lace.y - shield.y, 5);
          this.playerLaces.splice(i, 1);
          break;
        }
      }
    }

    // Invader laces vs player
    for (let i = this.invaderLaces.length - 1; i >= 0; i--) {
      const lace = this.invaderLaces[i];
      if (this.player.alive && this._collide(lace, this.player)) {
        this.invaderLaces.splice(i, 1);
        this._playerHit();
        continue;
      }
      for (const shield of this.barriers) {
        if (this._collide(lace, shield)) {
          this._damageShield(shield, lace.x - shield.x, lace.y - shield.y, 4);
          this.invaderLaces.splice(i, 1);
          break;
        }
      }
    }

    // Invader reaches bottom or overlaps player -> game over
    for (const inv of this.invaders) {
      if (!inv.alive) continue;
      if (inv.y + inv.height >= this.GROUND_Y - 4) {
        this._endGame();
        return;
      }
      if (this.player.alive && this._collide(inv, this.player)) {
        this._playerHit();
        return;
      }
    }

    // Invaders gnaw through shields as they pass
    for (const inv of this.invaders) {
      if (!inv.alive) continue;
      for (const shield of this.barriers) {
        if (this._collide(inv, shield)) {
          this._damageShield(shield, inv.x - shield.x, inv.y - shield.y, 8, inv.width, inv.height);
        }
      }
    }

    if (this.score > this.hiScore) {
      this.hiScore = this.score;
      this._saveHiScore();
    }
    this.updateUI();
  }

  _mysteryScore() {
    // Original 1978 machine had a complex 15-shot cycle; this approximation
    // keeps the iconic "every 15th shot = 300" moment while randomising others.
    if (this.shotCount > 0 && this.shotCount % 15 === 0) return 300;
    const table = [50, 100, 150];
    return table[Math.floor(Math.random() * table.length)];
  }

  _playerHit() {
    if (!this.player.alive) return;
    this.player.alive = false;
    this.playerDeathTimer = 90;
    this.lives--;
    this.updateUI();
    this.audio.playerDeath();
    this._addExplosion(this.player.x, this.player.y, 'player');
    this.shake = 16;
    if (this.lives <= 0) {
      // death sequence finishes in update(); game ends when timer hits 0
    }
  }

  _endGame() {
    if (this.gameState === 'gameOver') return;
    this.gameState = 'gameOver';
    this.audio.ufoStop();
    if (this.score > this.hiScore) { this.hiScore = this.score; this._saveHiScore(); }
    if (this.gameOverElement) this.gameOverElement.classList.remove('game-over-hidden');
    if (this.finalScoreElement) this.finalScoreElement.textContent = this.score.toString().padStart(6, '0');
  }

  _addExplosion(x, y, kind, bonus = 0) {
    const ttl = kind === 'ufo' ? 40 : kind === 'player' ? 80 : 14;
    this.explosions.push({ x, y, kind, ttl, bonus });
    // Spark particles
    const n = kind === 'invader' ? 8 : kind === 'ufo' ? 18 : 22;
    const palette = kind === 'player'
      ? ['#FF3030', '#FFC700', '#FFFFFF']
      : kind === 'ufo'
        ? ['#FF00FF', '#FFC700', '#00E0FF']
        : ['#FFC700', '#FF8800', '#FFFFFF'];
    for (let i = 0; i < n; i++) {
      this.particles.push({
        x: x + (kind === 'player' ? 16 : 16) + (Math.random() - 0.5) * 8,
        y: y + 8 + (Math.random() - 0.5) * 8,
        vx: (Math.random() - 0.5) * (kind === 'player' ? 6 : 4),
        vy: (Math.random() - 0.8) * (kind === 'player' ? 5 : 3),
        life: 24 + Math.floor(Math.random() * 16),
        maxLife: 40,
        color: palette[Math.floor(Math.random() * palette.length)],
      });
    }
  }

  _damageShield(shield, hitX, hitY, radius, w = 0, h = 0) {
    const rx = w > 0 ? w + 2 : radius;
    const ry = h > 0 ? h + 2 : radius;
    const x0 = Math.max(0, Math.floor(hitX) - Math.floor(rx / 2));
    const y0 = Math.max(0, Math.floor(hitY) - Math.floor(ry / 2));
    const x1 = Math.min(shield.width, Math.floor(hitX) + Math.ceil(rx / 2));
    const y1 = Math.min(shield.height, Math.floor(hitY) + Math.ceil(ry / 2));
    for (let px = x0; px < x1; px++) {
      for (let py = y0; py < y1; py++) {
        const dx = px - hitX, dy = py - hitY;
        const r = w > 0 ? Math.max(rx, ry) : radius;
        if (dx * dx + dy * dy <= r * r + 4) shield.damage.add(`${px}-${py}`);
      }
    }
  }

  checkLevelCompletion() {
    const alive = this.invaders.filter(i => i.alive).length;
    if (alive === 0 && this.explosions.length === 0 && this.gameState === 'playing') {
      this.gameState = 'levelComplete';
      this.levelCompleteTimer = 120;
      this.audio.ufoStop();
      setTimeout(() => this._startNextLevel(), 1800);
    }
  }

  _startNextLevel() {
    this.level++;
    this.initializeLevel();
    this.gameState = 'playing';
    this.updateUI();
  }

  _collide(a, b) {
    return a.x < b.x + b.width &&
           a.x + a.width > b.x &&
           a.y < b.y + b.height &&
           a.y + a.height > b.y;
  }

  updateUI() {
    if (this.scoreElement) this.scoreElement.textContent = this.score.toString().padStart(6, '0');
    if (this.livesElement) this.livesElement.textContent = String(this.lives);
    if (this.levelElement) this.levelElement.textContent = String(this.level);
  }

  // ============ Rendering ============
  _drawPixels(rows, x, y, scale, color) {
    this.ctx.fillStyle = color;
    for (let ry = 0; ry < rows.length; ry++) {
      const row = rows[ry];
      for (let rx = 0; rx < row.length; rx++) {
        if (row[rx]) this.ctx.fillRect(x + rx * scale, y + ry * scale, scale, scale);
      }
    }
  }

  _invaderSprite(type, frameAlt) {
    if (type === 1) return frameAlt ? SPRITES.lowB : SPRITES.lowA;
    if (type === 2) return frameAlt ? SPRITES.athB : SPRITES.athA;
    return frameAlt ? SPRITES.htB : SPRITES.htA;
  }

  _invaderColor(type) {
    if (type === 1) return '#FF5555';   // low-top red
    if (type === 2) return '#5AD0FF';   // athletic cyan
    return '#B388FF';                   // high-top violet
  }

  _newAttract() {
    const cols = 7;
    const rows = 3;
    const spacingX = 44;
    const spacingY = 36;
    const gridW = (cols - 1) * spacingX + 32;
    const box = { x: 80, y: 220, w: 740, h: 260 };

    const invaders = [];
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        let type = 1;
        if (r === 0) type = 3;
        else if (r === 1) type = 2;
        invaders.push({ col: c, row: r, type, alive: true, respawnIn: 0 });
      }
    }

    return {
      box,
      invaders,
      cols, rows, spacingX, spacingY, gridW,
      baseX: box.x + (box.w - gridW) / 2,
      baseY: box.y + 20,
      xOffset: 0,
      yOffset: 0,
      dir: 1,
      marchTimer: 0,
      marchInterval: 14,
      marchFrame: 0,
      shooterX: box.x + box.w / 2 - 16,
      shooterDir: 1,
      shooterTimer: 60,
      shooterCooldown: 30,
      demoLaces: [],
      invLaces: [],
      explosions: [],
      ufo: null,
      ufoTimer: 600,
    };
  }

  _updateAttract() {
    const a = this.attract;
    if (!a) return;

    // March step — two-frame toggle, reverse at box edges
    a.marchTimer++;
    if (a.marchTimer >= a.marchInterval) {
      a.marchTimer = 0;
      a.marchFrame = 1 - a.marchFrame;

      let minCol = a.cols, maxCol = -1;
      for (const inv of a.invaders) {
        if (!inv.alive) continue;
        if (inv.col < minCol) minCol = inv.col;
        if (inv.col > maxCol) maxCol = inv.col;
      }
      if (maxCol === -1) { minCol = 0; maxCol = a.cols - 1; }
      const stepDx = 6 * a.dir;
      const leftEdge = a.baseX + a.xOffset + minCol * a.spacingX + stepDx;
      const rightEdge = a.baseX + a.xOffset + maxCol * a.spacingX + 32 + stepDx;
      if (rightEdge > a.box.x + a.box.w - 6 || leftEdge < a.box.x + 6) {
        a.dir = -a.dir;
        a.yOffset += 4;
        if (a.yOffset > 60) a.yOffset = 0;
      } else {
        a.xOffset += stepDx;
      }
    }

    // Shooter oscillation
    a.shooterTimer++;
    a.shooterX += a.shooterDir * 1.6;
    const shooterMinX = a.box.x + 10;
    const shooterMaxX = a.box.x + a.box.w - 42;
    if (a.shooterX < shooterMinX) { a.shooterX = shooterMinX; a.shooterDir = 1; }
    if (a.shooterX > shooterMaxX) { a.shooterX = shooterMaxX; a.shooterDir = -1; }
    if (a.shooterTimer > 100 + Math.random() * 80) {
      a.shooterTimer = 0;
      a.shooterDir = Math.random() < 0.5 ? -1 : 1;
    }

    // Shooter fires
    if (a.shooterCooldown > 0) a.shooterCooldown--;
    if (a.shooterCooldown === 0 && Math.random() < 0.05) {
      a.demoLaces.push({ x: a.shooterX + 15, y: a.box.y + a.box.h - 32 });
      a.shooterCooldown = 40 + Math.floor(Math.random() * 40);
    }

    // Advance player laces upward
    for (const l of a.demoLaces) l.y -= 7;

    // Lace vs invader collisions
    for (let i = a.demoLaces.length - 1; i >= 0; i--) {
      const l = a.demoLaces[i];
      if (l.y < a.box.y - 10) { a.demoLaces.splice(i, 1); continue; }
      let hit = false;
      for (const inv of a.invaders) {
        if (!inv.alive) continue;
        const ix = a.baseX + a.xOffset + inv.col * a.spacingX;
        const iy = a.baseY + a.yOffset + inv.row * a.spacingY;
        const iw = 32;
        const ih = inv.type === 3 ? 20 : inv.type === 2 ? 18 : 16;
        if (l.x >= ix && l.x <= ix + iw && l.y >= iy && l.y <= iy + ih) {
          inv.alive = false;
          inv.respawnIn = 90 + Math.floor(Math.random() * 80);
          a.explosions.push({ x: ix, y: iy, ttl: 14 });
          hit = true;
          break;
        }
      }
      if (hit) a.demoLaces.splice(i, 1);
    }

    // Respawn
    for (const inv of a.invaders) {
      if (inv.alive) continue;
      inv.respawnIn--;
      if (inv.respawnIn <= 0) inv.alive = true;
    }

    // Cosmetic invader down-laces
    if (Math.random() < 0.03) {
      const alive = a.invaders.filter(i => i.alive);
      if (alive.length) {
        const inv = alive[Math.floor(Math.random() * alive.length)];
        const ix = a.baseX + a.xOffset + inv.col * a.spacingX + 16;
        const iy = a.baseY + a.yOffset + inv.row * a.spacingY + 16;
        a.invLaces.push({ x: ix, y: iy });
      }
    }
    for (let i = a.invLaces.length - 1; i >= 0; i--) {
      a.invLaces[i].y += 3;
      if (a.invLaces[i].y > a.box.y + a.box.h - 12) a.invLaces.splice(i, 1);
    }

    // Explosions fade
    for (let i = a.explosions.length - 1; i >= 0; i--) {
      a.explosions[i].ttl--;
      if (a.explosions[i].ttl <= 0) a.explosions.splice(i, 1);
    }

    // UFO crossings
    a.ufoTimer--;
    if (!a.ufo && a.ufoTimer <= 0) {
      const leftToRight = Math.random() < 0.5;
      a.ufo = {
        x: leftToRight ? a.box.x - 38 : a.box.x + a.box.w + 8,
        y: a.box.y + 4,
        vx: leftToRight ? 2 : -2,
      };
    }
    if (a.ufo) {
      a.ufo.x += a.ufo.vx;
      if (a.ufo.x < a.box.x - 50 || a.ufo.x > a.box.x + a.box.w + 50) {
        a.ufo = null;
        a.ufoTimer = 400 + Math.floor(Math.random() * 400);
      }
    }
  }

  _renderAttract() {
    const a = this.attract;
    if (!a) return;

    // Invaders
    for (const inv of a.invaders) {
      if (!inv.alive) continue;
      const ix = a.baseX + a.xOffset + inv.col * a.spacingX;
      const iy = a.baseY + a.yOffset + inv.row * a.spacingY;
      const sprite = this._invaderSprite(inv.type, a.marchFrame);
      this._drawPixels(sprite, ix, iy, 2, this._invaderColor(inv.type));
    }

    // UFO
    if (a.ufo) {
      this._drawPixels(SPRITES.ufo, a.ufo.x, a.ufo.y, 2, '#FF2E6F');
    }

    // Shooter
    const shooterY = a.box.y + a.box.h - 30;
    this._drawPixels(SPRITES.player, a.shooterX, shooterY, 2, '#5AFF7A');

    // Player laces (white)
    this.ctx.fillStyle = '#FFFFFF';
    for (const l of a.demoLaces) this.ctx.fillRect(l.x, l.y, 2, 8);

    // Invader laces (red zig-zag)
    this.ctx.fillStyle = '#FF5555';
    for (const l of a.invLaces) {
      for (let s = 0; s < 3; s++) {
        const offset = (s % 2 === 0) ? 0 : 2;
        this.ctx.fillRect(l.x + offset - 1, l.y + s * 4, 3, 4);
      }
    }

    // Explosions
    for (const e of a.explosions) {
      this._drawPixels(SPRITES.boom, e.x, e.y, 2, '#FFC700');
    }

    // Faint ground line inside the box
    this.ctx.fillStyle = 'rgba(90, 255, 122, 0.35)';
    this.ctx.fillRect(a.box.x + 10, a.box.y + a.box.h - 10, a.box.w - 20, 1);
  }

  render() {
    // Background
    this.ctx.fillStyle = '#000000';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    this._renderStars();

    // Apply screen shake to playfield only (HUD stays steady)
    let shx = 0, shy = 0;
    if (this.shake > 0.2) {
      shx = (Math.random() - 0.5) * this.shake;
      shy = (Math.random() - 0.5) * this.shake;
      this.shake *= 0.84;
    } else {
      this.shake = 0;
    }

    if (this.gameState === 'menu') { this._renderHUD(); this._renderMenu(); return; }
    if (shx || shy) { this.ctx.save(); this.ctx.translate(shx, shy); }
    this._renderGame();
    if (shx || shy) this.ctx.restore();
    if (this.gameState === 'paused') this._renderPause();
    else if (this.gameState === 'gameOver') this._renderGameOver();
    else if (this.gameState === 'levelComplete') this._renderLevelComplete();
  }

  _renderStars() {
    if (!this.stars) return;
    for (const s of this.stars) {
      s.phase += s.speed;
      const alpha = 0.25 + 0.75 * (Math.sin(s.phase) * 0.5 + 0.5);
      this.ctx.save();
      this.ctx.globalAlpha = alpha;
      this.ctx.fillStyle = s.big ? '#FFFFFF' : '#8899CC';
      const size = s.big ? 2 : 1;
      this.ctx.fillRect(s.x, s.y, size, size);
      this.ctx.restore();
    }
  }

  _renderHUD() {
    this.ctx.save();
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = 'bold 14px "Courier New", monospace';
    this.ctx.textBaseline = 'top';
    this.ctx.textAlign = 'left';
    this.ctx.fillText('SCORE<1>', 40, 12);
    this.ctx.fillText('HI-SCORE', this.canvas.width / 2 - 48, 12);
    this.ctx.fillText(`LEVEL ${this.level}`, this.canvas.width - 140, 12);

    this.ctx.font = 'bold 20px "Courier New", monospace';
    this.ctx.fillStyle = '#FFC700';
    this.ctx.fillText(this.score.toString().padStart(6, '0'), 40, 28);
    this.ctx.fillStyle = '#FF5555';
    this.ctx.fillText(this.hiScore.toString().padStart(6, '0'), this.canvas.width / 2 - 48, 28);

    // Lives icons
    for (let i = 0; i < this.lives; i++) {
      this._drawPixels(SPRITES.player, this.canvas.width - 140 + i * 36, 28, 2, '#5AFF7A');
    }
    this.ctx.restore();
  }

  _renderGame() {
    this._renderHUD();

    // Ground line (classic green floor)
    this.ctx.fillStyle = '#5AFF7A';
    this.ctx.fillRect(0, this.GROUND_Y, this.canvas.width, 2);

    // Shields
    for (const shield of this.barriers) this._renderShield(shield);

    // Invaders
    for (const inv of this.invaders) {
      if (!inv.alive) continue;
      const sprite = this._invaderSprite(inv.type, this.marchFrame);
      this._drawPixels(sprite, inv.x, inv.y, 2, this._invaderColor(inv.type));
    }

    // UFO
    if (this.ufo) {
      this._drawPixels(SPRITES.ufo, this.ufo.x, this.ufo.y, 2, '#FF2E6F');
    }

    // Player
    if (this.player.alive) {
      this._drawPixels(SPRITES.player, this.player.x, this.player.y, 2, '#5AFF7A');
    }

    // Projectiles — player bullets get a fading speed-trail
    for (const l of this.playerLaces) {
      // Trail (oldest at bottom)
      for (let t = 1; t <= 4; t++) {
        const alpha = 0.6 - t * 0.13;
        if (alpha <= 0) continue;
        this.ctx.fillStyle = `rgba(160, 230, 255, ${alpha})`;
        this.ctx.fillRect(l.x, l.y + t * 4, l.width, 3);
      }
      // Hot core
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.fillRect(l.x, l.y, l.width, l.height);
      this.ctx.fillStyle = '#88E5FF';
      this.ctx.fillRect(l.x - 1, l.y + 1, l.width + 2, l.height - 2);
    }
    this.ctx.fillStyle = '#FF5555';
    for (const l of this.invaderLaces) {
      // Zig-zag shape: alternate x offset each 4px to look like a lace
      const segs = Math.ceil(l.height / 4);
      for (let s = 0; s < segs; s++) {
        const offset = (s % 2 === 0) ? 0 : 2;
        this.ctx.fillRect(l.x + offset - 1, l.y + s * 4, 3, 4);
      }
    }

    // Explosions
    for (const e of this.explosions) {
      if (e.kind === 'invader') {
        this._drawPixels(SPRITES.boom, e.x, e.y, 2, '#FFC700');
      } else if (e.kind === 'ufo') {
        this._drawPixels(SPRITES.boom, e.x, e.y, 2, '#FF2E6F');
        // Bonus score flash above UFO
        this.ctx.save();
        this.ctx.fillStyle = '#FFFFFF';
        this.ctx.font = 'bold 16px "Courier New", monospace';
        this.ctx.textAlign = 'center';
        this.ctx.fillText(String(e.bonus), e.x + 20, e.y - 6);
        this.ctx.restore();
      } else if (e.kind === 'player') {
        this._drawPixels(SPRITES.playerBoom, e.x, e.y, 2, (e.ttl % 8 < 4) ? '#FF3030' : '#FFC700');
      }
    }

    // Particles
    for (const p of this.particles) {
      this.ctx.save();
      this.ctx.globalAlpha = Math.max(0, p.life / p.maxLife);
      this.ctx.fillStyle = p.color;
      this.ctx.fillRect(p.x, p.y, 2, 2);
      this.ctx.restore();
    }
  }

  _renderShield(shield) {
    const pxSize = 1;
    // Base dome mask: simple parabolic arch with a ground-facing notch
    for (let sx = 0; sx < shield.width; sx++) {
      for (let sy = 0; sy < shield.height; sy++) {
        if (shield.damage.has(`${sx}-${sy}`)) continue;
        const cx = shield.width / 2;
        const arch = Math.pow((sx - cx) / cx, 2) * shield.height * 0.55;
        const inDome = sy >= arch;
        const notch = sy > shield.height * 0.66 && sx > shield.width * 0.37 && sx < shield.width * 0.63;
        if (inDome && !notch) {
          this.ctx.fillStyle = '#5AFF7A';
          this.ctx.fillRect(shield.x + sx, shield.y + sy, pxSize, pxSize);
        }
      }
    }
  }

  _renderMenu() {
    const cx = this.canvas.width / 2;

    // Attract demo behind everything
    this._renderAttract();

    // Color-cycling title with glow
    const hue = (this.frameCounter * 1.2) % 360;
    this.ctx.save();
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.shadowColor = `hsl(${hue}, 100%, 60%)`;
    this.ctx.shadowBlur = 26;
    this.ctx.fillStyle = `hsl(${hue}, 100%, 65%)`;
    this.ctx.font = 'bold 60px "Courier New", monospace';
    this.ctx.fillText('LACE INVADERS', cx, 140);
    this.ctx.restore();

    // Blinking PRESS SPACE prompt
    if (Math.floor(this.frameCounter / 22) % 2 === 0) {
      this.ctx.save();
      this.ctx.textAlign = 'center';
      this.ctx.textBaseline = 'middle';
      this.ctx.shadowColor = '#FFC700';
      this.ctx.shadowBlur = 10;
      this.ctx.fillStyle = '#FFC700';
      this.ctx.font = 'bold 24px "Courier New", monospace';
      this.ctx.fillText('PRESS SPACE TO DEFEND EARTH', cx, 190);
      this.ctx.restore();
    }

    // Controls hint (just above scoring row)
    this.ctx.save();
    this.ctx.textAlign = 'center';
    this.ctx.fillStyle = '#AACCFF';
    this.ctx.font = '14px "Courier New", monospace';
    this.ctx.fillText('← →  MOVE    SPACE  FIRE    P  PAUSE    M  MUTE', cx, 538);
    this.ctx.restore();

    // Scoring row at the bottom with animated two-frame sprites
    const rowY = 578;
    const frameAlt = Math.floor(this.frameCounter / 20) % 2;
    this.ctx.save();
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = 'bold 14px "Courier New", monospace';
    this.ctx.textAlign = 'left';
    this.ctx.textBaseline = 'top';

    const entries = [
      { sprite: SPRITES.ufo,                                  color: '#FF2E6F', label: '= ?'  },
      { sprite: frameAlt ? SPRITES.htB  : SPRITES.htA,        color: '#B388FF', label: '= 30' },
      { sprite: frameAlt ? SPRITES.athB : SPRITES.athA,       color: '#5AD0FF', label: '= 20' },
      { sprite: frameAlt ? SPRITES.lowB : SPRITES.lowA,       color: '#FF5555', label: '= 10' },
    ];
    const slotW = this.canvas.width / entries.length;
    for (let i = 0; i < entries.length; i++) {
      const ex = slotW * i + slotW / 2 - 50;
      this._drawPixels(entries[i].sprite, ex, rowY, 2, entries[i].color);
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.fillText(entries[i].label, ex + 42, rowY + 6);
    }
    this.ctx.restore();
  }

  _renderPause() {
    this.ctx.fillStyle = 'rgba(0,0,0,0.65)';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    this.ctx.save();
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.fillStyle = '#FFC700';
    this.ctx.font = 'bold 48px "Courier New", monospace';
    this.ctx.fillText('PAUSED', this.canvas.width / 2, this.canvas.height / 2);
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = '20px "Courier New", monospace';
    this.ctx.fillText('Press P to resume', this.canvas.width / 2, this.canvas.height / 2 + 46);
    this.ctx.restore();
  }

  _renderGameOver() {
    this.ctx.fillStyle = 'rgba(0,0,0,0.75)';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    this.ctx.save();
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.shadowColor = '#FF3030';
    this.ctx.shadowBlur = 14;
    this.ctx.fillStyle = '#FF3030';
    this.ctx.font = 'bold 52px "Courier New", monospace';
    this.ctx.fillText('GAME OVER', this.canvas.width / 2, this.canvas.height / 2 - 60);
    this.ctx.restore();
    this.ctx.save();
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = '22px "Courier New", monospace';
    this.ctx.fillText(`FINAL SCORE ${this.score.toString().padStart(6, '0')}`, this.canvas.width / 2, this.canvas.height / 2);
    this.ctx.fillText(`HI-SCORE    ${this.hiScore.toString().padStart(6, '0')}`, this.canvas.width / 2, this.canvas.height / 2 + 30);
    const pulse = Math.sin(this.frameCounter * 0.12) * 0.4 + 0.6;
    this.ctx.globalAlpha = pulse;
    this.ctx.fillStyle = '#FFC700';
    this.ctx.font = 'bold 18px "Courier New", monospace';
    this.ctx.fillText('PRESS SPACE TO RETRY', this.canvas.width / 2, this.canvas.height / 2 + 80);
    this.ctx.restore();
  }

  _renderLevelComplete() {
    this.ctx.save();
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.shadowColor = '#5AFF7A';
    this.ctx.shadowBlur = 14;
    this.ctx.fillStyle = '#5AFF7A';
    this.ctx.font = 'bold 46px "Courier New", monospace';
    this.ctx.fillText('WAVE CLEARED', this.canvas.width / 2, this.canvas.height / 2 - 40);
    this.ctx.restore();
    this.ctx.save();
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = '22px "Courier New", monospace';
    this.ctx.fillText(`ADVANCING TO WAVE ${this.level + 1}`, this.canvas.width / 2, this.canvas.height / 2 + 20);
    this.ctx.restore();
  }

  gameLoop() {
    try {
      this.update();
      this.render();
    } catch (error) {
      console.error('Game loop error:', error);
    }
    this._raf = requestAnimationFrame(() => this.gameLoop());
  }

  destroy() {
    if (this._raf) cancelAnimationFrame(this._raf);
    if (this.keyDownHandler) document.removeEventListener('keydown', this.keyDownHandler);
    if (this.keyUpHandler) document.removeEventListener('keyup', this.keyUpHandler);
    this.audio.destroy();
  }
}
