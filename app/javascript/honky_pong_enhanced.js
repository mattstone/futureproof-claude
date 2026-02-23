// Honky Pong - Donkey Kong Clone Game Engine
// Uses sprite-based rendering with canvas

export class HonkyPongGame {
  constructor(options) {
    this.canvas = options.canvas;
    this.ctx = this.canvas.getContext('2d');
    this.container = options.container;
    this.scoreEl = options.scoreElement;
    this.livesEl = options.livesElement;
    this.levelEl = options.levelElement;
    this.onStateChange = options.onStateChange || (() => {});

    // Canvas size
    this.W = 800;
    this.H = 600;
    this.canvas.width = this.W;
    this.canvas.height = this.H;

    // Game state
    this.state = 'ready'; // ready, playing, paused, gameover
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.keys = {};
    this.frame = 0;
    this.animId = null;

    // Constants
    this.GRAVITY = 0.5;
    this.JUMP_FORCE = -10;
    this.MOVE_SPEED = 3;
    this.CLIMB_SPEED = 2.5;

    // Load sprites
    this.sprites = {};
    this.spritesLoaded = false;
    this.loadSprites();

    // Build level
    this.buildLevel();

    // Input
    this._onKeyDown = (e) => this.onKeyDown(e);
    this._onKeyUp = (e) => this.onKeyUp(e);
    document.addEventListener('keydown', this._onKeyDown);
    document.addEventListener('keyup', this._onKeyUp);

    // Initial render
    this.render();
  }

  destroy() {
    document.removeEventListener('keydown', this._onKeyDown);
    document.removeEventListener('keyup', this._onKeyUp);
    if (this.animId) cancelAnimationFrame(this.animId);
  }

  loadSprites() {
    const assets = this.container.dataset;
    const spriteMap = {
      mario: assets.assetMario,
      marioRun1: assets.assetMarioRun,
      marioRun2: assets.assetMarioRun2,
      marioLeft: assets.assetMarioLeft,
      marioLeftRun1: assets.assetMarioLeftRun,
      marioLeftRun2: assets.assetMarioLeftRun2,
      marioClimb: assets.assetMarioUp,
      marioClimbLeft: assets.assetMarioUpLeft,
      dk: assets.assetDonkeyKong,
      barrel: assets.assetBarril,
      barrelStack: assets.assetBarriles,
      ladder: assets.assetEscalera,
      hammer: assets.assetHammer,
      hammerRun1: assets.assetHammerRun,
      hammerRun2: assets.assetHammerRun2,
      peach: assets.assetPeach,
      platform: assets.assetPiso,
      heart: assets.assetHeart,
      gameOver: assets.assetGameOver
    };

    let loaded = 0;
    const total = Object.keys(spriteMap).length;

    for (const [key, url] of Object.entries(spriteMap)) {
      if (!url) { loaded++; continue; }
      const img = new Image();
      img.onload = () => {
        loaded++;
        if (loaded >= total) this.spritesLoaded = true;
      };
      img.onerror = () => {
        loaded++;
        if (loaded >= total) this.spritesLoaded = true;
      };
      img.src = url;
      this.sprites[key] = img;
    }
  }

