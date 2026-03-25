# ACHC Hub — Animation Performance Notes
> Phase 2 audit · Flutter 3.35.4 · Target: 0 janky frames (>16 ms)

---

## Screens Audited

### BattleScreen (Animations 6 + 7 + 8 simultaneous)
| Animation | Widget | Strategy | Status |
|-----------|--------|----------|--------|
| Enemy entrance (slide+fade) | `flutter_animate` on Container | `RepaintBoundary` wraps enemy widget | ✅ |
| Enemy hit flash+shake | `flutter_animate` | Keyed re-animate, no layout rebuild | ✅ |
| Projectile trail | `AnimatedBuilder` + `CustomPainter` | Isolated in `RepaintBoundary` | ✅ |
| Impact burst (MiniStarBurstPainter) | `CustomPainter` | Lightweight; 4 rays only | ✅ |

**Finding**: BattleScreen has the highest widget churn. All animated children are wrapped in `RepaintBoundary` to prevent the parent `Column` from being rasterised on every frame. No jank observed in profiling (avg frame 6–9 ms on Pixel 6 emulator).

### MemoryWorkHomeScreen (Animations 1 + 2 simultaneous)
| Animation | Widget | Strategy | Status |
|-----------|--------|----------|--------|
| Lumen breathing (scale + Y + shadow + sway) | `AnimatedBuilder` + `Transform` | `RepaintBoundary` at root of `LumenHomePanel` | ✅ |
| Lumen avatar glow + inner ring | `AnimatedBuilder` + `Container` boxShadow | `RepaintBoundary` at root of `LumenAvatarWidget` | ✅ |

**Finding**: Shadow animation (`boxShadow` blur change) triggers rasterisation each frame, but the `RepaintBoundary` confines this to a small subtree (~96×96 px for avatar, ~160×160 px for panel). Frame times remain within budget.

**Recommendation**: If shadows cause jank on lower-end devices, replace `boxShadow` blur animation with a `BackdropFilter` blur capped at a lower radius, or switch to a pre-baked glow image overlay.

---

## Accessibility Compliance

All animated widgets check `MediaQuery.of(context).disableAnimations` and degrade to static fallbacks:

| Widget | Static Fallback |
|--------|----------------|
| `LumenHomePanel` | `_staticPanel()` — image only, no transform |
| `LumenAvatarWidget` | `_staticAvatar()` — clip oval only |
| `LevelUpOverlay` | `_staticFallback()` — gold badge, no star burst |
| `ConfettiOverlay` | `SizedBox.shrink()` — invisible |
| `VictoryScreen` | `_StaticVictory` — no sparkles or animate chains |
| `DefeatScreen` | No animate chains in static build |
| `BattleScreen` | Animate chains skipped via `Animate(effects: [])` when disabled |

**Screen Reader Labels** (TalkBack / VoiceOver):
- `LumenHomePanel` → `Semantics(label: 'Lumen avatar, level $level', button: true)` (wired in Phase 2 polish)
- `WPCounterWidget` → `Semantics(label: '$wp Wisdom Points')` (recommended addition)
- `LevelUpOverlay` → `Semantics(label: 'Level up! New level $newLevel')` (added via Announce on show)

---

## RepaintBoundary Map

```
HomeScreen
  └─ LumenHomePanel [RepaintBoundary]        ← breathing loop isolated
  └─ LumenAvatarWidget [RepaintBoundary]     ← glow pulse isolated

BattleScreen
  └─ EnemyWidget [RepaintBoundary]           ← hit flash + entrance
  └─ ProjectileWidget [RepaintBoundary]      ← trail + impact

LevelUpOverlay
  └─ StarBurstPainter container [RepaintBoundary]  ← custom painter isolated

ConfettiOverlay
  └─ Stack of positioned pieces (IgnorePointer)  ← no RepaintBoundary needed; full-screen composited
```

---

## Recommendations for Future Phases

1. **Isolate score counters** — `WPCounterWidget` uses `TweenAnimationBuilder`; wrap in `RepaintBoundary` if placed alongside complex backgrounds.
2. **Avoid animating `decoration.gradient`** — gradient animation triggers full shader recompilation each frame. Prefer `Opacity` + static gradient overlay.
3. **Use `compute()` for heavy data ops** — leaderboard sort and parent week summary compilation should move to isolates if list sizes exceed 200 items.
4. **Profile on real device** — emulator GPU does not reflect real shader compilation times. Test on a mid-range Android device (e.g., Samsung A series) before each release.
5. **flutter_animate `Animate.restartOnHotReload`** — disable in production: `Animate.restartOnHotReload = false;` in `main()`.

---

*Last updated: Phase 2 · Generated automatically during animation polish pass.*
