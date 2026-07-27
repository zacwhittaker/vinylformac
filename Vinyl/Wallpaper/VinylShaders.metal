#include <metal_stdlib>
using namespace metal;

// Shared helpers -------------------------------------------------------------

static inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static inline float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static inline float ringGauss(float rn, float center, float width) {
    float x = (rn - center) / width;
    return exp(-x * x);
}

// Integer hashing avoids the repeating bands caused by loss of precision in
// floating-point hashes across a large design canvas. No tiled bitmap or time.
static inline float materialNoise(float2 p) {
    uint2 q = uint2(int2(floor(p)));
    uint n = q.x * 1597334677u ^ q.y * 3812015801u;
    n ^= n >> 16; n *= 2246822519u; n ^= n >> 13;
    return float(n & 0x00ffffffu) / 16777215.0;
}

// Continuous fibres avoid visible rectangular cells on long metal surfaces.
static inline float finishNoise(float2 p) {
    float2 cell = floor(p);
    float2 u = smoothstep(0.0, 1.0, fract(p));
    return mix(mix(materialNoise(cell), materialNoise(cell + float2(1, 0)), u.x),
               mix(materialNoise(cell + float2(0, 1)), materialNoise(cell + 1), u.x), u.y);
}

// Preserve the shaped surface's alpha and lighting. 0 = satin metal,
// 1 = fine elastomer, 2 = machined metal. Applied only to physical surfaces.
[[ stitchable ]] half4 componentFinish(float2 position, half4 color, float kind) {
    float micro = materialNoise(position * 1.4) - 0.5;
    float brush = finishNoise(float2(position.x / 68.0, position.y * 1.25)) - 0.5;
    float pores = finishNoise(position * 0.9) - 0.5;
    float variation = kind < 0.5 ? micro * 0.055 + brush * 0.13
                    : kind < 1.5 ? micro * 0.18 + pores * 0.24
                    : micro * 0.06 + brush * 0.30;
    return half4(color.rgb * half(1.0 + variation), color.a);
}

// Fine charcoal microcement for the studio surface. The large-scale field is
// deliberately broad and non-directional; the smaller aggregate is restrained
// so the surface reads clearly without becoming a repeating wallpaper pattern.
[[ stitchable ]] half4 microcementSurface(float2 position, half4 color,
                                           float2 size) {
    float2 p = position / max(size, float2(1.0));
    float macro = vnoise(position * 0.0032 + float2(11.0, 7.0)) - 0.5;
    float mid = vnoise(position * 0.012 + float2(23.0, 19.0)) - 0.5;
    // Smooth aggregate replaces hard per-cell noise: no isolated pixels or
    // square specks when viewed on a bright Retina display.
    float aggregate = finishNoise(position * 0.065) - 0.5;
    float light = 0.016 * (1.0 - p.y) + 0.008 * (1.0 - p.x);
    float value = light + macro * 0.022 + mid * 0.009 + aggregate * 0.003;
    // Warm charcoal separates the backdrop from the cooler graphite chassis.
    float3 base = float3(0.062, 0.058, 0.055) + value;
    return half4(half3(clamp(base, 0.0, 1.0)), color.a);
}

// Display calibration in linear light. Positive exposure adds most energy to
// dark midtones, tapers to zero at white, and preserves the deepest occlusion.
// Negative values gently compress the scene for bright/low-contrast panels.
[[ stitchable ]] half4 sceneExposure(float2 position, half4 color,
                                     float exposure) {
    float3 rgb = float3(color.rgb);
    float luminance = dot(rgb, float3(0.2126, 0.7152, 0.0722));
    if (exposure >= 0.0) {
        float shadowFloor = smoothstep(0.002, 0.035, luminance);
        float highlightProtection = pow(1.0 - clamp(luminance, 0.0, 1.0), 2.4);
        rgb += exposure * 0.22 * shadowFloor * highlightProtection;
    } else {
        float compression = 1.0 + exposure * 0.42;
        rgb *= mix(compression, 1.0, smoothstep(0.45, 1.0, luminance));
    }
    return half4(half3(clamp(rgb, 0.0, 1.0)), color.a);
}