  buildLevel() {
    // Platforms - classic DK layout with slight slopes
    // Each platform: { x, y, w, h, slope }
    this.platforms = [
      { x: 0, y: 560, w: 800, h: 20, slope: 0 },          // Ground
      { x: 100, y: 460, w: 700, h: 16, slope: -0.025 },    // L1 slopes down-right
      { x: 0, y: 360, w: 700, h: 16, slope: 0.025 },       // L2 slopes up-right
      { x: 100, y: 260, w: 700, h: 16, slope: -0.025 },    // L3 slopes down-right
      { x: 0, y: 170, w: 700, h: 16, slope: 0.025 },       // L4 slopes up-right
      { x: 150, y: 80, w: 300, h: 16, slope: 0 }           // Top platform (DK + Peach)
    ];

    // Ladders connecting platforms
    this.ladders = [
      { x: 720, y: 470, w: 30, h: 95 },    // Ground → L1
      { x: 180, y: 370, w: 30, h: 95 },     // L1 → L2
      { x: 600, y: 270, w: 30, h: 95 },     // L2 → L3
      { x: 180, y: 180, w: 30, h: 85 },     // L3 → L4
      { x: 400, y: 90, w: 30, h: 85 },      // L4 → Top
      // Extra partial ladders for variety
      { x: 400, y: 470, w: 30, h: 95 },     // Ground → L1 (mid)
      { x: 550, y: 370, w: 30, h: 95 },     // L1 → L2 (mid)
      { x: 300, y: 270, w: 30, h: 95 },     // L2 → L3 (mid)
      { x: 500, y: 180, w: 30, h: 85 },     // L3 → L4 (mid)
    ];

    // Mario start position
    this.mario = {
      x: 50, y: 524, w: 28, h: 36,
      vx: 0, vy: 0,
      onGround: false, onLadder: false,
      facingRight: true, moving: false,
      hasHammer: false, hammerTime: 0,
      invincible: false, invincibleTime: 0
    };

    // DK position
    this.dk = {
      x: 100, y: 20, w: 64, h: 60,
      throwTimer: 60, animFrame: 0
    };

    // Princess
    this.princess = {
      x: 320, y: 30, w: 36, h: 48
    };

    // Hammer powerup
    this.hammer = {
      x: 380, y: 234, w: 24, h: 24,
      active: true, respawnTimer: 0
    };

    // Barrel stack (visual)
    this.barrelStack = {
      x: 50, y: 18, w: 40, h: 60
    };

    // Barrels array
    this.barrels = [];
  }

