# Game Controls & Systems

## Controls
- **Arrow Keys**: Move character
- **Z**: Light attack
- **X**: Heavy attack  
- **C**: Dash

## Combat System
- **Combos**: Chain Z and X attacks for special moves
  - Z, Z, X = Fire attack
  - X, X, Z = Shove attack
- **Dash**: Brief invulnerability during dash
- **Hit Reactions**: Enemies can knock you back and send you flying

## Health & Damage
- Take damage from enemy attacks
- Become briefly invulnerable after being hit
- Game over when health reaches 0

## Enemies
- Automatically spawn around the player
- Maximum of 8 enemies at once
- Each has unique attack patterns

## Core Architecture
- **State-based character controller** - Clean separation between idle, moving, attacking, dashing, and hit states
- **Combo system with queueing** - Smooth attack chaining with input buffering
- **Modular attack system** - Reusable projectile component for all attack types

## Key Design Choices
- **Timer-driven systems** - Combo windows, invulnerability, dash cooldowns
- **Event-driven damage** - Universal `get_hit()` interface for player/enemies
- **Group-based spawning** - Enemy manager tracks active enemies via groups

## Combat Flow
- **Hit reactions** - Knockback + flying state creates visceral feedback
- **Special moves** - Sequence-based combos reward player skill
- **Resource management** - Dash cooldown encourages strategic movement

## Technical Notes
- **Parent-scene projectiles** - Attacks spawn in parent scene to avoid transform issues
- **Sprite flipping** - Unified direction handling for character and attacks
- **Time manipulation** - Slow-motion death effect for dramatic impact
