#!/bin/bash
# Installs the blend-mode filter effects into ProPresenter.
#
# The Helper (renderer) folder is user-writable and needs NO sudo.
# The app-bundle folder is root-owned; only that half needs sudo.
#
# Usage:
#   ./install.sh            # installs into the writable Helper folder only
#   sudo ./install.sh --bundle   # ALSO installs into /Applications app bundle
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)/shaders"
FILES=(blendModes.h CRTMonitorBlend.metal CRTMonitorBlend.rvfx DotsBlend.metal DotsBlend.rvfx AlphaCurve.metal AlphaCurve.rvfx InverseVignette.metal InverseVignette.rvfx RippleCenterIntensity.metal RippleCenterIntensity.rvfx RippleSideIntensity.metal RippleSideIntensity.rvfx RadialBlurAngle.metal RadialBlurAngle.rvfx ShapeMaskEllipse.metal ShapeMaskEllipse.rvfx ShapeMaskRect.metal ShapeMaskRect.rvfx Extrude3D.metal Extrude3D.rvfx BoxGlitch.metal BoxGlitch.rvfx YawSwing.metal YawSwing.rvfx YawSnap.metal YawSnap.rvfx HatchShading.metal HatchShading.rvfx GaussianBlur.metal GaussianBlur.rvfx Transform2D.metal Transform2D.rvfx Bloom.metal Bloom.rvfx CutoutMask.metal CutoutMask.rvfx ShapeMaskRectRot.metal ShapeMaskRectRot.rvfx HologramGlitch.metal HologramGlitch.rvfx Sheen.metal Sheen.rvfx LumaMatte.metal LumaMatte.rvfx)

HELPER="$HOME/Library/Application Support/RenewedVision/ProPresenter/Helpers/Workspaces/frameworks/ssAPI.framework/Versions/A/Resources/GLSL"
BUNDLE="/Applications/ProPresenter.app/Contents/Frameworks/ssAPI.framework/Versions/A/Resources/GLSL"

# If run with sudo, $HOME may be root's; recompute the real user's Helper path.
if [ "${SUDO_USER:-}" != "" ]; then
  HELPER="$(eval echo "~$SUDO_USER")/Library/Application Support/RenewedVision/ProPresenter/Helpers/Workspaces/frameworks/ssAPI.framework/Versions/A/Resources/GLSL"
fi

echo "Installing into Helper (renderer): $HELPER"
for f in "${FILES[@]}"; do cp "$DIR/$f" "$HELPER/$f"; done
echo "  done."

if [ "${1:-}" == "--bundle" ]; then
  if [ "$(id -u)" -ne 0 ]; then echo "ERROR: --bundle requires sudo."; exit 1; fi
  echo "Installing into app bundle: $BUNDLE"
  for f in "${FILES[@]}"; do cp "$DIR/$f" "$BUNDLE/$f"; done
  echo "  done. (Note: this breaks the framework's code-signature seal; reversible via uninstall.sh)"
fi

echo "Installed. Fully quit ProPresenter (incl. helper processes) and relaunch."
