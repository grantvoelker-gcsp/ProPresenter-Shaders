#!/bin/bash
# Removes the blend-mode filter effects from both ProPresenter GLSL folders,
# restoring each framework's original (sealed) file set. Only new files were
# ever added, so removal returns things to stock exactly.
#
# Usage:
#   ./uninstall.sh          # removes from the writable Helper folder
#   sudo ./uninstall.sh     # ALSO removes from the /Applications app bundle
set -uo pipefail

FILES=(blendModes.h CRTMonitorBlend.metal CRTMonitorBlend.rvfx DotsBlend.metal DotsBlend.rvfx AlphaCurve.metal AlphaCurve.rvfx InverseVignette.metal InverseVignette.rvfx RippleCenterIntensity.metal RippleCenterIntensity.rvfx RippleSideIntensity.metal RippleSideIntensity.rvfx RadialBlurAngle.metal RadialBlurAngle.rvfx ShapeMaskEllipse.metal ShapeMaskEllipse.rvfx ShapeMaskRect.metal ShapeMaskRect.rvfx Extrude3D.metal Extrude3D.rvfx BoxGlitch.metal BoxGlitch.rvfx YawSwing.metal YawSwing.rvfx YawSnap.metal YawSnap.rvfx HatchShading.metal HatchShading.rvfx GaussianBlur.metal GaussianBlur.rvfx Transform2D.metal Transform2D.rvfx Bloom.metal Bloom.rvfx CutoutMask.metal CutoutMask.rvfx ShapeMaskRectRot.metal ShapeMaskRectRot.rvfx HologramGlitch.metal HologramGlitch.rvfx Sheen.metal Sheen.rvfx LumaMatte.metal LumaMatte.rvfx)

HELPER="$HOME/Library/Application Support/RenewedVision/ProPresenter/Helpers/Workspaces/frameworks/ssAPI.framework/Versions/A/Resources/GLSL"
BUNDLE="/Applications/ProPresenter.app/Contents/Frameworks/ssAPI.framework/Versions/A/Resources/GLSL"
if [ "${SUDO_USER:-}" != "" ]; then
  HELPER="$(eval echo "~$SUDO_USER")/Library/Application Support/RenewedVision/ProPresenter/Helpers/Workspaces/frameworks/ssAPI.framework/Versions/A/Resources/GLSL"
fi

echo "Removing from Helper: $HELPER"
for f in "${FILES[@]}"; do rm -f "$HELPER/$f"; done

if [ "$(id -u)" -eq 0 ]; then
  echo "Removing from app bundle: $BUNDLE"
  for f in "${FILES[@]}"; do rm -f "$BUNDLE/$f"; done
fi
echo "Removed. Relaunch ProPresenter."
