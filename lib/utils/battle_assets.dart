// lib/utils/battle_assets.dart
//
// Central registry for all battle-related image asset paths.
// Used across battle_entry_screen, battle_screen, victory_screen,
// defeat_screen, and class_battle_screen.

class BattleAssets {
  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const String battleBg  = 'assets/battle/battle_bg.png';
  static const String victoryBg = 'assets/battle/victory_bg.png';
  static const String defeatBg  = 'assets/battle/defeat_bg.png';

  // ── Enemy characters (by unit tier) ──────────────────────────────────────
  static const String enemyFogSprites = 'assets/battle/enemy_fog_sprites.png';
  static const String enemyWraith     = 'assets/battle/enemy_wraith.png';
  static const String enemyFogKnight  = 'assets/battle/enemy_fog_knight.png';
  static const String enemyArchon     = 'assets/battle/enemy_archon.png';

  /// Return the correct enemy image path for the current unit number.
  static String enemyImageForUnit(int unit) {
    if (unit <= 8)  return enemyFogSprites;
    if (unit <= 18) return enemyWraith;
    if (unit <= 25) return enemyFogKnight;
    return enemyArchon;
  }

  /// Return the correct enemy image for class-battle difficulty string.
  static String enemyImageForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'easy':       return enemyFogSprites;
      case 'hard':       return enemyFogKnight;
      case 'legendary':  return enemyArchon;
      default:           return enemyWraith; // 'standard'
    }
  }

  // ── Attack effects ────────────────────────────────────────────────────────
  /// Golden light-beam — shown when Lumen (the student) lands a hit.
  static const String attackLumen = 'assets/battle/attack_lumen.png';

  /// Dark purple energy beam — shown when the enemy attacks Lumen.
  static const String attackEnemy = 'assets/battle/attack_enemy.png';
}
