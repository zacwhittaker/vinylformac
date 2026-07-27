# Implemented revision: annotated single bow (2026-09-06)

The user's red/green annotation supersedes the earlier S-arm proposal below.
The arm now uses one convex cubic curve, rotated rigidly about the bearing.
Playing sweeps down and left onto the vinyl; idle sweeps right into the cradle.
Both poses use identical local tube geometry and pivot-to-stylus length. The
headshell connection follows the terminal direction of the curve.

The tube descends gradually from the elevated bearing to the headshell. Removing
the previous late height drop prevents an extra visible bend near the cartridge.
The existing tall pedestal, surface-dependent shadows, cartridge thickness,
stylus contact and lifted idle/paused states remain in use. The cradle follows
the revised tube geometry automatically.

Validation: Debug build; geometry smoke checks for fixed length, inward tracking,
record contact, height, receiver shadows, parking clearance, and single-direction
curvature in both local and projected coordinates throughout the parking swing.
Rendered playing, idle, paused and inner-groove views at 2560 × 1440, plus portrait.

The references and earlier proposal below are retained as historical research;
the S-curve recommendation is no longer the implementation direction.

---

# Tonearm visual research and next-pass plan

Research date: 2026-09-06. Target reference screenshot: 2560 × 1440. This is a research and planning document; no Swift implementation is changed by this pass.

## References reviewed

The links below are the image references used for proportion, part separation, cueing height, and stylus contact. Several are retailer or enthusiast photographs, so they are useful for visual construction rather than exact product specification.

