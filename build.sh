#!/usr/bin/env bash
# ================================================
#   Peaka ODBC Driver - Build Script (macOS / Linux)
#
#   Produces:
#     dist/peaka.mez        -- Power BI custom connector
#     dist/peaka_odbc.zip   -- Full distribution package
#
#   Structure inside peaka_odbc.zip:
#     driver/**                     (Simba ODBC driver, as-is)
#     bin/install.bat               (main setup entry point)
#     bin/utils/**                  (helper scripts + templates)
#     extensions/powerbi/peaka.mez  (Power BI connector)
#     manual/README.md
#
#   Requires: zip (pre-installed on most systems)
# ================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
DIST_DIR="$SCRIPT_DIR/dist"
DRIVER_DIR="$SCRIPT_DIR/driver"

mkdir -p "$DIST_DIR"

echo
echo " ================================================"
echo "      Peaka ODBC Driver - Build"
echo " ================================================"
echo

# ================================================
# Step 1: Build peaka.mez
#   ZIP all files inside src/extensions/powerbi/
# ================================================
echo " [1/2] Building dist/peaka.mez ..."

MEZ_SRC="$SRC_DIR/extensions/powerbi"
MEZ_OUT="$DIST_DIR/peaka.mez"

# Stamp __BUILD_DATE__ in peaka_odbc.m with today's date (YYYY-MM-DD)
BUILD_DATE_STAMP="$(date +%Y-%m-%d)"
MEZ_STAGE="$(mktemp -d)"
cp -r "$MEZ_SRC"/* "$MEZ_STAGE/"
sed -i.bak "s/__BUILD_DATE__/$BUILD_DATE_STAMP/g" "$MEZ_STAGE/peaka_odbc.m"
rm -f "$MEZ_STAGE/peaka_odbc.m.bak"

rm -f "$MEZ_OUT"
(cd "$MEZ_STAGE" && zip -r "$MEZ_OUT" . -x "*.DS_Store" -x "__MACOSX/*" -x "*.gitkeep")
rm -rf "$MEZ_STAGE"

echo " OK: $MEZ_OUT"
echo

# ================================================
# Step 2: Build peaka_odbc.zip
#   Stage all content then zip into dist/
# ================================================
echo " [2/2] Building dist/peaka_odbc.zip ..."

ZIP_OUT="$DIST_DIR/peaka_odbc.zip"
STAGE_DIR="$(mktemp -d)"

cleanup() { rm -rf "$STAGE_DIR"; }
trap cleanup EXIT

# Copy driver (as-is)
cp -r "$DRIVER_DIR" "$STAGE_DIR/driver"

# Copy scripts: install.bat -> bin/  and  utils/ -> bin/utils/
mkdir -p "$STAGE_DIR/bin"
cp "$SRC_DIR/scripts/install.bat" "$STAGE_DIR/bin/install.bat"
cp -r "$SRC_DIR/scripts/utils" "$STAGE_DIR/bin/utils"

# Copy Power BI connector
mkdir -p "$STAGE_DIR/extensions/powerbi"
cp "$MEZ_OUT" "$STAGE_DIR/extensions/powerbi/peaka.mez"

# Copy README into manual/ subdirectory
mkdir -p "$STAGE_DIR/manual"
cp "$SRC_DIR/README.md" "$STAGE_DIR/manual/README.md"

# Create zip from staging dir
rm -f "$ZIP_OUT"
(cd "$STAGE_DIR" && zip -r "$ZIP_OUT" .)

echo " OK: $ZIP_OUT"
echo

echo " ================================================"
echo "  Build complete."
echo
echo "  dist/peaka.mez        -- Power BI connector"
echo "  dist/peaka_odbc.zip   -- Full distribution package"
echo " ================================================"
echo
