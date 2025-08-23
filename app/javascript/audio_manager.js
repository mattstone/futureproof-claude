// Professional Audio Manager for Honky Pong
export class AudioManager {
  constructor() {
    this.audioContext = null;
    this.masterGain = null;
    this.soundEnabled = true;
    this.volume = 0.7;
    this.sounds = new Map();
    this.initializeAudioContext();
  }
  
  async initializeAudioContext() {
    try {
      // Create AudioContext only after user interaction
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
      this.masterGain = this.audioContext.createGain();
      this.masterGain.connect(this.audioContext.destination);
      this.masterGain.gain.value = this.volume;
      
      // Generate procedural game sounds
      this.generateGameSounds();
      
      console.log("🔊 Professional Audio System Initialized");
    } catch (error) {
      console.warn("Audio context not supported:", error);
      this.soundEnabled = false;
    }
  }
  
  // Resume audio context after user interaction (required by browsers)
  async resumeAudioContext() {
    if (this.audioContext && this.audioContext.state === 'suspended') {
      await this.audioContext.resume();
    }
  }
  
  generateGameSounds() {
    if (!this.audioContext) return;
    
    // Professional procedurally generated sounds
    this.sounds.set('walk', this.createWalkSound());
    this.sounds.set('jump', this.createJumpSound());
    this.sounds.set('barrel', this.createBarrelSound());
    this.sounds.set('hammer', this.createHammerSound());
    this.sounds.set('death', this.createDeathSound());
    this.sounds.set('levelComplete', this.createLevelCompleteSound());
    this.sounds.set('climb', this.createClimbSound());
    this.sounds.set('coin', this.createCoinSound());
    this.sounds.set('powerUp', this.createPowerUpSound());
  }
  
  createOscillator(frequency, type = 'square', duration = 0.1) {
    const oscillator = this.audioContext.createOscillator();
    const gainNode = this.audioContext.createGain();
    
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, this.audioContext.currentTime);
    
    gainNode.gain.setValueAtTime(0.3, this.audioContext.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.01, this.audioContext.currentTime + duration);
    
    oscillator.connect(gainNode);
    gainNode.connect(this.masterGain);
    