1. [Pro-Ject E1 BT tonearm close-up](https://www.av.com/Hi-Fi/Pro-Ject-E1-BT-Turntable-White-with-AT3600L-Cartridge/71R3) — slim tube, compact fixed headshell, clear tube-to-cartridge join, stylus close to the record.
2. [Pro-Ject E1 tonearm in playback](https://www.kbaudio.co.uk/products/pro-ject-e1-turntable) — arm tube stays almost parallel to the record; the cartridge is visibly lower than the tube.
3. [Pro-Ject E1 cartridge macro](https://www.smarthomesounds.co.uk/pro-ject-e1) — the cartridge has a distinct lower body and a small cantilever/needle rather than a single pointed block.
4. [Pro-Ject E1 mounting and cue lever](https://www.weybridge-audio.co.uk/products/pro-ject-e1-phono-turntable) — pivot mounting plate, screws, and cueing mechanism read as separate mechanical parts.
5. [Pro-Ject Pick it PRO cartridge](https://www.henleyaudio.co.uk/brands/pro-ject-audio-systems/product/pick-it-pro-moving-magnet-cartridges-styli/) — visible mounting hardware and material contrast between cartridge shell, arm, and stylus.
6. [Pro-Ject Debut Revolve cartridge view](https://www.henleyaudio.co.uk/brands/pro-ject-audio-systems/product/debut-revolve-turntables/) — thin arm tube, compact headshell, and soft specular light on the cylindrical tube.
7. [Technics SL-1200 pivot and counterweight](https://www.stereonet.com/forums/topic/512527-technics-sl-1200-project/page/4/) — curved S-arm, large stepped pivot housing, height ring, and counterweight dial on the rear axis.
8. [Rega Planar 1 tonearm](https://fjaudio.com/rega-planar-1/) — gently curved/offset arm, compact bearing area, and a cartridge that hangs below the arm line.
9. [Rega Planar 3 RS close-up](https://www.tomsguide.com/audio/rega-planar-3-rs-review) — cartridge wiring, mounting screws, and headshell underside remain visible during playback.
10. [Rega RB200 playback view](https://www.vinylengine.com/turntable_forum/viewtopic.php?t=126884) — curved arm silhouette and the needle contact point are visually separated from the record surface.
11. [SME 3009 counterweight setup](https://www.tforumhifi.com/t60536-braccio-sme-3009-aiuto-per-la-regolazione) — counterweight is a threaded cylindrical component with a collar and adjustment mass, not a rounded rectangle.
12. [Kuzma Stogi S brass counterweight](https://www.kuzma.si/stogi-s.html) — pivot, tube, shaft, and weight have distinct material values and visible mechanical interfaces.
13. [SME S-2 headshell on vinyl](https://vinylengine.com/turntable_forum/gallery/image/17706/medium) — bayonet mount, finger lift, cartridge body, cantilever, and stylus form a readable descending chain.
14. [Stylus and groove macro](https://blog.son-video.com/en/2020/03/guide-when-should-you-change-the-stylus-on-a-phono-cartridge-stylus/) — the stylus is a fine cantilever and diamond tip that meets the groove; it is not the entire cartridge body.
15. [Stylus contact macro](https://www.vintagetech.ru/articles/articles_vinil/8-kartridzhi-i-igly-dlja-vinilovyh-proigryvatelej.html) — a tiny contact shadow/reflection makes the needle-to-vinyl relationship legible.

## Findings that apply to VinylForMac

### 1. The arm must be curved in plan view

The screenshot’s straight diagonal line is the main reason it reads like a graphic overlay. Real examples use either an S-curve (Technics/SME style) or a gentle offset curve (Rega/Pro-Ject style). The curve is modest: the tube remains elegant, but it bends enough that the pivot-to-headshell path cannot be mistaken for a ruler-straight stroke.

The next pass should use a cubic Bézier or a short two-segment spline from pivot to headshell. The spline should be animated by the same playback progress as today, with the control points moving as a rigid arm around the pivot. Do not animate individual visual pieces independently.

### 2. Height is communicated by relative silhouettes, not brightness

In every useful reference, the pivot has a vertical pedestal, the arm tube begins above that pedestal, and the cartridge hangs below the tube. The tube is usually close to parallel with the record while playing. A darker, displaced shadow below the tube is more convincing than making the metal brighter.

The current scene needs three explicit heights:

- `deckSurface`: top plinth plane;
- `recordSurface`: the slightly higher vinyl plane;
- `armTubeHeight`: a clearly higher tube and headshell plane.

The stylus/cantilever is the only element that bridges `armTubeHeight` to `recordSurface`. When parked or paused, raise the stylus by a small cueing gap and soften/remove the contact shadow.

### 3. The pivot is a vertical assembly

The references show a mounting plate or ring, a thicker bearing housing, a central cap/bearing, and an arm collar emerging from the top. The arm should appear to enter the bearing horizontally. The counterweight should continue behind that bearing along the same arm axis, with a visible collar between shaft and weight.

For this app, the pivot should be rendered before the tube collar but after the pivot shadow. The central cap must sit above the housing rim; a highlight on the cap and a dark ring below it provide the depth cue.

### 4. The counterweight is cylindrical and aligned

The rear mass is consistently a cylinder or stepped cylinder, often with a threaded or knurled adjustment ring. Its long axis follows the arm shaft. It should have a brighter upper-left/top-facing side, a dark underside, and a short dark connection sleeve where it meets the arm.

### 5. The headshell is a small assembly below the arm

The visual chain should be: arm tube → collar → headshell/finger lift → cartridge body → cantilever → stylus tip. The cartridge body has visible thickness and is usually darker or a different material from the tube. Two tiny mounting screws are enough to make it read as hardware. Keep this group small relative to the record.

### 6. Playing and not-playing states need different cues

The current parked state looks odd because the arm is still presented as a long elevated diagonal with no strong resting relationship. The parked state should place the headshell over the arm rest, with the stylus clearly lifted. The rest should have a cradle/fork that catches the tube; its shadow should be tight and local.

During playback, the stylus should descend to the record and create a tiny contact shadow. The arm tube remains elevated, so the long tube shadow stays displaced and soft. Paused playback should preserve the playing position but lift the stylus only if the product’s intended cueing behavior calls for it; otherwise keep the stylus down and stop only the record motion.

### 7. Light direction should remain upper-left/front

Across the references, the useful studio treatment is a soft key from upper-left/front, a darker underside, and a restrained cool or neutral rim on the opposite edge. The same direction should control tube highlights, pivot cap, counterweight, headshell edge, and the cast shadows. Avoid a bright outline around the whole arm.

## Proposed implementation plan

1. Preserve the existing `progress`, `playing`, `enabled`, responsive scene scale, and transition calculations.
2. Replace the straight tube path with a rigid, gently curved arm spline. Define the spline in normalized scene coordinates so 2560 × 1440 remains the primary reference without hardcoding a screen position.
3. Derive the stylus contact point from the record ellipse and groove radius. Derive the raised headshell point from the same path plus an explicit vertical lift; never place the needle by a second unrelated coordinate.
4. Render the layer stack in this order: deck shadow, record shadow, parked-arm cradle, pivot base shadow, pivot sidewall, pivot top/bearing, elevated counterweight, elevated curved tube, headshell sidewall, cartridge, cantilever, stylus, and contact shadow.
5. Use two arm shadow passes: a broad displaced shadow on the plinth and a tighter darker shadow on the record. Increase blur and displacement with height; keep the stylus contact shadow small and sharp.
6. Add a cueing interpolation driven by `playing`/`enabled`: parked/paused lift is visible in the stylus gap, while playback places the diamond at the record surface. Keep this interpolation independent from record rotation.
7. Correct the arm-rest position so the parked headshell nests into it instead of floating beside it. Verify the pivot-to-rest geometry at the reference screenshot size.
8. Leave the Now Playing information and overall deck layout unchanged during this pass. Any display changes should be deferred until the arm silhouette and state behavior are correct.
9. Add geometry-only checks for: fixed pivot-to-headshell length, monotonic inward tracking, stylus contact inside the playable annulus, positive tube-to-record clearance, and parked-headshell intersection with the cradle.
10. Build and review snapshots at 2560 × 1440 for playing, paused, parked, and inner-groove states, plus one portrait render to protect responsive scaling.

## Acceptance criteria

- At 2560 × 1440, the tube visibly follows a gentle curve and cannot be mistaken for a single straight line.
- The pivot, tube, headshell, and stylus read as separate objects at normal viewing size.
- The tube and headshell visibly float above the plinth; only the stylus reaches the vinyl while playing.
- The parked state visibly rests in the cradle with the stylus lifted.
- Playback movement continues to track inward without changing arm length or breaking the record annulus.
- No changes are made to record size/location/rotation, metadata, controls, or app state architecture.

