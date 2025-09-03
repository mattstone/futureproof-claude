// Sprite Extraction System for Donkey Kong
// Contains all the sprite extraction data and coordinates we've spent days building

export const SpriteExtractor = {
  // Mario sprite coordinates from extracted data
  marioSprites: {
    standing: { left: { x: 120, y: 0, width: 24, height: 24 }, right: { x: 160, y: 0, width: 24, height: 24 } },
    running: { 
      left: [{ x: 40, y: 0, width: 24, height: 24 }, { x: 80, y: 0, width: 24, height: 24 }],
      right: [{ x: 200, y: 0, width: 24, height: 24 }, { x: 240, y: 0, width: 24, height: 24 }]
    },
    climbing: { frames: Array.from({length: 8}, (_, i) => ({ x: i * 40, y: 40, width: 24, height: 24 })) },
    hammer: {
      left: { frames: Array.from({length: 4}, (_, i) => ({ x: i * 40, y: 80, width: 24, height: 24 })) },
      right: { frames: Array.from({length: 4}, (_, i) => ({ x: 160 + (i * 40), y: 80, width: 24, height: 24 })) }
    },
    death: { frames: Array.from({length: 8}, (_, i) => ({ x: i * 40, y: 120, width: 24, height: 24 })) }
  },

  // Donkey Kong sprite coordinates
  donkeyKongSprites: {
    chestBeating: [
      { x: 50, y: 57, width: 46, height: 31 },   // Left arm
      { x: 103, y: 57, width: 46, height: 31 },  // Both arms
      { x: 150, y: 57, width: 46, height: 31 }   // Right arm
    ],
    throwingBarrel: { x: 1, y: 57, width: 46, height: 31 }
  },

  // Pauline sprite coordinates
  paulineSprites: {
    help: [
      { x: 0, y: 0, width: 15, height: 22 },
      { x: 50, y: 0, width: 15, height: 22 }
    ]
  },

  // Enemy sprites (barrels, fireballs, etc.)
  enemySprites: {
    barrels: [
      { x: 5, y: 7, width: 15, height: 10 },
      { x: 5, y: 27, width: 15, height: 10 }
    ],
    fireballs: {
      type0: { x: 102, y: 7, width: 10, height: 10 },
      type1: { x: 153, y: 7, width: 10, height: 10 },
      type2: { x: 204, y: 7, width: 10, height: 10 }
    },
    hammer: { x: 269, y: 54, width: 7, height: 15 }
  },

  // Level structure coordinates from extracted data
  levelSprites: {
    "long-girder": { x: 18, y: 195, width: 48, height: 8 },
    "short-girder": { x: 107, y: 219, width: 24, height: 8 },
    "ladder": { x: 101, y: 200, width: 16, height: 30 }
  },

  // Color palette from extracted data
  colors: {
    girder: '#FF6B47',
    ladder: '#DAA520',
    background: '#000000',
    oil: '#FF0000',
    mario: '#0000FF',
    kong: '#8B4513',
    pauline: '#FF69B4',
    barrel: '#8B4513',
    fireball: '#FF4500',
    hammer: '#FFD700'
  }
};

// Helper functions for sprite rendering
export const SpriteHelper = {
  drawMarioSprite(ctx, sprites, mario, marioObj) {
    if (!sprites.mario) {
      // Fallback
      ctx.fillStyle = marioObj.hasHammer ? '#FF0000' : '#0000FF';
      ctx.fillRect(marioObj.x, marioObj.y, marioObj.width, marioObj.height);
      return;
    }

    let sourceX = 0, sourceY = 0;
    const frameIndex = Math.floor(marioObj.animFrame) % 4;
    
    switch (marioObj.state) {
      case 'standing':
        sourceY = 0;
        sourceX = marioObj.facing === 'left' ? 120 : 160;
        break;
      case 'running':
        sourceY = 0;
        sourceX = marioObj.facing === 'left' ? 
                  [40, 80][frameIndex % 2] :
                  [200, 240][frameIndex % 2];
        break;
      case 'climbing':
        sourceY = 40;
        sourceX = Math.min(frameIndex * 40, 280);
        break;
      case 'hammer':
        sourceY = 80;
        sourceX = marioObj.facing === 'left' ? 
                  frameIndex * 40 :
                  160 + (frameIndex * 40);
        break;
      case 'death':
      case 'tumbling':
        sourceY = 120;
        sourceX = frameIndex * 40;
        break;
    }
    
    ctx.drawImage(
      sprites.mario,
      sourceX, sourceY, 24, 24,
      marioObj.x, marioObj.y, marioObj.width, marioObj.height
    );
  },

  drawDonkeyKongSprite(ctx, sprites, donkeyKong) {
    if (!sprites.enemies) {
      ctx.fillStyle = '#8B4513';
      ctx.fillRect(donkeyKong.x, donkeyKong.y, donkeyKong.width, donkeyKong.height);
      return;
    }
    
    let sourceX = 1, sourceY = 57;
    const frameIndex = Math.floor(donkeyKong.animFrame) % 5;
    
    if (donkeyKong.state === 'throwing_barrel') {
      sourceX = 1;
    } else {
      const poses = [50, 103, 150];
      sourceX = poses[frameIndex % 3];
    }
    
    ctx.drawImage(
      sprites.enemies,
      sourceX, sourceY, 46, 31,
      donkeyKong.x, donkeyKong.y, donkeyKong.width, donkeyKong.height
    );
  }
};