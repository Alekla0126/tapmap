#!/bin/bash

# Tile coordinates and zoom level
ZOOM=15
X=7.8804
Y=98.3923
TILE_URL="https://map-travel.net/tilesets/data/tiles/${ZOOM}/${X}/${Y}.pbf"
TILE_FILE="tile.pbf"

# Download the tile
echo "Downloading tile..."
curl -o "$TILE_FILE" "$TILE_URL"

# Check if the tile was downloaded successfully
if [ -f "$TILE_FILE" ]; then
  echo "Tile downloaded successfully."
else
  echo "Failed to download the tile."
  exit 1
fi

# Ensure the mapbox_vector_tile module is installed
echo "Installing mapbox_vector_tile module..."
pip3 install mapbox-vector-tile

# Decode the tile using Python
echo "Decoding tile with Python..."
python3 - <<EOF
import mapbox_vector_tile
import os
import gzip

try:
    # Check if the file exists and is not empty
    if not os.path.isfile("$TILE_FILE") or os.path.getsize("$TILE_FILE") == 0:
        raise Exception("Tile file is missing or empty")

    # Read the .pbf file
    with open("$TILE_FILE", "rb") as f:
        compressed_tile_data = f.read()

    # Decompress the tile data
    tile_data = gzip.decompress(compressed_tile_data)

    # Check if the tile data is not empty
    if not tile_data:
        raise Exception("Tile data is empty")

    # Print the first few bytes of the tile data for debugging
    print(f"Tile data (first 100 bytes): {tile_data[:10]}")

    # Decode the vector tile
    decoded_tile = mapbox_vector_tile.decode(tile_data)

    # Print all features and properties
    for layer_name, layer_data in decoded_tile.items():
        print(f"Layer: {layer_name}")
        for feature in layer_data.get("features", []):
            print(f"Feature: {feature}")
            # properties = feature.get("properties", {})
            # print(f"Feature ID: {properties.get('id', 'No ID')}")
            # print(f"Properties: {properties}")
except Exception as e:
    print(f"Error decoding tile: {e}")
EOF

# Cleanup
echo "Cleaning up..."
rm -f "$TILE_FILE"
echo "Done!"
