#!/bin/bash

set -e

SVG_FILE="chronology_app_icon.svg"
ICONSET_DIR="Chronology.iconset"
ICNS_FILE="Chronology.icns"

# Create iconset directory
mkdir -p "$ICONSET_DIR"

# Generate PNG files at different sizes
# macOS requires specific sizes for .icns files
sizes=(16 32 64 128 256 512 1024)

echo "Converting SVG to PNG at different sizes..."

for size in "${sizes[@]}"; do
    # Standard resolution
    qlmanage -t -s $size -o . "$SVG_FILE" 2>/dev/null || true
    if [ -f "${SVG_FILE}.png" ]; then
        mv "${SVG_FILE}.png" "$ICONSET_DIR/icon_${size}x${size}.png"
    fi
    
    # Retina resolution (@2x) - except for 1024 which doesn't have @2x
    if [ $size -ne 1024 ]; then
        retina_size=$((size * 2))
        qlmanage -t -s $retina_size -o . "$SVG_FILE" 2>/dev/null || true
        if [ -f "${SVG_FILE}.png" ]; then
            mv "${SVG_FILE}.png" "$ICONSET_DIR/icon_${size}x${size}@2x.png"
        fi
    fi
done

# If qlmanage didn't work, try using sips to convert from a base PNG
# First, create a large PNG from SVG using qlmanage
echo "Creating base image..."
qlmanage -t -s 1024 -o . "$SVG_FILE" 2>/dev/null || true

if [ -f "${SVG_FILE}.png" ]; then
    BASE_PNG="${SVG_FILE}.png"
    
    # Generate all required sizes from the base PNG
    for size in "${sizes[@]}"; do
        sips -z $size $size "$BASE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null 2>&1
        
        if [ $size -ne 1024 ]; then
            retina_size=$((size * 2))
            sips -z $retina_size $retina_size "$BASE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null 2>&1
        fi
    done
    
    rm "$BASE_PNG"
fi

# Convert iconset to icns
echo "Creating .icns file..."
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"

# Clean up
rm -rf "$ICONSET_DIR"

echo "Successfully created $ICNS_FILE"