  onKeyDown(e) {
    this.keys[e.key] = true;
    if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', ' '].includes(e.key)) {
      e.preventDefault();
    }
  }

  onKeyUp(e) {
    this.keys[e.key] = false;
  }

  start() {
    if (this.state === 'ready' || this.state === 'gameover') {
      this.reset();
      this.state = 'playing';
      this.loop();
    }
  }

  togglePause() {
    if (this.state === 'playing') {
      this.state = 'paused';
    } else if (this.state === 'paused') {
      this.state = 'playing';
      this.loop();
    }
    this.onStateChange(this.state);
  }

  restart() {
    this.reset();
    this.state = 'playing';
    this.loop();
  }

  reset() {
    this.score = 0;
    this.lives = 3;
    this.level = 1;
    this.resetMario();
    this.barrels = [];
    this.dk.throwTimer = 60;
    this.hammer.active = true;
    this.updateHUD();
  }

  resetMario() {
    this.mario.x = 50;
    this.mario.y = 524;
    this.mario.vx = 0;
    this.mario.vy = 0;
    this.mario.hasHammer = false;
    this.mario.hammerTime = 0;
    this.mario.onGround = false;
    this.mario.onLadder = false;
    this.mario.facingRight = true;
  }

  loop() {
    if (this.state !== 'playing') return;
    this.frame++;
    this.update();
    this.render();
    this.animId = requestAnimationFrame(() => this.loop());
  }

  update() {
    this.updateMario();
    this.updateDK();
    this.updateBarrels();
    this.checkCollisions();
    this.checkWin();
  }

  updateMario() {
    const m = this.mario;

    // Horizontal movement
    if (this.keys['ArrowLeft']) {
      m.vx = -this.MOVE_SPEED;
      m.facingRight = false;
      m.moving = true;
    } else if (this.keys['ArrowRight']) {
      m.vx = this.MOVE_SPEED;
      m.facingRight = true;
      m.moving = true;
    } else {
      m.vx = 0;
      m.moving = false;
    }

    // Ladder check
    m.onLadder = this.isOnLadder(m);

    if (m.onLadder) {
      if (this.keys['ArrowUp']) {
        m.vy = -this.CLIMB_SPEED;
        m.onGround = false;
      } else if (this.keys['ArrowDown']) {
        m.vy = this.CLIMB_SPEED;
        m.onGround = false;
      } else {
        if (!m.onGround) m.vy = 0;
      }
    } else {
      m.vy += this.GRAVITY;
      if (this.keys['ArrowUp'] && m.onGround) {
        m.vy = this.JUMP_FORCE;
        m.onGround = false;
      }
    }

    m.x += m.vx;
    m.y += m.vy;

    // Bounds
    m.x = Math.max(0, Math.min(m.x, this.W - m.w));
    if (m.y > this.H) this.marioHit(); // fell off

    // Platform collision
    m.onGround = false;
    for (const p of this.platforms) {
      if (this.landOnPlatform(m, p)) {
        m.onGround = true;
        break;
      }
    }

    // Hammer timer
    if (m.hasHammer) {
      m.hammerTime--;
      if (m.hammerTime <= 0) m.hasHammer = false;
    }

    // Invincibility
    if (m.invincible) {
      m.invincibleTime--;
      if (m.invincibleTime <= 0) m.invincible = false;
    }
  }

  isOnLadder(obj) {
    for (const l of this.ladders) {
      if (obj.x + obj.w > l.x + 5 && obj.x < l.x + l.w - 5 &&
          obj.y + obj.h > l.y && obj.y < l.y + l.h) {
        return true;
      }
    }
    return false;
  }

  landOnPlatform(obj, p) {
    const cx = obj.x + obj.w / 2;
    if (cx < p.x || cx > p.x + p.w) return false;
    const py = p.y + (cx - p.x) * p.slope;
    if (obj.y + obj.h >= py && obj.y + obj.h <= py + p.h + 8 && obj.vy >= 0) {
      obj.y = py - obj.h;
      obj.vy = 0;
      return true;
    }
    return false;
  }

  updateDK() {
    this.dk.throwTimer--;
    this.dk.animFrame++;

    if (this.dk.throwTimer <= 0) {
      // Throw barrel
      this.barrels.push({
        x: this.dk.x + 50, y: this.dk.y + 50,
        w: 22, h: 22,
        vx: 2, vy: 0,
        dir: 1, rotation: 0,
        onGround: false
      });
      // Faster throws at higher levels
      this.dk.throwTimer = Math.max(30, 100 - this.level * 10);
      this.score += 10;
      this.updateHUD();
    }
  }

  updateBarrels() {
    for (let i = this.barrels.length - 1; i >= 0; i--) {
      const b = this.barrels[i];
      b.vy += this.GRAVITY;
      b.x += b.vx;
      b.y += b.vy;
      b.rotation += b.vx * 0.05;

      b.onGround = false;
      for (const p of this.platforms) {
        if (this.landOnPlatform(b, p)) {
          b.onGround = true;
          // Roll direction based on platform slope
          b.vx = (p.slope < 0 ? 2.5 : p.slope > 0 ? -2.5 : b.dir * 2) * (1 + this.level * 0.1);
          b.dir = b.vx > 0 ? 1 : -1;
          break;
        }
      }

      // Random ladder descent
      if (b.onGround && Math.random() < 0.012) {
        for (const l of this.ladders) {
          if (b.x + b.w > l.x && b.x < l.x + l.w &&
              b.y + b.h >= l.y - 5 && b.y + b.h <= l.y + 20) {
            b.vx = 0;
            b.x = l.x + (l.w - b.w) / 2;
            b.vy = 2.5;
            break;
          }
        }
      }

      // Remove off-screen
      if (b.y > this.H + 50 || b.x < -50 || b.x > this.W + 50) {
        this.barrels.splice(i, 1);
      }
    }
  }

  checkCollisions() {
    const m = this.mario;
    if (m.invincible) return;

    for (let i = this.barrels.length - 1; i >= 0; i--) {
      if (this.boxCollide(m, this.barrels[i])) {
        if (m.hasHammer) {
          this.barrels.splice(i, 1);
          this.score += 300;
          this.updateHUD();
        } else {
          this.marioHit();
          return;
        }
      }
      // Score for jumping over barrels
      const b = this.barrels[i];
      if (b && !b.scored && m.y + m.h < b.y && Math.abs(m.x - b.x) < 30) {
        b.scored = true;
        this.score += 100;
        this.updateHUD();
      }
    }

    // Hammer pickup
    if (this.hammer.active && this.boxCollide(m, this.hammer)) {
      m.hasHammer = true;
      m.hammerTime = 360; // 6 seconds at 60fps
      this.hammer.active = false;
      this.score += 500;
      this.updateHUD();
      this.hammer.respawnTimer = 600; // respawn after 10s
    }

    // Hammer respawn
    if (!this.hammer.active) {
      this.hammer.respawnTimer--;
      if (this.hammer.respawnTimer <= 0) this.hammer.active = true;
    }
  }

  boxCollide(a, b) {
    return a.x < b.x + b.w && a.x + a.w > b.x &&
           a.y < b.y + b.h && a.y + a.h > b.y;
  }

  checkWin() {
    if (this.boxCollide(this.mario, this.princess)) {
      this.score += 5000;
      this.level++;
      this.lives = Math.min(this.lives + 1, 5);
      this.resetMario();
      this.barrels = [];
      this.dk.throwTimer = 60;
      this.hammer.active = true;
      this.updateHUD();
    }
  }

  marioHit() {
    this.lives--;
    this.updateHUD();
    if (this.lives <= 0) {
      this.gameOver();
    } else {
      this.mario.invincible = true;
      this.mario.invincibleTime = 120;
      this.resetMario();
      this.mario.invincible = true;
      this.mario.invincibleTime = 120;
      this.barrels = [];
    }
  }

  gameOver() {
    this.state = 'gameover';
    if (this.animId) cancelAnimationFrame(this.animId);
    this.render();
    this.onStateChange('gameover');
  }

  updateHUD() {
    if (this.scoreEl) this.scoreEl.textContent = this.score.toString().padStart(6, '0');
    if (this.livesEl) this.livesEl.textContent = this.lives;
    if (this.levelEl) this.levelEl.textContent = this.level;
  }

  // ─── RENDERING ───

  render() {
    const ctx = this.ctx;
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, this.W, this.H);

    this.drawPlatforms();
    this.drawLadders();
    this.drawDK();
    this.drawBarrelStack();
    this.drawPrincess();
    if (this.hammer.active) this.drawHammer();
    this.drawBarrels();
    this.drawMario();
    this.drawHammerTimer();
    this.drawLives();

    if (this.state === 'ready') this.drawStartScreen();
    else if (this.state === 'paused') this.drawPauseScreen();
    else if (this.state === 'gameover') this.drawGameOverScreen();
  }

  drawSprite(key, x, y, w, h) {
    const img = this.sprites[key];
    if (img && img.complete && img.naturalWidth > 0) {
      this.ctx.drawImage(img, x, y, w, h);
      return true;
    }
    return false;
  }

  drawPlatforms() {
    const ctx = this.ctx;
    for (const p of this.platforms) {
      if (this.sprites.platform && this.sprites.platform.complete) {
        // Tile the platform sprite
        const tileW = 60;
        const tileH = p.h;
        for (let tx = p.x; tx < p.x + p.w; tx += tileW) {
          const w = Math.min(tileW, p.x + p.w - tx);
          const py = p.y + (tx + w/2 - p.x) * p.slope;
          ctx.drawImage(this.sprites.platform, 0, 0, this.sprites.platform.naturalWidth * (w/tileW), this.sprites.platform.naturalHeight, tx, py, w, tileH);
        }
      } else {
        // Fallback: red girders
        ctx.fillStyle = '#FF3333';
        for (let tx = p.x; tx < p.x + p.w; tx += 32) {
          const w = Math.min(32, p.x + p.w - tx);
          const py = p.y + (tx + w/2 - p.x) * p.slope;
          ctx.fillRect(tx, py, w, p.h);
        }
      }
    }
  }

  drawLadders() {
    const ctx = this.ctx;
    for (const l of this.ladders) {
      if (!this.drawSprite('ladder', l.x - 2, l.y, l.w + 4, l.h)) {
        // Fallback
        ctx.fillStyle = '#00CCFF';
        ctx.fillRect(l.x, l.y, 4, l.h);
        ctx.fillRect(l.x + l.w - 4, l.y, 4, l.h);
        ctx.fillStyle = '#66DDFF';
        for (let ry = l.y + 8; ry < l.y + l.h; ry += 12) {
          ctx.fillRect(l.x, ry, l.w, 3);
        }
      }
    }
  }

  drawDK() {
    const dk = this.dk;
    if (!this.drawSprite('dk', dk.x, dk.y, dk.w, dk.h)) {
      // Fallback
      this.ctx.fillStyle = '#8B4513';
      this.ctx.fillRect(dk.x, dk.y, dk.w, dk.h);
      this.ctx.fillStyle = '#FFF';
      this.ctx.font = 'bold 14px monospace';
      this.ctx.fillText('DK', dk.x + 18, dk.y + 35);
    }
  }

  drawBarrelStack() {
    const bs = this.barrelStack;
    if (!this.drawSprite('barrelStack', bs.x, bs.y, bs.w, bs.h)) {
      this.ctx.fillStyle = '#D2691E';
      for (let i = 0; i < 3; i++) {
        this.ctx.fillRect(bs.x + 5, bs.y + i * 18 + 5, 30, 14);
      }
    }
  }

  drawPrincess() {
    const p = this.princess;
    if (!this.drawSprite('peach', p.x, p.y, p.w, p.h)) {
      this.ctx.fillStyle = '#FFB6C1';
      this.ctx.fillRect(p.x, p.y, p.w, p.h);
      this.ctx.fillStyle = '#FFF';
      this.ctx.font = '10px monospace';
      this.ctx.fillText('HELP!', p.x, p.y - 5);
    }
  }

  drawHammer() {
    const h = this.hammer;
    if (!this.drawSprite('hammer', h.x, h.y, h.w, h.h)) {
      this.ctx.fillStyle = '#FFD700';
      this.ctx.fillRect(h.x, h.y, h.w, h.h);
    }
  }

  drawBarrels() {
    const ctx = this.ctx;
    for (const b of this.barrels) {
      ctx.save();
      ctx.translate(b.x + b.w / 2, b.y + b.h / 2);
      ctx.rotate(b.rotation);
      if (!this.drawSprite('barrel', -b.w / 2, -b.h / 2, b.w, b.h)) {
        ctx.fillStyle = '#D2691E';
        ctx.fillRect(-b.w / 2, -b.h / 2, b.w, b.h);
        ctx.strokeStyle = '#8B4513';
        ctx.lineWidth = 2;
        ctx.strokeRect(-b.w / 2, -b.h / 2, b.w, b.h);
      }
      ctx.restore();
    }
  }

  drawMario() {
    const m = this.mario;
    const ctx = this.ctx;

    // Flicker when invincible
    if (m.invincible && Math.floor(this.frame / 4) % 2 === 0) return;

    let spriteKey;
    const runFrame = Math.floor(this.frame / 8) % 2;

    if (m.onLadder && (this.keys['ArrowUp'] || this.keys['ArrowDown'])) {
      spriteKey = Math.floor(this.frame / 10) % 2 === 0 ? 'marioClimb' : 'marioClimbLeft';
    } else if (m.hasHammer) {
      if (m.moving) {
        spriteKey = runFrame === 0 ? 'hammerRun1' : 'hammerRun2';
      } else {
        spriteKey = 'hammer'; // standing with hammer
      }
    } else if (m.moving) {
      if (m.facingRight) {
        spriteKey = runFrame === 0 ? 'marioRun1' : 'marioRun2';
      } else {
        spriteKey = runFrame === 0 ? 'marioLeftRun1' : 'marioLeftRun2';
      }
    } else {
      spriteKey = m.facingRight ? 'mario' : 'marioLeft';
    }

    if (!this.drawSprite(spriteKey, m.x, m.y, m.w, m.h)) {
      // Fallback colored rectangle
      ctx.fillStyle = m.hasHammer ? '#FFD700' : '#FF0000';
      ctx.fillRect(m.x, m.y, m.w, m.h);
      ctx.fillStyle = '#FFFFFF';
      const eyeX = m.facingRight ? m.x + 18 : m.x + 6;
      ctx.fillRect(eyeX, m.y + 8, 5, 5);
    }
  }

  drawHammerTimer() {
    if (!this.mario.hasHammer) return;
    const ctx = this.ctx;
    const secs = Math.ceil(this.mario.hammerTime / 60);
    ctx.fillStyle = '#FFD700';
    ctx.font = 'bold 16px monospace';
    ctx.fillText(`🔨 ${secs}s`, this.W - 80, 25);
  }

  drawLives() {
    const ctx = this.ctx;
    for (let i = 0; i < this.lives; i++) {
      if (!this.drawSprite('heart', this.W - 30 - i * 28, this.H - 30, 22, 22)) {
        ctx.fillStyle = '#FF0000';
        ctx.font = '18px sans-serif';
        ctx.fillText('❤️', this.W - 30 - i * 28, this.H - 12);
      }
    }
  }

  drawStartScreen() {
    const ctx = this.ctx;
    ctx.fillStyle = 'rgba(0,0,0,0.7)';
    ctx.fillRect(0, 0, this.W, this.H);
    ctx.fillStyle = '#FF0000';
    ctx.font = 'bold 48px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('HONKY PONG', this.W / 2, this.H / 2 - 40);
    ctx.fillStyle = '#FFD700';
    ctx.font = '24px Arial';
    ctx.fillText('Press START to play!', this.W / 2, this.H / 2 + 20);
    ctx.fillStyle = '#FFFFFF';
    ctx.font = '16px Arial';
    ctx.fillText('Arrow Keys to move • Up to jump/climb • Space for hammer', this.W / 2, this.H / 2 + 60);
    ctx.textAlign = 'left';
  }

  drawPauseScreen() {
    const ctx = this.ctx;
    ctx.fillStyle = 'rgba(0,0,0,0.5)';
    ctx.fillRect(0, 0, this.W, this.H);
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 48px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('PAUSED', this.W / 2, this.H / 2);
    ctx.textAlign = 'left';
  }

  drawGameOverScreen() {
    const ctx = this.ctx;
    ctx.fillStyle = 'rgba(0,0,0,0.85)';
    ctx.fillRect(0, 0, this.W, this.H);

    // Try game over sprite
    if (!this.drawSprite('gameOver', this.W / 2 - 150, this.H / 2 - 100, 300, 120)) {
      ctx.fillStyle = '#FF0000';
      ctx.font = 'bold 56px Arial';
      ctx.textAlign = 'center';
      ctx.fillText('GAME OVER', this.W / 2, this.H / 2 - 20);
    }

    ctx.fillStyle = '#FFFFFF';
    ctx.font = '28px Arial';
    ctx.textAlign = 'center';
    ctx.fillText(`Final Score: ${this.score.toString().padStart(6, '0')}`, this.W / 2, this.H / 2 + 40);
    ctx.fillStyle = '#FFD700';
    ctx.font = '20px Arial';
    ctx.fillText('Press START to play again', this.W / 2, this.H / 2 + 80);
    ctx.textAlign = 'left';
  }
}
