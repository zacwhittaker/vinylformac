# Creating a Vinyl turntable theme

Read `AGENTS.md`, `PROGRESS.md` and `PROJECT_INDEX.md` first. Midnight is the approved default and the physical base for every **new** theme. A theme changes materials only. It must not rebuild or copy the turntable, move parts, change animation or replace playback code.

## Architecture and boundaries

- `Vinyl/Themes/TurntableMaterials.swift`: surface recipes and their static finish renderer; no geometry or transport parameters.
- `Vinyl/Themes/MidnightMaterials.swift`: the approved baseline. Inherit a value from `make()`; leave this definition unchanged unless the user requests a Midnight material change.
- `Vinyl/Themes/TurntableTheme.swift`: catalogue, stable IDs, settings choices and compatibility resolution. Add new themes to `TurntableThemeCatalog.all`.
- `ModernWallpaperView` → `SharedTurntableScene` → the existing `MidnightDeck`, chassis shapes, display and `MidnightTonearm`: the single physical base. Historical `Midnight` helper names denote shared components, not permission to fork them.
- `VinylTheme` / `ThemeDesign` retain old themes for saved-preference compatibility. **Do not add new enum cases or extend that geometry switch.** New themes enter through the material catalogue and always use `.midnight` as their renderer identity.

The physical base retains the 1920×1000 design canvas, responsive camera, common projection, enclosure contour, rigid tonearm, record/native artwork host, feet, display, shadows, lights and control placement. Coordinates are screen-Y-down. Material definitions cannot provide paths, sizes, offsets, view builders, state, timers or playback closures. Existing album-reactive LEDs and their timing remain shared.

## Add a theme

1. Create `Vinyl/Themes/YourTheme.swift`. Copy the example below and change only selected materials. Use a stable unique lowercase ID; do not rename an ID after shipping it.
2. Append `YourTheme.definition` to `TurntableThemeCatalog.all`, keeping Midnight first. Registration automatically populates Appearance → Turntable and the per-display theme picker. No settings-view or physical-renderer edits are needed.
3. Add any static texture assets to `Vinyl/Assets.xcassets` with attribution in `ASSET_LICENSES.md`. The synchronized Xcode source group includes new Swift files automatically.
4. Build and verify as below. Update the handoff/index for the new theme. Commit/push/release only when requested.

```swift
import SwiftUI

enum YourTheme {
    static let definition: TurntableTheme = {
        var materials = MidnightMaterials.make()
        materials.chassisTop.colors = [
            Color(red:0.16,green:0.18,blue:0.20),
            Color(red:0.09,green:0.11,blue:0.13),
            Color(red:0.05,green:0.06,blue:0.08)
        ]
        materials.chassisFront.colors = [
            Color(red:0.14,green:0.16,blue:0.18),
            Color(red:0.08,green:0.10,blue:0.12),
            Color(red:0.045,green:0.055,blue:0.07)
        ]
        // Keep the baseline microcement texture and tint its finished RGB.
        materials.background.tint = Color(red:0.85,green:0.92,blue:1)
        return TurntableTheme(id:"your-theme",name:"Your Theme",materials:materials)
    }()
}
```

Register with `static let all: [TurntableTheme] = [midnight, YourTheme.definition]`. This example is illustrative; it does not ship an additional design or imply approval of those colours.

These are compiled theme definitions: adding a definition requires a normal app build, but requires no model, geometry, animation or integration rebuild work. This is not a runtime theme-file importer or PBR/mesh pipeline.

## Material slots

| Slot | What it changes |
| --- | --- |
| `background` | Studio surface beneath the shared light/shadow composition. |
| `chassisCore`, `chassisTop`, `chassisFront` | Continuous enclosure pigments and finishes. Match adjacent surfaces. |
| `platterEdge`, `platterRim`, `platterMat` | Machined outer edge, raised rim and mat. |
| `record`, `spindle` | Static vinyl surface and centre pin; never the album artwork. |
| `feet` | Rubber body gradient/finish, with shared compression highlights and grain. |
| `displayHousing` | Sidewalls, underside, bezel and glass pigments; finish covers the housing canvas only. |
| `tonearm` | Metal tint and cartridge/headshell pigments, with physical light response computed by the rotating model. |
| `powerHousing`, `startStop`, `speedSlot`, `speedSwitch` | Existing control surfaces; red power lens stays shared. |
| `fasciaInk`, `displayInk` | Primary printed/text colour, preserving typography and secondary text hierarchy. |
| `backgroundWarmLight`, `topWarmLight`, `topCoolLight`, `frontWarmLight`, `chamferWarmLight`, `glassReflection` | Material reflection colours at the existing direction, placement and strength. |

A `TurntableSurface` has `colors`, `finish`, and `tint`. Gradient slots consume the array in the renderer's established direction; single-colour slots (background, mat, record) consume the first colour. Keep arrays nonempty. `tint` multiplies the finished surface RGB while preserving alpha. Midnight uses white, an identity operation. Never tint the whole scene or native artwork.

