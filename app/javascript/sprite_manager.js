// Professional Sprite Manager for Honky Pong
export class SpriteManager {
  constructor(ctx) {
    this.ctx = ctx;
    this.sprites = new Map();
    this.animations = new Map();
    this.createAllSprites();
  }
  
  createAllSprites() {
    this.createMarioSprites();
    this.createDonkeyKongSprites();
    this.createPrincessSprites();
    this.createBarrelSprites();
    this.createHammerSprites();
    this.createFireballSprites();
    this.createLadderSprites();
    this.createGirderSprites();
    this.createOilDrumSprites();
  }
  
  // Create detailed Mario/Jumpman sprites
  createMarioSprites() {
    // Mario standing right
    this.sprites.set('mario_right', {
      width: 16,
      height: 24,
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        // Hat
        ctx.fillStyle = '#CC0000';
        ctx.fillRect(x + 2*s, y, 12*s, 6*s);
        
        // Face
        ctx.fillStyle = '#FFE4B5';
        ctx.fillRect(x + 3*s, y + 6*s, 10*s, 8*s);
        
        // Eyes
        ctx.fillStyle = '#000000';
        ctx.fillRect(x + 5*s, y + 8*s, 2*s, 2*s);
        ctx.fillRect(x + 9*s, y + 8*s, 2*s, 2*s);
        
        // Mustache
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(x + 6*s, y + 11*s, 4*s, 2*s);
        
        // Overalls
        ctx.fillStyle = '#0066FF';
        ctx.fillRect(x + 1*s, y + 14*s, 14*s, 10*s);
        
        // Overalls straps
        ctx.fillStyle = '#004499';
        ctx.fillRect(x + 4*s, y + 14*s, 2*s, 4*s);
        ctx.fillRect(x + 10*s, y + 14*s, 2*s, 4*s);
        
        // Arms
        ctx.fillStyle = '#FFE4B5';
        ctx.fillRect(x, y + 16*s, 3*s, 6*s);
        ctx.fillRect(x + 13*s, y + 16*s, 3*s, 6*s);
        
        // Shoes
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(x + 2*s, y + 22*s, 5*s, 2*s);
        ctx.fillRect(x + 9*s, y + 22*s, 5*s, 2*s);
      }
    });
    
    // Mario standing left (mirrored)
    this.sprites.set('mario_left', {
      width: 16,
      height: 24,
      draw: (ctx, x, y, scale = 1) => {
        ctx.save();
        ctx.translate(x + 8*scale, y + 12*scale);
        ctx.scale(-1, 1);
        this.sprites.get('mario_right').draw(ctx, -8*scale, -12*scale, scale);
        ctx.restore();
      }
    });
    
