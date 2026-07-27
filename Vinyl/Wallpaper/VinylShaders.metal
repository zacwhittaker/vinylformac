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
    float g1 = vnoise(float2(r * 0.70, 3.7)) - 0.5;
    float g2 = vnoise(float2(r * 0.22, 9.1)) - 0.5;
    float grooves = g1 * 0.6 + g2;

    float base = 0.052
               + grooveAmp * grooves * 0.022
               - sep * inGroove * 0.012;

    // Anisotropic sheen: two lobes where the groove tangent is
    // perpendicular to the light.
    float ca = dot(radial, L);
    float lobes = ca * ca;
    float env = smoothstep(labelR, 0.46, rn) * (1.0 - smoothstep(0.965, 1.0, rn));

    float sheen = (pow(lobes, 2.0) * 0.045
                 + pow(lobes, 5.0) * 0.26
                 + pow(lobes, 32.0) * 0.32)
                * env * (0.30 + 0.70 * grooveAmp);

    // Smooth lead-in / dead-wax areas reflect a narrower, more mirror-like band.
    float smoothArea = (1.0 - inGroove) * step(labelR, rn);
    sheen += pow(lobes, 80.0) * 0.18 * smoothArea * env;

    // Micro sparkle inside the lit lobes.
    float ang = atan2(d.y, d.x);
    float sp = hash21(float2(floor(r * 1.5), floor(ang * 520.0)));
    float sparkle = step(0.997, sp) * pow(lobes, 4.0) * grooveAmp * 0.34;

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
    float mat = 0.085
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
    float streak = (vnoise(float2(position.y * 1.4 + seed * 17.0,
                                  position.x * 0.012)) - 0.5) * 0.22;
    float fine   = (vnoise(float2(position.y * 6.0 + seed * 31.0,
                                  position.x * 0.030)) - 0.5) * 0.05;
    float g = 0.5 + streak + fine;
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