    return { oscillator, gainNode };
  }
  
  createWalkSound() {
    return () => {
      if (!this.soundEnabled || !this.audioContext) return;
      
      const { oscillator } = this.createOscillator(200 + Math.random() * 100, 'sawtooth', 0.05);
      oscillator.start();
      oscillator.stop(this.audioContext.currentTime + 0.05);
    };
  }
  
  createJumpSound() {
    return () => {
      if (!this.soundEnabled || !this.audioContext) return;
      
      const { oscillator } = this.createOscillator(400, 'square', 0.2);
      oscillator.frequency.exponentialRampToValueAtTime(600, this.audioContext.currentTime + 0.1);
      oscillator.start();
      oscillator.stop(this.audioContext.currentTime + 0.2);
    };
  }
  
  createBarrelSound() {
    return () => {
      if (!this.soundEnabled || !this.audioContext) return;
      
      // Explosion-like sound
      const { oscillator } = this.createOscillator(100, 'sawtooth', 0.3);
      oscillator.frequency.exponentialRampToValueAtTime(50, this.audioContext.currentTime + 0.15);
      oscillator.start();
      oscillator.stop(this.audioContext.currentTime + 0.3);
      
      // Add noise component
      const noiseBuffer = this.createNoiseBuffer(0.1);
      const noiseSource = this.audioContext.createBufferSource();
      const noiseGain = this.audioContext.createGain();
      
      noiseSource.buffer = noiseBuffer;
      noiseGain.gain.setValueAtTime(0.2, this.audioContext.currentTime);
      noiseGain.gain.exponentialRampToValueAtTime(0.01, this.audioContext.currentTime + 0.1);
      
      noiseSource.connect(noiseGain);
      noiseGain.connect(this.masterGain);
      noiseSource.start();
    };
  }
  
  createHammerSound() {
    return () => {
      if (!this.soundEnabled || !this.audioContext) return;
      
      // Metallic clang sound
      const { oscillator: osc1 } = this.createOscillator(800, 'square', 0.15);
      const { oscillator: osc2 } = this.createOscillator(1200, 'triangle', 0.1);
      
      osc1.start();
      osc1.stop(this.audioContext.currentTime + 0.15);
      osc2.start(this.audioContext.currentTime + 0.05);
      osc2.stop(this.audioContext.currentTime + 0.15);
    };
  }
  
  createDeathSound() {
    return () => {
      if (!this.soundEnabled || !this.audioContext) return;
      
      // Descending death sound
      const { oscillator } = this.createOscillator(500, 'sawtooth', 0.8);
      oscillator.frequency.exponentialRampToValueAtTime(100, this.audioContext.currentTime + 0.6);
      oscillator.start();
      oscillator.stop(this.audioContext.currentTime + 0.8);
    };
  }
  
  createLevelCompleteSound() {
    return () => {
      if (!this.soundEnabled || !this.audioContext) return;
      
      // Victory fanfare
      const notes = [523, 659, 784, 1047]; // C, E, G, C
      notes.forEach((note, i) => {
        const { oscillator } = this.createOscillator(note, 'square', 0.2);
        oscillator.start(this.audioContext.currentTime + i * 0.15);
        oscillator.stop(this.audioContext.currentTime + i * 0.15 + 0.2);
      });
    };
  }
  
  createClimbSound() {
    return () => {
      if (!this.soundEnabled || !this.audioContext) return;
      
      const { oscillator } = this.createOscillator(300 + Math.random() * 50, 'triangle', 0.08);
      oscillator.start();
      oscillator.stop(this.audioContext.currentTime + 0.08);
    };
  }
  
  createCoinSound() {
    return () => {
      if (!this.soundEnabled || !this.audioContext) return;
      
      const { oscillator } = this.createOscillator(1000, 'sine', 0.1);
      oscillator.frequency.exponentialRampToValueAtTime(1500, this.audioContext.currentTime + 0.05);
      oscillator.start();
      oscillator.stop(this.audioContext.currentTime + 0.1);
    };
  }
  
  createPowerUpSound() {
    return () => {
      if (!this.soundEnabled || !this.audioContext) return;
      
      // Ascending power-up sound
      const frequencies = [262, 330, 392, 523]; // C, E, G, C
      frequencies.forEach((freq, i) => {
        const { oscillator } = this.createOscillator(freq, 'square', 0.1);
        oscillator.start(this.audioContext.currentTime + i * 0.05);
        oscillator.stop(this.audioContext.currentTime + i * 0.05 + 0.1);
      });
    };
  }
  
  createNoiseBuffer(duration) {
    const sampleRate = this.audioContext.sampleRate;
    const bufferSize = sampleRate * duration;
    const buffer = this.audioContext.createBuffer(1, bufferSize, sampleRate);
    const data = buffer.getChannelData(0);
    
    for (let i = 0; i < bufferSize; i++) {
      data[i] = Math.random() * 2 - 1;
    }
    
    return buffer;
  }
  
  // Play sound by name
  playSound(soundName) {
    if (!this.soundEnabled || !this.sounds.has(soundName)) {
      return;
    }
    
    // Resume audio context if needed
    this.resumeAudioContext();
    
    try {
      const soundFunction = this.sounds.get(soundName);
      soundFunction();
    } catch (error) {
      console.warn(`Failed to play sound ${soundName}:`, error);
    }
  }
  
  // Professional volume control
  setVolume(volume) {
    this.volume = Math.max(0, Math.min(1, volume));
    if (this.masterGain) {
      this.masterGain.gain.setValueAtTime(this.volume, this.audioContext.currentTime);
    }
  }
  
  // Mute/unmute
  toggleMute() {
    this.soundEnabled = !this.soundEnabled;
    return this.soundEnabled;
  }
  
  // Professional cleanup
  destroy() {
    if (this.audioContext) {
      this.audioContext.close();
    }
    this.sounds.clear();
  }
  
  // Professional audio settings
  getAudioSettings() {
    return {
      enabled: this.soundEnabled,
      volume: this.volume,
      contextState: this.audioContext ? this.audioContext.state : 'unavailable'
    };
  }
}