// Vinyl record surface -------------------------------------------------------
//
// The disc is rotationally symmetric (concentric grooves), so the whole
// surface including its light response can stay static while only the label
// and dust rotate above it. The signature realism cue is the anisotropic
// sheen: grooves scatter light into two soft lobes along the light axis
// through the spindle, fixed relative to the light rather than the record.

[[ stitchable ]] half4 vinylSurface(float2 position, half4 color,
                                    float2 size, float2 lightDir) {
    float2 c = size * 0.5;
    float2 d = position - c;
    float R = min(size.x, size.y) * 0.5;
    float r = length(d);
    float rn = r / R;

    float alpha = 1.0 - smoothstep(R - 1.2, R + 0.2, r);
    if (alpha <= 0.0) { return half4(0.0); }

    float2 radial = r > 0.001 ? d / r : float2(0.0, 1.0);
    float2 L = normalize(lightDir);

    const float labelR     = 0.318;
    const float deadwaxEnd = 0.372;
    const float grooveEnd  = 0.955;
    const float edgeStart  = 0.982;

    // Track separations: quieter land between songs reads darker and calmer.
    float sep = ringGauss(rn, 0.455, 0.0075)
              + ringGauss(rn, 0.560, 0.0060)
              + ringGauss(rn, 0.662, 0.0080)
              + ringGauss(rn, 0.778, 0.0060)
              + ringGauss(rn, 0.884, 0.0070);
    sep = min(sep, 1.0);

    float inGroove = smoothstep(deadwaxEnd, deadwaxEnd + 0.012, rn)
                   * (1.0 - smoothstep(grooveEnd, grooveEnd + 0.010, rn));
    float grooveAmp = inGroove * mix(1.0, 0.30, sep);

    // Concentric micro-groove modulation at two scales to avoid moiré.
    float fineRings = sin(r * 2.1) * 0.24;
    float g1 = vnoise(float2(r * 0.82, 3.7)) - 0.5;
    float g2 = vnoise(float2(r * 0.25, 9.1)) - 0.5;
    float grooves = fineRings * 0.40 + g1 * 0.40 + g2 * 0.26;

    float base = 0.068
               + grooveAmp * grooves * 0.045
               - sep * inGroove * 0.012;

    // Anisotropic sheen: two lobes where the groove tangent is
    // perpendicular to the light.
    float ca = dot(radial, L);
    float lobes = ca * ca;
    float env = smoothstep(labelR, 0.46, rn) * (1.0 - smoothstep(0.965, 1.0, rn));

    float sheen = (pow(lobes, 18.0) * 0.075
                 + pow(lobes, 54.0) * 0.145)
                * env * (0.30 + 0.70 * grooveAmp);
    sheen *= 1.0 + grooves * grooveAmp * 0.90;

    // Smooth lead-in / dead-wax areas reflect a narrower, more mirror-like band.
    float smoothArea = (1.0 - inGroove) * step(labelR, rn);
    sheen += pow(lobes, 96.0) * 0.080 * smoothArea * env;

    // Micro sparkle inside the lit lobes.
    float ang = atan2(d.y, d.x);
    float sp = hash21(float2(floor(r * 1.5), floor(ang * 520.0)));
    float sparkle = step(0.9995, sp) * pow(lobes, 4.0) * grooveAmp * 0.025;

    // Edge bevel: darkens overall, catches light on the side facing the lamp.
    float bevel = smoothstep(edgeStart, 1.0, rn);
    base *= 1.0 - bevel * 0.45;
    float rimLight = bevel * max(0.0, dot(radial, L)) * 0.20;

    float3 sheenTint = float3(1.0, 0.94, 0.84);
    float3 rgb = base * float3(1.02, 1.0, 0.98)
               + sheen * sheenTint
               + sparkle
               + rimLight * sheenTint;

    rgb = clamp(rgb, 0.0, 1.0);
    return half4(half3(rgb * alpha), half(alpha));
}

