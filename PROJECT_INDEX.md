# VinylForMac — project index

Indexed 2026-09-07 against baseline HEAD `53534607af2846fcdd05339e94f7002c1ec39a89`. Read AGENTS.md and PROGRESS.md first. This is a navigation map, not a claim that every feature has been tested. Current source wins over stale prose.

## Continuity package

| File | Purpose |
| --- | --- |
| AGENTS.md | Durable theme, scope, architecture and task read/update instructions. |
| PROGRESS.md | Current state, acceptance status, unresolved work, verification and per-task log. |
| PROJECT_INDEX.md | This source and artifact navigation map. |
| THEME_AUTHORING.md | Agent guide for new material-only themes, registration, compatibility and verification. |
| project-notes/CHAT_HISTORY.md | 150 retrieved turns from seven project chats, historical user/final-assistant text only. Read selectively; earlier plans are often superseded. |
| project-notes/TRACKED_FILES.tsv | Complete baseline Git index inventory: 9,623 paths with mode/blob ID/stage. 76 outside outputs; 9,547 generated/output entries. Does not include this newly created package. |

## Active flow

Spotify distributed notification / launch / wake / manual refresh → AppModel → serialized SpotifyBridge read → PlayingItem with monotonic sample → ArtworkWallpaperController → existing per-display presentation → ModernWallpaperView.

ModernWallpaperView → material catalogue → SharedTurntableScene (approved Midnight physical base) → chassis, platter/record, MidnightTonearm, embedded display. SpinningArtwork and PlaybackProgressBar use native Core Animation; other surfaces mostly use SwiftUI paths/Canvas/Metal. Appearance-only changes and routine playback changes update retained presentations. Window-policy/animation/exposure changes keep their rebuild path; display changes reconcile by display ID.

Midnight RecordView consumes `dominantArtworkColor` from `ArtworkAccent.swift`; its small sRGB sampler detects image-wide monochrome coverage before selecting a hue. RecordWaveAccents/RecordWavePath use concentric polar grooves despite the historical names. Record rim and groove bloom share the extracted artwork colour.

## Source ownership map

All paths below are relative to the repository root.

