# CRITICAL DEVELOPMENT NOTES

## STYLING SEPARATION - DO NOT FORGET!

### ⚠️ NEVER MODIFY application.css FOR GAMES
- Games use separate `layouts/games.html.erb` layout
- Games include styles via `games.css` manifest ONLY
- Keep application and game styling completely separate
- Application styling goes in application.css
- Game styling goes in games.css manifest

### 🎮 Game CSS Architecture:
```
layouts/games.html.erb
├── stylesheet_link_tag "games"
└── games.css manifest
    ├── arcade.css
    ├── hemorrhoids.css  
    ├── lace_invaders.css
    ├── hackman.css
    └── defendher.css
```

### 🚫 What NOT to do:
- ❌ Add game CSS imports to application.css
- ❌ Mix application and game styles
- ❌ Break main site functionality with game changes

### ✅ What TO do:
- ✅ Add game CSS imports to games.css only
- ✅ Keep layouts completely separate
- ✅ Test sign_out and main site functionality after changes