// Platter: rubber mat with fine concentric ribs and a machined metal rim ----

[[ stitchable ]] half4 platterSurface(float2 position, half4 color,
                                      float2 size, float2 lightDir) {
    float2 c = size * 0.5;
    float2 d = position - c;
    float R = min(size.x, size.y) * 0.5;
    float r = length(d);
    float rn = r / R;

    float alpha = 1.0 - smoothstep(R - 1.2, R + 0.2, r);
    if (alpha <= 0.0) { return half4(0.0); }

    float2 radial = r > 0.001 ? d / r : float2(0.0, 1.0);
    float2 L = normalize(lightDir);
    float ca = dot(radial, L);
    float lobes = ca * ca;

    float rimStart = 0.955;
    float rim = smoothstep(rimStart, rimStart + 0.02, rn);

    // Rubber mat body.
    float ribs = sin(r * 1.35) * 0.5 + 0.5;
    float mat = 0.105
              + (vnoise(float2(r * 0.8, 4.2)) - 0.5) * 0.018
              + ribs * 0.020 * smoothstep(0.15, 0.3, rn)
              + pow(lobes, 4.0) * 0.045; // dull rubber sheen

    // Machined aluminum rim.
    float metal = 0.30
                + (vnoise(float2(r * 0.9, 8.8)) - 0.5) * 0.10
                + pow(lobes, 3.0) * 0.14
                + pow(lobes, 28.0) * 0.16
                + max(0.0, dot(radial, L)) * 0.10;

    float v = mix(mat, metal, rim);
    v *= 1.0 - smoothstep(0.994, 1.0, rn) * 0.5;

    float3 rgb = clamp(float3(v * 1.0, v * 0.995, v * 0.985), 0.0, 1.0);
    return half4(half3(rgb * alpha), half(alpha));
}

// Brushed aluminum for the deck face -----------------------------------------
// Modulate the actual surface color, preserving premultiplied alpha. A separate
// grey soft-light layer can wash out the finish in the live compositing path.

[[ stitchable ]] half4 brushedMetal(float2 position, half4 color,
                                    float2 size, float seed) {
    float2 uv = position / max(size, float2(1.0));
    bool front = seed > 25.0;
    float2 surface = position;
    if (front) {
        // The existing fascia spans x=.04... .95, y=.775... .90.
        // Unwrap its rounded ends and lower return in material coordinates;
        // neither the silhouette nor the projection is changed.
        float end = smoothstep(0.36, 0.455, abs(uv.x - 0.495));
        float lower = smoothstep(0.85, 0.90, uv.y);
        surface.y += size.y * (0.018 * end * end + 0.009 * lower * lower);
        surface.x += size.x * 0.012 * end * end * sign(uv.x - 0.495);
    }
    float2 p = surface + float2(seed * 13.0, seed * 7.0);
    // Short, irregular hairlines mixed with isotropic microtexture. No long
    // bands or broad noise field that could resemble stretched silver stripes.
    float fibre = finishNoise(float2(p.x / 6.0, p.y * 1.15)) - 0.5;
    float micro = finishNoise(p * 1.15) - 0.5;
    // Increase local grain contrast without lifting the average graphite tone.
    float variation = fibre * (front ? 0.25 : 0.34) + micro * 0.10;
    float tone = front ? 0.80 : 0.84;
    return half4(color.rgb * half(tone * (1.0 + variation)), color.a);
}

// Photographic grain ----------------------------------------------------------
// Static mid-grey noise, composited with soft-light blending.

[[ stitchable ]] half4 filmGrain(float2 position, half4 color,
                                 float intensity, float seed) {
    float n = hash21(position * 1.37 + seed);
    float g = 0.5 + (n - 0.5) * intensity;
    return half4(half3(g), 1.0);
}