Available finishes:

- `.smooth`: colour/gradient with no extra procedural finish.
- `.brushedMetal(seed:17)` for top, `seed:31` for front: existing direct-colour modulation and curved fascia mapping. Preserve these seeds when inheriting brushing.
- `.component(kind:0)` satin, `kind:1` rubber, `kind:2` machined: existing component finish.
- `.microcement`: the approved warm charcoal procedural base. This shader generates its own pigment; use `tint` to recolour the finished texture, or choose `.smooth` for a completely custom base colour.
- `.vinyl`: existing concentric-groove material with generated black pigment. Use `tint` to modify its finished reflection; use another finish for a different base. Keep all groove/record geometry intact.
- `.image(name:opacity:)`: static asset over the base, aspect-filled within the supplied surface canvas and masked by the receiving shape's alpha. It is not UV-unwrapped mesh mapping. Use on suitable flat surfaces and inspect crops/scale; do not put it over the tonearm assembly, glass text/artwork or a rounded fascia requiring curved grain. A new physically mapped finish belongs in the shared finish library, never in a copied model.

For the tonearm use `metalTint` (RGB multipliers, white = `SIMD3(repeating:1)`), cartridge/headshell colours, and `.component(kind:0)` or `.smooth`. Its cylindrical highlights must continue to follow the rotating tube. Do not apply a whole-arm tint that recolours the album LEDs or receiver shadows.

Light gradients, occlusion, groove highlights, foot microtexture and LED choreography stay part of the shared rendering recipe. A material-only theme is not an authorization to change them. If the requested finish needs new physical shading, extend the common material implementation with a neutral default and verify Midnight parity.

## Persistence and live switching

`AppearanceConfiguration.materialThemeID` is optional and Codable. Old schema-v2 configurations/presets decode with nil, retaining their original `VinylTheme`; nil plus `.midnight` resolves to Midnight. An unknown material ID displays Midnight without erasing the stored ID. New choices set the catalogue ID plus the compatibility `.midnight` enum value; legacy choices clear the catalogue ID. Use `themeChoiceID` when selecting themes programmatically.

Global/shared/per-display selection and presets retain material IDs. Per-display exposure remains independent. Appearance-only changes publish into existing wallpaper presentations, preserving the shared arm state and native layers between material themes. Window-policy, animation configuration, display enablement and exposure changes retain their existing rebuild behavior. Switching to a legacy design necessarily changes the renderer branch.

## Verification

Build `Vinyl.xcodeproj`, scheme `Vinyl`, Debug with unique temporary derived data and `CODE_SIGNING_ALLOWED=NO`. The Metal toolchain/compiler plugins may require approved access outside the sandbox; do not change signing, entitlements or source to work around that restriction.

```sh
xcodebuild -quiet -project Vinyl.xcodeproj -scheme Vinyl -configuration Debug \
  -derivedDataPath /tmp/vinyl-your-theme-dd CODE_SIGNING_ALLOWED=NO build
swiftc -D DEBUG Vinyl/Models/AppConfiguration.swift Vinyl/Themes/*.swift \
  Tests/ThemeConfigurationSmoke.swift -o /tmp/vinyl-theme-config
/tmp/vinyl-theme-config
swiftc -D DEBUG Vinyl/Models/PlayingItem.swift \
  Vinyl/Themes/TurntableMaterials.swift Vinyl/Themes/MidnightMaterials.swift \
  Vinyl/Wallpaper/MidnightTonearm.swift Tests/TonearmGeometrySmoke.swift \
  -o /tmp/vinyl-theme-geometry
/tmp/vinyl-theme-geometry
git diff --check
```

Render the new theme with `VINYL_SNAPSHOT_THEME=your-theme` and the Debug executable's `--snapshot /tmp/your-theme.png`. The existing width/height/scale/exposure/idle/paused/progress overrides still work. Compare normal and +0.40 exposure at 2×, plus a smaller size; inspect actual PNGs. Check portrait/ultrawide when changing mapped materials. Keep Midnight unchanged and compare matching baseline snapshots whenever the shared finish library changes.

Compile `TonearmAnimationSmoke.swift` in place of `TonearmGeometrySmoke.swift` above and run in an awake graphical session when shared rendering changes. It covers start, pause, parking and inner-groove resume. Set `VINYL_TONEARM_SNAPSHOT_PREFIX=/tmp/your-theme-arm` for its default-material pose captures. `ThemeMaterialRenderingSmoke.swift` checks a material-only recolour and switching materials on a retained playing arm.

Headless ImageRenderer snapshots show the known yellow/red native-artwork placeholder and cannot prove live artwork/progress correctness. Before replacing the live development app, stop the old run **through Xcode**, Build/Run, and verify a single executable. Review theme switching while playing and paused, preset persistence, and independent displays. Do not change the user's saved theme just to capture a proof image. Separate build, snapshot, live launch, physical-display and user-approval statuses in the handoff.
