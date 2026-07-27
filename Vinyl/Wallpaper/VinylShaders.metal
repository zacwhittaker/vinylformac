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
    float fineRings = sin(r * 8.6) * 0.40 + sin(r * 13.7) * 0.16;
    float g1 = vnoise(float2(r * 0.82, 3.7)) - 0.5;
    float g2 = vnoise(float2(r * 0.25, 9.1)) - 0.5;
    float grooves = fineRings * 0.40 + g1 * 0.40 + g2 * 0.26;

    float base = 0.068
               + grooveAmp * grooves * 0.010
               - sep * inGroove * 0.012;

    // Anisotropic sheen: two lobes where the groove tangent is
    // perpendicular to the light.
    float ca = dot(radial, L);
    float lobes = ca * ca;
    float env = smoothstep(labelR, 0.46, rn) * (1.0 - smoothstep(0.965, 1.0, rn));

    float sheen = (pow(lobes, 18.0) * 0.025
                 + pow(lobes, 54.0) * 0.050)
                * env * (0.30 + 0.70 * grooveAmp);

    // Smooth lead-in / dead-wax areas reflect a narrower, more mirror-like band.
    float smoothArea = (1.0 - inGroove) * step(labelR, rn);
    sheen += pow(lobes, 96.0) * 0.038 * smoothArea * env;

    // Micro sparkle inside the lit lobes.
    float ang = atan2(d.y, d.x);
    float sp = hash21(float2(floor(r * 1.5), floor(ang * 520.0)));
    float sparkle = step(0.9985, sp) * pow(lobes, 4.0) * grooveAmp * 0.10;

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
// Returned as mid-grey modulation, composited with soft-light blending.

[[ stitchable ]] half4 brushedMetal(float2 position, half4 color,
                                    float2 size, float seed) {
    float2 uv = position / max(size, float2(1.0));
    bool frontFacing = seed > 25.0;
    float2 grainPosition = frontFacing ? float2(position.x * 0.72, position.y * 0.055)
                                       : float2(position.y * 2.35, position.x * 0.022);
    float micro = (hash21(float2(grainPosition.x * 2.15, floor(grainPosition.y * 8.0) + seed)) - 0.5) * (frontFacing ? 0.066 : 0.070);
    float small = (vnoise(grainPosition + float2(seed * 17.0, 0.0)) - 0.5) * (frontFacing ? 0.17 : 0.145);
    float medium = (vnoise(float2(uv.x * 9.0 + seed, uv.y * 3.2)) - 0.5) * (frontFacing ? 0.105 : 0.085);
    // Local contrast follows the product-photo light rig: the warm left key
    // reveals the brush most strongly while neutral fill preserves the right.
    float grazing = frontFacing ? (0.72 + 0.28 * (1.0 - uv.x))
                                : (0.56 + 0.78 * pow(1.0 - uv.x, 1.55));
    float g = 0.5 + (micro + small + medium) * grazing;
    return half4(half3(g), 1.0);
}

// Photographic grain ----------------------------------------------------------
// Static mid-grey noise, composited with soft-light blending.

[[ stitchable ]] half4 filmGrain(float2 position, half4 color,
                                 float intensity, float seed) {
    float n = hash21(position * 1.37 + seed);
    float g = 0.5 + (n - 0.5) * intensity;
    return half4(half3(g), 1.0);
}
