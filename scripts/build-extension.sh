#!/usr/bin/env bash
# Build QRadar installable extension packages for lab testing.
#
# Outputs:
#   dist/hexcodec.xml              - standalone XML (CLI install)
#   dist/hexcodec-lab.zip          - ZIP with hexcodec.xml at root (GUI install, QRadar 7.3+)
#   dist/AQL-Hex-Codec-Functions-1.0.0-docs.zip - docs bundle (optional, not for install)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION="1.0.0"
SOURCE_XML="${ROOT_DIR}/extensions/hexcodec/hexcodec.xml"
DIST_DIR="${ROOT_DIR}/dist"
LAB_ZIP="${DIST_DIR}/hexcodec-lab.zip"
DOCS_ZIP="${DIST_DIR}/AQL-Hex-Codec-Functions-${VERSION}-docs.zip"
STANDALONE_XML="${DIST_DIR}/hexcodec.xml"

echo "==> Cleaning dist/ ..."
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

echo "==> Copying standalone XML ..."
cp "${SOURCE_XML}" "${STANDALONE_XML}"

echo "==> Creating lab ZIP (hexcodec.xml at ZIP root) ..."
python3 - <<PY
import zipfile
from pathlib import Path

out = Path("${LAB_ZIP}")
src = Path("${STANDALONE_XML}")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.write(src, arcname="hexcodec.xml")
print(out)
PY

echo "==> Creating docs ZIP (not for QRadar install) ..."
python3 - <<PY
import zipfile
from pathlib import Path

root = Path("${ROOT_DIR}")
out = Path("${DOCS_ZIP}")
docs = ["README.md", "LICENSE", "CHANGELOG.md", "TEST_PLAN.md", "TEST_REPORT_TEMPLATE.md", "BUILD_AND_DEPLOY.md"]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
    for name in docs:
        path = root / name
        if path.exists():
            zf.write(path, arcname=f"docs/{name}")
print(out)
PY

echo ""
echo "Build complete."
echo ""
echo "For QRadar 7.3.3 lab install, use ONE of:"
echo "  1) GUI:  dist/hexcodec-lab.zip"
echo "  2) CLI:  dist/hexcodec.xml"
echo ""
echo "Do NOT upload AQL-Hex-Codec-Functions-*-docs.zip to Extensions Management."