| File | Responsibility and edit guidance |
| --- | --- |
| Vinyl/VinylApp.swift | App entry, settings scene, menu bar, app commands, silent launch/accessory behavior, duplicate-instance handling. Snapshot invocation is Debug-only. |
| Vinyl/AppModel.swift | Main actor app state, Spotify refresh lifecycle, event/poll/sleep/wake coordination, wallpaper enablement, presets, login item. |
| Vinyl/Models/PlayingItem.swift | Source-neutral playback record, idle state, monotonic position, album identity. |
| Vinyl/Models/AppConfiguration.swift | Theme/material/background/layout/animation options, optional material catalogue ID, defaults, per-display configuration, presets, Codable persistence and appearance-only update comparison. |
| Vinyl/Themes/TurntableTheme.swift | Material-only theme catalogue, Midnight default/fallback, stable selection IDs and legacy compatibility. Add all new themes here. |
| Vinyl/Themes/TurntableMaterials.swift | Material slot schema, environment and per-surface finish application; no geometry or animation configuration. |
| Vinyl/Themes/MidnightMaterials.swift | Approved Midnight baseline pigments and finishes; new themes copy and override this value. |
| Vinyl/Models/VinylSetup.swift | Setup IDs/catalogue; available Turntable and coming-soon placeholders. Not the theme catalogue. |
| Vinyl/Models/DeviceInfo.swift | Device naming used in presentation/branding. |
| Vinyl/Spotify/SpotifyBridge.swift | Local player queries/commands and serialized script execution; retained legacy oEmbed artwork helper. |
| Vinyl/Spotify/SpotifyPlaybackEventMonitor.swift | Distributed Spotify notifications and 40 ms debounce. |
| Vinyl/Display/DisplayManager.swift | Display discovery, identifiers, pixel/frame/orientation details, display-identification state. |
| Vinyl/Animation/PlaybackAnimationCoordinator.swift | Visual playback transition states and cancellable convergence. |
| Vinyl/Wallpaper/ArtworkWallpaperController.swift | Per-display windows, sRGB, persistent presentation, occlusion/Low Power propagation, incremental display-ID reconciliation and synchronized replacement-window state. Inspect before changing window identity. |
| Vinyl/Wallpaper/ArtworkAccent.swift | Album-art sRGB sampling, image-wide monochrome classification and chromatic hue selection for shared Midnight lighting. |
| Vinyl/Wallpaper/ModernWallpaperView.swift | Active composition, SharedTurntableScene for all material themes, retained legacy ThemeDesign cases, aspect-ratio camera framing for the fixed physical canvas, shared chassis paths, material attachment, feet, underglow, controls, approved display geometry/UI, non-Midnight deck/panels. |
| Vinyl/Wallpaper/MidnightTonearm.swift | Arm geometry/pose, cancellable lift/travel/lower sequencing, seek-aware live tracking, configurable paused rest (10-second default), rigid bow, lowered-pose cradle alignment, receiver shadows and continuous cylinder lighting. |
| Vinyl/Wallpaper/VinylShaders.metal | Noise helpers, component finishes, microcement, vinyl/platter shaders, direct chassis material, historical exposure and film grain functions. Verify call sites: not every shader is active in Midnight. |
| Vinyl/Wallpaper/SpinningArtwork.swift | Native persistent artwork host/CALayer rotation and cache integration. |
| Vinyl/Wallpaper/CachedArtwork.swift | Shared decoded artwork cache, concurrent fetch coalescing, retained displayed bitmap. |
| Vinyl/Wallpaper/PlaybackProgressBar.swift | Native progress-layer animation from monotonic position to track end, optionally gated by Midnight's physical stylus-contact sequence. |
| Vinyl/Wallpaper/PlaybackTextSchedule.swift | Playback-second-aligned text ticks; hidden/paused and Low Power environment keys. |
| Vinyl/Wallpaper/WallpaperSnapshot.swift | Debug ImageRenderer harness and environment overrides; native-layer preview limitations. |
| Vinyl/Wallpaper/SmoothRecordRotation.swift | Legacy generic SwiftUI rotation wrapper; not the active native wallpaper artwork host. |
| Vinyl/Wallpaper/AlbumCanvasWallpaperView.swift | Large earlier tabletop/sleeve/turntable renderer, SceneLight and older surface helpers; not current Midnight entry. |
| Vinyl/Views/SettingsRootView.swift | Current native sidebar settings and preview; appearance, player, deck, light, background, display, motion/general sections. |
| Vinyl/Views/MenuBarContent.swift | Menu-bar access, playback/status/settings/preset/display controls. |
| Vinyl/Views/ContentView.swift | Earlier setup/content UI retained; current app scene opens SettingsRootView. |

## Geometry anchors to preserve

- `SharedTurntableScene.designSize`: 1920×1000 logical points.
- `PhysicalPlaneProjection`: shared 2.8° x-axis rotation, perspective 0.16 for top and plinth.
- `ChassisOuterContour` / `ChassisDiagnosticBlueShape` / `MidnightTopShape`: master enclosure and derived continuous surfaces. Existing diagnostic naming does not mean the app is in diagnostic color mode.
- `MidnightPlinth`: controls/branding centered within y=.785... .890, local content sizing. Keep straight central fascia and flush curved joins.
- `DisplayHousingGeometry`: approved 910×250 rectangular face, -20/930 outer triangle tips at y=162, underside to y=280; rounded bezel is a separate shallow surface.
- `MidnightTonearmGeometry`: same effective length and rigid shape across progress/parking; groove annulus radius factors .88 to .46; needle contacts record, elevated assembly above it.
- Latest material knobs and approval history are in PROGRESS.md. Avoid line-number-based patches without re-reading the symbols.

## Tests

Standalone smoke executables, not a configured XCTest target. Compile only relevant production dependencies with each test's `@main`; do not link VinylApp's `@main`. UI/animation tests need an awake graphical session; live Spotify test needs Spotify/Automation; oEmbed test needs network.

