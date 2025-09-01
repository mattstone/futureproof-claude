# 🎮 Grid-Based Donkey Kong Level Extractor

## Overview
This tool systematically extracts pixel-perfect coordinates from Donkey Kong level sprites using Grok's grid-based methodology. It converts visual elements into precise game coordinates for authentic recreation.

## Features
✅ **Grid-Based Analysis**: Uses 28x32 grid overlay for precise positioning  
✅ **Multi-Click Girders**: Click start→end points for accurate angled platforms  
✅ **Element Types**: Girders, ladders, barrels, conveyors, characters, etc.  
✅ **Color Palettes**: Pre-defined DK color schemes with visual picker  
✅ **Coordinate Conversion**: Automatic scaling to game canvas (900x700)  
✅ **JSON Export**: Structured output ready for code generation  
✅ **JavaScript Generation**: Ready-to-use game code  
✅ **Visual Feedback**: Real-time element overlay and numbering  
✅ **Error Handling**: ESC to cancel, status updates, validation  

## How to Use

### 1. Load Image
- Click "Choose File" and select `levels.png`
- Image should be 4 columns × 3 rows of Donkey Kong levels

### 2. Select Level  
- Choose from dropdown: "25M", "50M Original", etc.
- Tool automatically extracts the correct level section

### 3. Extract Elements
- **Girders**: Select "🏗️ Girder/Platform", click start point, then end point
- **Ladders**: Select "🪜 Ladder", single click to place
- **Characters**: Select character type, click position
- **Other Elements**: Single click to place

### 4. Generate Output
- Click "📄 Generate JSON" for structured data
- Copy the JavaScript code section for direct use in game

## Controls
- **ESC**: Cancel pending girder
- **Grid Toggle**: Show/hide coordinate grid
- **Color Picker**: Click palette colors to select
- **Element List**: View/delete placed elements

## Output Format

### JSON Structure
```json
{
  "level": {
    "label": "25M",
    "grid_dimensions": {"width": 28, "height": 32},
    "elements": [
      {
        "type": "girder",
        "grid_position": {"x": 2, "y": 8},
        "game_position": {"x": 35, "y": 590},
        "end_game_position": {"x": 861, "y": 579},
        "color": "#FF6B47",
        "length": 826,
        "orientation": "horizontal"
      }
    ],
    "estimated_resolution": {"width": 257, "height": 273}
  }
}
```

### Generated JavaScript
```javascript
// Generated from 25M
this.girders = [
  { startX: 35, startY: 590, endX: 861, endY: 579, color: '#FF6B47',
    segments: this.createGirderSegments(35, 590, 861, 579) }
];

this.ladders = [
  { x: 725, y: 536, width: 16, height: 31 }
];

// Character positions
this.mario.x = 56;
this.mario.y = 564;
```

## Element Types Supported
- 🏗️ **Girder/Platform**: Angled or horizontal platforms
- 🪜 **Ladder**: Vertical climbing connections  
- 🛢️ **Barrel**: Rolling obstacles
- 🔄 **Conveyor**: Moving platforms
- 📶 **Elevator**: Vertical moving platforms
- 🔩 **Rivet**: Level completion targets
- 🌀 **Spring**: Bouncing elements
- 🔥 **Fireball**: Moving hazards
- 🦍 **Donkey Kong**: Boss position
- 👨 **Mario**: Player start position
- 👩 **Pauline**: Rescue target
- 🔨 **Hammer**: Power-up items
- ⭐ **Bonus**: Point items

## Coordinate System
- **Grid**: (0,0) = bottom-left corner
- **Game Coordinates**: Scaled to standard Donkey Kong resolution
- **Canvas Coordinates**: Internal tool coordinates
- **Automatic Scaling**: Grid → Game → Canvas conversions

## Color Palettes
Pre-configured with authentic Donkey Kong colors:
- **Oil Barrel Palette**: Classic red/brown girders
- **Conveyor Palette**: Blue/cyan elements  
- **Elevator Palette**: Purple/magenta platforms
- **Rivets Palette**: Blue structural elements
- **Character Colors**: Player/enemy colors

## Tips for Accurate Extraction
1. **Zoom Browser**: Use browser zoom for pixel-perfect clicking
2. **Grid Reference**: Use grid lines for alignment
3. **Start with Girders**: Extract platforms first, then ladders
4. **Check Element List**: Verify coordinates before generating code
5. **Test Output**: Copy JavaScript directly into game engine

## Troubleshooting
- **"No image loaded"**: Select levels.png file first
- **Grid not visible**: Click "👁️ Toggle Grid" button
- **Girder stuck**: Press ESC to cancel, start again
- **Wrong coordinates**: Check grid dimensions (28x32 recommended)
- **Elements not showing**: Check if they're outside canvas area

## Integration with Game
The generated JavaScript code integrates directly with the HonkyPong game engine:

1. Copy the `girders` array to `createLevel()` method
2. Copy the `ladders` array  
3. Copy character positions
4. Test in browser at `/test-honky-pong`

## Technical Details
- **Canvas Scaling**: 2x zoom for better visibility
- **Grid System**: Configurable resolution grid
- **Coordinate Precision**: Pixel-perfect positioning
- **Error Recovery**: Robust cancellation and retry
- **Memory Efficient**: Minimal overhead, fast rendering

This tool eliminates guesswork and provides authentic, pixel-perfect Donkey Kong level recreation!