    // Mario walking frame 1
    this.sprites.set('mario_walk1', {
      width: 16,
      height: 24,
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        // Similar to standing but with legs positioned differently
        // Hat
        ctx.fillStyle = '#CC0000';
        ctx.fillRect(x + 2*s, y, 12*s, 6*s);
        
        // Face
        ctx.fillStyle = '#FFE4B5';
        ctx.fillRect(x + 3*s, y + 6*s, 10*s, 8*s);
        
        // Eyes
        ctx.fillStyle = '#000000';
        ctx.fillRect(x + 5*s, y + 8*s, 2*s, 2*s);
        ctx.fillRect(x + 9*s, y + 8*s, 2*s, 2*s);
        
        // Mustache
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(x + 6*s, y + 11*s, 4*s, 2*s);
        
        // Overalls
        ctx.fillStyle = '#0066FF';
        ctx.fillRect(x + 1*s, y + 14*s, 14*s, 8*s);
        
        // Walking legs - frame 1
        ctx.fillStyle = '#0066FF';
        ctx.fillRect(x + 3*s, y + 20*s, 4*s, 4*s); // Left leg forward
        ctx.fillRect(x + 9*s, y + 21*s, 4*s, 3*s); // Right leg back
        
        // Shoes
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(x + 2*s, y + 22*s, 5*s, 2*s);
        ctx.fillRect(x + 10*s, y + 22*s, 4*s, 2*s);
      }
    });
    
    // Mario with hammer
    this.sprites.set('mario_hammer', {
      width: 20,
      height: 24,
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        // Draw mario body
        this.sprites.get('mario_right').draw(ctx, x, y, scale);
        
        // Change colors to indicate power-up
        ctx.fillStyle = '#FFD700'; // Golden overalls
        ctx.fillRect(x + 1*s, y + 14*s, 14*s, 10*s);
        
        // Hammer
        ctx.fillStyle = '#8B4513'; // Handle
        ctx.fillRect(x + 16*s, y + 8*s, 2*s, 12*s);
        
        ctx.fillStyle = '#666666'; // Hammer head
        ctx.fillRect(x + 14*s, y + 6*s, 6*s, 6*s);
        
        // Hammer glow effect
        ctx.fillStyle = '#FFFF00';
        ctx.fillRect(x + 13*s, y + 5*s, 8*s, 1*s);
        ctx.fillRect(x + 13*s, y + 12*s, 8*s, 1*s);
      }
    });
    
    // Mario climbing
    this.sprites.set('mario_climb', {
      width: 16,
      height: 24,
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        // Hat
        ctx.fillStyle = '#CC0000';
        ctx.fillRect(x + 2*s, y, 12*s, 6*s);
        
        // Face
        ctx.fillStyle = '#FFE4B5';
        ctx.fillRect(x + 3*s, y + 6*s, 10*s, 8*s);
        
        // Eyes looking up
        ctx.fillStyle = '#000000';
        ctx.fillRect(x + 5*s, y + 7*s, 2*s, 2*s);
        ctx.fillRect(x + 9*s, y + 7*s, 2*s, 2*s);
        
        // Overalls
        ctx.fillStyle = '#0066FF';
        ctx.fillRect(x + 2*s, y + 14*s, 12*s, 10*s);
        
        // Arms reaching up
        ctx.fillStyle = '#FFE4B5';
        ctx.fillRect(x + 1*s, y + 12*s, 3*s, 8*s);
        ctx.fillRect(x + 12*s, y + 12*s, 3*s, 8*s);
        
        // Feet
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(x + 4*s, y + 22*s, 8*s, 2*s);
      }
    });
  }
  
  // Create detailed Donkey Kong sprites
  createDonkeyKongSprites() {
    this.sprites.set('donkey_kong', {
      width: 48,
      height: 40,
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        
        // Body
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(x + 8*s, y + 15*s, 32*s, 25*s);
        
        // Chest
        ctx.fillStyle = '#DEB887';
        ctx.fillRect(x + 12*s, y + 20*s, 24*s, 15*s);
        
        // Head
        ctx.fillStyle = '#DEB887';
        ctx.fillRect(x + 10*s, y + 5*s, 28*s, 20*s);
        
        // Hair/crown
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(x + 12*s, y, 24*s, 8*s);
        
        // Eyes
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(x + 16*s, y + 12*s, 6*s, 4*s);
        ctx.fillRect(x + 26*s, y + 12*s, 6*s, 4*s);
        
        ctx.fillStyle = '#000000';
        ctx.fillRect(x + 18*s, y + 13*s, 2*s, 2*s);
        ctx.fillRect(x + 28*s, y + 13*s, 2*s, 2*s);
        
        // Nostrils
        ctx.fillStyle = '#000000';
        ctx.fillRect(x + 22*s, y + 18*s, 2*s, 2*s);
        ctx.fillRect(x + 26*s, y + 18*s, 2*s, 2*s);
        
        // Arms
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(x, y + 20*s, 12*s, 15*s);
        ctx.fillRect(x + 36*s, y + 20*s, 12*s, 15*s);
        
        // Hands
        ctx.fillStyle = '#DEB887';
        ctx.fillRect(x + 2*s, y + 32*s, 8*s, 8*s);
        ctx.fillRect(x + 38*s, y + 32*s, 8*s, 8*s);
        
        // Legs
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(x + 12*s, y + 35*s, 8*s, 5*s);
        ctx.fillRect(x + 28*s, y + 35*s, 8*s, 5*s);
      }
    });
    
    // Donkey Kong beating chest
    this.sprites.set('donkey_kong_beating', {
      width: 48,
      height: 40,
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        
        // Draw base sprite
        this.sprites.get('donkey_kong').draw(ctx, x, y, scale);
        
        // Angry eyes
        ctx.fillStyle = '#FF0000';
        ctx.fillRect(x + 18*s, y + 13*s, 2*s, 2*s);
        ctx.fillRect(x + 28*s, y + 13*s, 2*s, 2*s);
        
        // Open mouth
        ctx.fillStyle = '#FF0000';
        ctx.fillRect(x + 20*s, y + 22*s, 8*s, 4*s);
        
        // Chest beating effect
        ctx.fillStyle = '#FFAA00';
        ctx.fillRect(x + 15*s, y + 25*s, 6*s, 6*s);
        ctx.fillRect(x + 27*s, y + 25*s, 6*s, 6*s);
      }
    });
    
    // Donkey Kong throwing
    this.sprites.set('donkey_kong_throwing', {
      width: 52,
      height: 40,
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        
        // Draw base body
        this.sprites.get('donkey_kong').draw(ctx, x, y, scale);
        
        // Throwing arm extended
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(x + 40*s, y + 15*s, 12*s, 8*s);
        
        // Extended hand
        ctx.fillStyle = '#DEB887';
        ctx.fillRect(x + 48*s, y + 18*s, 4*s, 6*s);
      }
    });
  }
  
  // Create Princess Pauline sprites
  createPrincessSprites() {
    this.sprites.set('princess', {
      width: 16,
      height: 24,
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        
        // Dress
        ctx.fillStyle = '#FF69B4';
        ctx.fillRect(x, y + 10*s, 16*s, 14*s);
        
        // Dress trim
        ctx.fillStyle = '#FFB6C1';
        ctx.fillRect(x, y + 10*s, 16*s, 2*s);
        ctx.fillRect(x, y + 22*s, 16*s, 2*s);
        
        // Head
        ctx.fillStyle = '#FFE4B5';
        ctx.fillRect(x + 3*s, y + 2*s, 10*s, 10*s);
        
        // Hair
        ctx.fillStyle = '#FFD700';
        ctx.fillRect(x + 2*s, y, 12*s, 8*s);
        
        // Crown/tiara
        ctx.fillStyle = '#FFFF00';
        ctx.fillRect(x + 4*s, y, 8*s, 2*s);
        ctx.fillRect(x + 6*s, y - 1*s, 2*s, 2*s);
        ctx.fillRect(x + 10*s, y - 1*s, 2*s, 2*s);
        
        // Eyes
        ctx.fillStyle = '#000000';
        ctx.fillRect(x + 5*s, y + 5*s, 2*s, 2*s);
        ctx.fillRect(x + 9*s, y + 5*s, 2*s, 2*s);
        
        // Eyelashes
        ctx.fillStyle = '#000000';
        ctx.fillRect(x + 4*s, y + 4*s, 1*s, 1*s);
        ctx.fillRect(x + 11*s, y + 4*s, 1*s, 1*s);
        
        // Lips
        ctx.fillStyle = '#FF0000';
        ctx.fillRect(x + 6*s, y + 8*s, 4*s, 2*s);
        
        // Arms
        ctx.fillStyle = '#FFE4B5';
        ctx.fillRect(x + 1*s, y + 12*s, 3*s, 8*s);
        ctx.fillRect(x + 12*s, y + 12*s, 3*s, 8*s);
      }
    });
    
    // Princess calling for help (animated)
    this.sprites.set('princess_help', {
      width: 16,
      height: 26,
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        
        // Draw base princess
        this.sprites.get('princess').draw(ctx, x, y + 2*s, scale);
        
        // Arms raised for help
        ctx.fillStyle = '#FFE4B5';
        ctx.fillRect(x + 1*s, y + 8*s, 3*s, 8*s);
        ctx.fillRect(x + 12*s, y + 8*s, 3*s, 8*s);
        
        // Hands raised
        ctx.fillStyle = '#FFE4B5';
        ctx.fillRect(x + 2*s, y + 4*s, 2*s, 4*s);
        ctx.fillRect(x + 12*s, y + 4*s, 2*s, 4*s);
      }
    });
  }
  
  // Create barrel sprites
  createBarrelSprites() {
    this.sprites.set('barrel', {
      width: 14,
      height: 12,
      draw: (ctx, x, y, scale = 1, rotation = 0) => {
        const s = scale;
        
        ctx.save();
        ctx.translate(x + 7*s, y + 6*s);
        ctx.rotate(rotation);
        
        // Barrel body
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(-7*s, -6*s, 14*s, 12*s);
        
        // Barrel bands
        ctx.fillStyle = '#654321';
        ctx.fillRect(-7*s, -5*s, 14*s, 1*s);
        ctx.fillRect(-7*s, -1*s, 14*s, 1*s);
        ctx.fillRect(-7*s, 4*s, 14*s, 1*s);
        
        // Barrel highlight
        ctx.fillStyle = '#CD853F';
        ctx.fillRect(-6*s, -5*s, 12*s, 2*s);
        
        // Side bands
        ctx.fillStyle = '#4A2C17';
        ctx.fillRect(-7*s, -6*s, 2*s, 12*s);
        ctx.fillRect(5*s, -6*s, 2*s, 12*s);
        
        ctx.restore();
      }
    });
  }
  
  // Create hammer sprites
  createHammerSprites() {
    this.sprites.set('hammer_pickup', {
      width: 16,
      height: 12,
      draw: (ctx, x, y, scale = 1, sparkle = 0) => {
        const s = scale;
        
        // Handle
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(x + 6*s, y - 2*s, 4*s, 12*s);
        
        // Hammer head
        ctx.fillStyle = '#666666';
        ctx.fillRect(x, y + 2*s, 16*s, 6*s);
        
        // Hammer head highlight
        ctx.fillStyle = '#999999';
        ctx.fillRect(x + 1*s, y + 3*s, 14*s, 2*s);
        
        // Handle wrap
        ctx.fillStyle = '#654321';
        ctx.fillRect(x + 6*s, y + 4*s, 4*s, 2*s);
        
        // Sparkle effect
        if (sparkle < 20) {
          ctx.fillStyle = '#FFFF00';
          ctx.fillRect(x - 2*s, y - 2*s, 2*s, 2*s);
          ctx.fillRect(x + 16*s, y + 8*s, 2*s, 2*s);
        }
        if (sparkle >= 20 && sparkle < 40) {
          ctx.fillStyle = '#FFFFFF';
          ctx.fillRect(x + 8*s, y - 3*s, 2*s, 2*s);
          ctx.fillRect(x - 1*s, y + 6*s, 2*s, 2*s);
        }
      }
    });
  }
  
  // Create fireball sprites
  createFireballSprites() {
    this.sprites.set('fireball', {
      width: 12,
      height: 12,
      draw: (ctx, x, y, scale = 1, frame = 0) => {
        const s = scale;
        
        // Flame core
        ctx.fillStyle = '#FF4444';
        ctx.fillRect(x + 1*s, y + 1*s, 10*s, 10*s);
        
        // Flame center
        ctx.fillStyle = '#FFAA00';
        ctx.fillRect(x + 2*s, y + 2*s, 8*s, 8*s);
        
        // Flame hot center
        ctx.fillStyle = '#FFFF44';
        ctx.fillRect(x + 3*s, y + 3*s, 6*s, 6*s);
        
        // Animated flicker
        if (frame < 10) {
          ctx.fillStyle = '#FFFFFF';
          ctx.fillRect(x + 5*s, y + 5*s, 2*s, 2*s);
          
          // Flame wisps
          ctx.fillStyle = '#FF6666';
          ctx.fillRect(x, y + 2*s, 2*s, 2*s);
          ctx.fillRect(x + 10*s, y + 8*s, 2*s, 2*s);
        }
      }
    });
  }
  
  // Create ladder sprites
  createLadderSprites() {
    this.sprites.set('ladder', {
      width: 16,
      height: 10, // Per segment
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        
        // Ladder rails
        ctx.fillStyle = '#FFFF00';
        ctx.fillRect(x, y, 3*s, 10*s);
        ctx.fillRect(x + 13*s, y, 3*s, 10*s);
        
        // Ladder rungs
        ctx.fillStyle = '#DDDD00';
        ctx.fillRect(x, y, 16*s, 2*s);
        ctx.fillRect(x, y + 8*s, 16*s, 2*s);
        
        // Rung shadows
        ctx.fillStyle = '#BBBB00';
        ctx.fillRect(x, y + 1*s, 16*s, 1*s);
        ctx.fillRect(x, y + 9*s, 16*s, 1*s);
      }
    });
    
    this.sprites.set('ladder_broken', {
      width: 16,
      height: 10,
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        
        // Broken ladder rails
        ctx.fillStyle = '#CCCC00';
        ctx.fillRect(x, y, 3*s, 10*s);
        ctx.fillRect(x + 13*s, y, 3*s, 10*s);
        
        // Some missing rungs
        ctx.fillStyle = '#AAAA00';
        if (Math.random() > 0.3) {
          ctx.fillRect(x, y, 16*s, 2*s);
        }
        if (Math.random() > 0.3) {
          ctx.fillRect(x, y + 8*s, 16*s, 2*s);
        }
      }
    });
  }
  
  // Create girder sprites
  createGirderSprites() {
    this.sprites.set('girder', {
      width: 35, // Segment width
      height: 16,
      draw: (ctx, x, y, scale = 1) => {
        const s = scale;
        
        // Main girder body
        ctx.fillStyle = '#FF6B35';
        ctx.fillRect(x, y, 35*s, 16*s);
        
        // Girder shadow
        ctx.fillStyle = '#CC4A00';
        ctx.fillRect(x, y + 13*s, 35*s, 3*s);
        
        // Rivets
        ctx.fillStyle = '#AA3300';
        ctx.fillRect(x + 5*s, y + 3*s, 4*s, 4*s);
        ctx.fillRect(x + 5*s, y + 9*s, 4*s, 4*s);
        ctx.fillRect(x + 26*s, y + 3*s, 4*s, 4*s);
        ctx.fillRect(x + 26*s, y + 9*s, 4*s, 4*s);
        
        // Rivet highlights
        ctx.fillStyle = '#DD5522';
        ctx.fillRect(x + 5*s, y + 3*s, 2*s, 2*s);
        ctx.fillRect(x + 5*s, y + 9*s, 2*s, 2*s);
        ctx.fillRect(x + 26*s, y + 3*s, 2*s, 2*s);
        ctx.fillRect(x + 26*s, y + 9*s, 2*s, 2*s);
      }
    });
  }
  
  // Create oil drum sprites
  createOilDrumSprites() {
    this.sprites.set('oil_drum', {
      width: 24,
      height: 24,
      draw: (ctx, x, y, scale = 1, fireFrame = 0) => {
        const s = scale;
        
        // Drum body
        ctx.fillStyle = '#333333';
        ctx.fillRect(x, y, 24*s, 24*s);
        
        // Drum bands
        ctx.fillStyle = '#555555';
        ctx.fillRect(x, y + 5*s, 24*s, 3*s);
        ctx.fillRect(x, y + 15*s, 24*s, 3*s);
        
        // Drum highlight
        ctx.fillStyle = '#666666';
        ctx.fillRect(x + 2*s, y + 2*s, 20*s, 3*s);
        
        // Animated fire on top
        if (fireFrame < 15) {
          ctx.fillStyle = '#FF4444';
          ctx.fillRect(x + 3*s, y - 8*s, 18*s, 6*s);
          ctx.fillStyle = '#FFAA00';
          ctx.fillRect(x + 6*s, y - 5*s, 12*s, 3*s);
          ctx.fillStyle = '#FFFF44';
          ctx.fillRect(x + 8*s, y - 3*s, 8*s, 2*s);
        }
      }
    });
  }
  
  // Draw sprite with optional animation frame
  drawSprite(spriteName, x, y, scale = 1, animationFrame = 0, ...args) {
    const sprite = this.sprites.get(spriteName);
    if (sprite) {
      sprite.draw(this.ctx, x, y, scale, animationFrame, ...args);
      return true;
    }
    return false;
  }
  
  // Get sprite dimensions
  getSpriteDimensions(spriteName) {
    const sprite = this.sprites.get(spriteName);
    return sprite ? { width: sprite.width, height: sprite.height } : null;
  }
  
  // Professional animation helper
  getAnimationFrame(animationName, frameCount, speed = 1) {
    return Math.floor(frameCount * speed) % this.getAnimationLength(animationName);
  }
  
  getAnimationLength(animationName) {
    const animationLengths = {
      walk: 4,
      climb: 2,
      beating: 6,
      throwing: 3,
      help: 2,
      fireball: 20,
      sparkle: 60
    };
    return animationLengths[animationName] || 1;
  }
}