| Test file | Coverage |
| --- | --- |
| Tests/ThemeConfigurationSmoke.swift | Old-schema/preset persistence, material defaults and unknown-ID fallback, global/per-display selection and retained-window update policy. Dependencies: AppConfiguration and Themes/*.swift. |
| Tests/ThemeMaterialRenderingSmoke.swift | Material pigment/tint and silhouette alpha; retained playing arm across material changes. Dependencies: PlayingItem, MidnightTonearm, TurntableMaterials and MidnightMaterials; DEBUG/GUI. |
| Tests/PlaybackClockSmoke.swift | Monotonic elapsed time, pause, seek and duration bounds. Dependency: Models/PlayingItem.swift. |
| Tests/PlaybackScheduleSmoke.swift | Next-second boundary, paused/hidden no repeated ticks. Dependencies: PlayingItem and PlaybackTextSchedule. |
| Tests/ArtworkCacheSmoke.swift | URLProtocol stub; 20 concurrent consumers, 100 reuses, one request/bitmap. Dependency: CachedArtwork. |
| Tests/ArtworkAccentSmoke.swift | Gray, white-with-tinted-detail and near-black/cyan-cast covers remain neutral white while broad teal artwork retains its hue. Dependency: ArtworkAccent. |
| Tests/PlaybackRenderingSmoke.swift | Native host persists across pause/resume, compositor angles advance, measured display-link cadence. Dependencies: SpinningArtwork, CachedArtwork, PlaybackTextSchedule, PlayingItem. |
| Tests/PlaybackProgressSmoke.swift | Progress fill/dot colour, endpoints, paired animation timing, seek, resize, suspension, pause and idle reset. Dependencies: PlaybackProgressBar, PlayingItem. |
| Tests/SpotifyPlaybackEventMonitorSmoke.swift | Synthetic notification/debounce path. Dependency: SpotifyPlaybackEventMonitor. |
| Tests/SpotifyArtworkLookupSmoke.swift | Spotify oEmbed helper returns upgraded artwork. Dependencies: SpotifyBridge, PlayingItem; network. |
| Tests/SpotifyCurrentPlaybackSmoke.swift | Read-only direct discovery; skips when Spotify absent. Dependencies: SpotifyBridge, PlayingItem; reports stopped/unavailable distinctly. |
| Tests/StartupPlaybackGateSmoke.swift | Fresh-process transport gating: unavailable and paused reads stay idle until playing is explicitly confirmed, then normal pauses pass through. Dependency: PlayingItem. |
| Tests/TonearmGeometrySmoke.swift | Inward tracking, rigid length/shape, clearance, lowered sampled-wire/cradle centering across sizes and counterweight highlight continuity. Dependencies: MidnightTonearm, PlayingItem, Themes/TurntableMaterials and Themes/MidnightMaterials. |
| Tests/TonearmAnimationSmoke.swift | Rendered start/pause/10-second parking/inner-groove resume, rigid attachment, constant cue lift, contact gating and actual lowered cradle centering. Dependencies: MidnightTonearm, PlayingItem, Themes/TurntableMaterials and Themes/MidnightMaterials; compile with DEBUG; requires GUI. |
| Tests/TonearmRestoreSmoke.swift | Recreated playing/paused views restore directly to tracking/pedestal without emitting physical transition phases. Dependencies: MidnightTonearm, PlayingItem, Themes/TurntableMaterials and Themes/MidnightMaterials; compile with DEBUG; requires GUI. |

Minimal clock example (output under a task-specific temporary directory):

```sh
swiftc Vinyl/Models/PlayingItem.swift Tests/PlaybackClockSmoke.swift -o /absolute/temporary/directory/playback-clock
/absolute/temporary/directory/playback-clock
```

Build and snapshot workflow, plus known visual limitations, are in PROGRESS.md. Historical pass reports are not newly rerun tests.

## Project, distribution and website files

| Path | Purpose |
| --- | --- |
| Vinyl.xcodeproj/project.pbxproj | Synchronized source groups, app target, build/signing/deployment/version settings. No package manifest or CI workflow was found in the baseline tracked source set. |
| Vinyl.xcodeproj/project.xcworkspace/contents.xcworkspacedata | Xcode workspace reference. |
| Vinyl/Info.plist | Bundle metadata, Automation usage description, app category, high-resolution and local networking declaration. |
| Vinyl/Vinyl.entitlements | Sandbox, outgoing network, Spotify Apple Events/Automation. |
| Vinyl/PrivacyInfo.xcprivacy | Privacy manifest: no tracking/collection declarations. |
| Distribution/DeveloperIDExportOptions.plist | Manual Developer ID distribution export settings. Not proof of current release notarization. |
| README.md | Product/build overview; some legacy claims require reconciliation, listed in PROGRESS.md. |
| ASSET_LICENSES.md | CC0 provenance, provider links and download dates for bundled raster textures. |
| tunearm.md | Historical tonearm research/design plan (filename intentionally preserved). Later single-bow/user geometry decisions supersede earlier alternatives. |
| Design/AppIcon.svg | Editable vector icon source. |
| docs/index.html | Static marketing page, latest-release download link, site styling. |
| docs/privacy.html | Public privacy page; oEmbed description predates current live player-artwork flow. |
| docs/CNAME | Website hostname vinyl.shivs.me; no deployment performed in this task. |
| .gitignore | Ignores common build/user state folders but does not prevent existing tracked outputs/*-build caches. |

## Asset catalogue

`Vinyl/Assets.xcassets` includes root metadata, AccentColor, ten AppIcon PNG size variants and metadata. Textures: DustTexture, LeatherTexture, MetalTexture, RosewoodTexture/RosewoodRoughness, ScratchesTexture, WalnutTexture/WalnutRoughness. Each image set contains Contents.json and one JPEG. These support existing/legacy designs; current Midnight chassis/background use procedural shaders. No SmokedWalnutTexture remains in the source inventory; its earlier introduction was reverted.

## Generated outputs and reference material

`outputs/` is evidence/build output, not canonical editable application code. Never edit an old built application's copied Swift/module/cache files thinking they are sources.

- `outputs/texture-overhaul/`: this task's before/after, small-paused, corrected-bright and balanced-bright snapshots. Latest tuning: balanced-bright.png; earlier after.png was rejected.
- `outputs/angle-fix/`, `outputs/final-fix/`: older geometry review images.
- `outputs/background-microcement*.png`: pre-refinement background examples.
- `outputs/background-build/`, `feet-led-build/`, `materials-build/`, `reverted-materials-build/`: old app products, Xcode build/index/module/compilation caches and logs. Included in full inventory only; do not reuse as the latest app automatically.
- Other diagnostic PNGs directly in outputs are historical geometry iterations; approval chronology is in CHAT_HISTORY.
- The ChatGPT mirror has older `tonearm/`, `curved-arm/`, `single-bow/`, `raised-card/`, `refined-panel/`, `shared-perspective/` and `final-fix/` PNGs.
- Generated concept/swatches remain at `/Users/zac/.codex/generated_images/01a07d02-1eb9-72e3-96ee-19055fd345fc/`; these are design references, not extracted production textures.
- Historical `/tmp`, `/var/folders`, container and visualization paths in chats may be gone or machine-specific. Inspect before linking them as current deliverables.

Continuity references copied into `project-notes/references/`:

- `2026-09-07-original-player.png` — initial user reference.
- `2026-09-07-rejected-bright-stretched-grain.png` — user rejection: bright, liney, stretched base texture.
- `2026-09-07-approved-base-background-needs-work.png` — user approval of the darker base, with background/grain feedback.
- `generated-concept-not-production.png` — generated concept, not an app render.
- `generated-swatches-not-texture-maps.png` — generated material board, not production maps.

## Exact baseline source/configuration/asset file list

The following covers every tracked path outside outputs/ at the audit baseline (76 files). Use TRACKED_FILES.tsv for all 9,547 output/build paths and Git blob identities.

- `.gitignore`
- `ASSET_LICENSES.md`
- `Design/AppIcon.svg`
- `Distribution/DeveloperIDExportOptions.plist`
- `README.md`
- `Tests/ArtworkCacheSmoke.swift`
- `Tests/PlaybackClockSmoke.swift`
- `Tests/PlaybackRenderingSmoke.swift`
- `Tests/PlaybackScheduleSmoke.swift`
- `Tests/SpotifyArtworkLookupSmoke.swift`
- `Tests/SpotifyCurrentPlaybackSmoke.swift`
- `Tests/SpotifyPlaybackEventMonitorSmoke.swift`
- `Tests/TonearmAnimationSmoke.swift`
- `Tests/TonearmGeometrySmoke.swift`
- `Vinyl.xcodeproj/project.pbxproj`
- `Vinyl.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- `Vinyl/Animation/PlaybackAnimationCoordinator.swift`
- `Vinyl/AppModel.swift`
- `Vinyl/Assets.xcassets/AccentColor.colorset/Contents.json`
- `Vinyl/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `Vinyl/Assets.xcassets/AppIcon.appiconset/icon_128x128.png`
- `Vinyl/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png`
- `Vinyl/Assets.xcassets/AppIcon.appiconset/icon_16x16.png`
- `Vinyl/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png`
- `Vinyl/Assets.xcassets/AppIcon.appiconset/icon_256x256.png`
- `Vinyl/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png`
- `Vinyl/Assets.xcassets/AppIcon.appiconset/icon_32x32.png`
- `Vinyl/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png`
- `Vinyl/Assets.xcassets/AppIcon.appiconset/icon_512x512.png`
- `Vinyl/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png`
- `Vinyl/Assets.xcassets/Contents.json`
- `Vinyl/Assets.xcassets/DustTexture.imageset/Contents.json`
- `Vinyl/Assets.xcassets/DustTexture.imageset/surface_imperfections015_1k.jpg`
- `Vinyl/Assets.xcassets/LeatherTexture.imageset/Contents.json`
- `Vinyl/Assets.xcassets/LeatherTexture.imageset/leather026_color_1k.jpg`
- `Vinyl/Assets.xcassets/MetalTexture.imageset/Contents.json`
- `Vinyl/Assets.xcassets/MetalTexture.imageset/metal012_color_1k.jpg`
- `Vinyl/Assets.xcassets/RosewoodRoughness.imageset/Contents.json`
- `Vinyl/Assets.xcassets/RosewoodRoughness.imageset/rosewood_veneer1_rough_2k.jpg`
- `Vinyl/Assets.xcassets/RosewoodTexture.imageset/Contents.json`
- `Vinyl/Assets.xcassets/RosewoodTexture.imageset/rosewood_veneer1_diff_2k.jpg`
- `Vinyl/Assets.xcassets/ScratchesTexture.imageset/Contents.json`
- `Vinyl/Assets.xcassets/ScratchesTexture.imageset/scratches005_1k.jpg`
- `Vinyl/Assets.xcassets/WalnutRoughness.imageset/Contents.json`
- `Vinyl/Assets.xcassets/WalnutRoughness.imageset/Wood067_2K-JPG_Roughness.jpg`
- `Vinyl/Assets.xcassets/WalnutTexture.imageset/Contents.json`
- `Vinyl/Assets.xcassets/WalnutTexture.imageset/Wood067_2K-JPG_Color.jpg`
- `Vinyl/Display/DisplayManager.swift`
- `Vinyl/Info.plist`
- `Vinyl/Models/AppConfiguration.swift`
- `Vinyl/Models/DeviceInfo.swift`
- `Vinyl/Models/PlayingItem.swift`
- `Vinyl/Models/VinylSetup.swift`
- `Vinyl/PrivacyInfo.xcprivacy`
- `Vinyl/Spotify/SpotifyBridge.swift`
- `Vinyl/Spotify/SpotifyPlaybackEventMonitor.swift`
- `Vinyl/Views/ContentView.swift`
- `Vinyl/Views/MenuBarContent.swift`
- `Vinyl/Views/SettingsRootView.swift`
- `Vinyl/Vinyl.entitlements`
- `Vinyl/VinylApp.swift`
- `Vinyl/Wallpaper/AlbumCanvasWallpaperView.swift`
- `Vinyl/Wallpaper/ArtworkWallpaperController.swift`
- `Vinyl/Wallpaper/CachedArtwork.swift`
- `Vinyl/Wallpaper/MidnightTonearm.swift`
- `Vinyl/Wallpaper/ModernWallpaperView.swift`
- `Vinyl/Wallpaper/PlaybackProgressBar.swift`
- `Vinyl/Wallpaper/PlaybackTextSchedule.swift`
- `Vinyl/Wallpaper/SmoothRecordRotation.swift`
- `Vinyl/Wallpaper/SpinningArtwork.swift`
- `Vinyl/Wallpaper/VinylShaders.metal`
- `Vinyl/Wallpaper/WallpaperSnapshot.swift`
- `docs/CNAME`
- `docs/index.html`
- `docs/privacy.html`
- `tunearm.md`
