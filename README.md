# ProPresenter Custom Effects (macOS / Metal)

A collection of custom Inspector **filter effects** for ProPresenter 7 on macOS,
written in Metal. They install **alongside** the stock effects (nothing stock is
modified) and show up in the Inspector's effect picker.

Each effect is a pair:
- `Name.rvfx` — JSON metadata: `name`, `numPasses`, `shaderFile`, `type` (0 = filter),
  a `uuid`, and `variables[]` (the Inspector controls).
- `Name.metal` — the Metal vertex+fragment shader, compiled at runtime.

Shared: `blendModes.h` (blend-mode include used by the `*Blend` effects).

## Install / uninstall

```bash
# install into the render-helper folder only (no sudo, survives most launches)
./install.sh

# ALSO install into the /Applications app bundle so they appear in the UI (needs sudo)
sudo ./install.sh --bundle

# remove from both
sudo ./uninstall.sh
```

Then fully quit and relaunch ProPresenter. Only **new** files are ever added, so
uninstall restores the stock state exactly.

## Effect catalog (22)

**Blend modes** (add traditional blend modes to a stock effect; see `blendModes.h`)
- **CRT Monitor (Blend)** — Strength, Size, Blend Mode
- **Dots (Blend)** — Intensity, Color, Blend Mode

**Color / stylize**
- **Alpha Curve** — Dark / Midtone / Light Opacity (opacity by luminance)
- **Hatch Shading** — Line Spacing, Thickness, Darkness (pen-and-ink cross-hatch)
- **Sheen Shimmer** — Angle, Speed, Intensity, Scale (fbm sheen, alpha-masked, morphs over time)
- **Bloom** — Threshold, Amount, Radius (additive overbright, clips to white)
- **Inverse Vignette** — Radius (darkens the center)

**Masks / mattes**
- **Shape Mask (Ellipse)** — Center X/Y, Scale X/Y, Edge Fade, Invert
- **Shape Mask (Rectangle)** — Center X/Y, Scale X/Y, Edge Fade, Invert
- **Shape Mask (Rect + Rotation)** — + Rotation
- **Cutout Mask (Black)** — Invert, Feather (black matte from alpha, feathered edge)
- **Luma Matte** — Threshold, Softness, Invert (alpha from luminance / luma key)

**Transform / distortion**
- **Transform** — X, Y, Scale, Skew, Rotation (2D affine, aspect-correct)
- **Extrude 3D** — Angle, Size, Shade (long-shadow / fake extrusion)
- **Yaw Swing 3D** — Speed, Angle, Perspective (perspective yaw, smooth swing)
- **Yaw Snap 3D** — Speed, Angle, Perspective (perspective yaw, snaps between positions)
- **Ripple Center (Intensity)** — Speed, Intensity
- **Ripple Side (Intensity)** — Speed, Intensity
- **Radial Blur (Angle)** — Blend, Angle, Iterations, Decay (static, angle-aimed)

**Blur**
- **Gaussian Blur** — Intensity (2-pass separable, true Gaussian weights) *(multi-pass)*

**Glitch / generative**
- **Box Glitch** — Chance/60s, Amount, Blocks, Duration, Seed (random block glitch)
- **Hologram Glitch** — scanlines, roll bar, RGB split, band tearing, flicker, noise, glow, Tint (color)

## How it works — the two-folder architecture

`ssAPI.framework` loads effects from `./GLSL` **relative to each process's own
framework copy**, so a full install needs both:

1. **Render helper** (user-writable, no sudo) — where the effects actually render:
   `~/Library/Application Support/RenewedVision/ProPresenter/Helpers/Workspaces/frameworks/ssAPI.framework/Versions/A/Resources/GLSL`
2. **App bundle** (root-owned, needs sudo) — where the main app enumerates the
   Inspector effect list:
   `/Applications/ProPresenter.app/Contents/Frameworks/ssAPI.framework/Versions/A/Resources/GLSL`

## Authoring notes (lessons baked in)

- **Shader inputs:** a filter fragment gets its own `inputTex` + `inputTexMask`,
  `fxGeneralUniforms` (`globalTime`, `localTime`, `random`, `blendValue`, …) and
  `fxVars` (the `.rvfx` controls). No audio, no backdrop/lower-layer (that needs a
  `type: 2` background effect).
- **Variable packing:** `type:1` slider → one `float` (tight-packed); `type:2`
  color → `float4` (16-byte aligned). Struct field order must match `variables[]`
  order; put any color **last**.
- **No `radians()`** — it isn't used by any stock shader and fails to compile here,
  producing a null pipeline that crashes the app. Convert degrees with an explicit
  `* 0.01745329…` constant.
- **Hashing:** use precision-robust hashes (Dave Hoskins), not `fract(sin(x*large))`,
  which collapses for large args (broke the Box Glitch trigger with big seeds).
- **Multi-pass** effects use `numPasses` + `u.pass` (see `GaussianBlur`); the
  framework does **not** preserve the original across passes.
- **Adding a control to an effect that's already on a slide** requires removing and
  re-adding it (the stored instance keeps the old variable set).
- Keep alpha handling inside the `#ifdef PRE_MULT` divide/multiply guards.

## Caveats

- These frameworks are Developer-ID signed with hardened runtime. Adding resource
  files breaks the `codesign` seal; at runtime the loader validates the framework
  *binary*, not `.metal`/`.rvfx` text, so it launches fine — but a future
  ProPresenter **update wipes the bundle copy** (re-run `install.sh --bundle`), and
  `uninstall.sh` restores the sealed state.
- `shaders/AlphaCurve.DIAG.metal` is a diagnostic build (paints uniforms as flat
  color) kept for troubleshooting; it is not installed by the scripts.

## Layout

```
ppblend-effects/
├── README.md
├── install.sh
├── uninstall.sh
└── shaders/
    ├── blendModes.h
    ├── <Effect>.metal
    └── <Effect>.rvfx
```
