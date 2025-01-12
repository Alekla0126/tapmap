import requests
from mapbox_vector_tile import decode
import json

# Constants
ZOOM = 0
X = 0  # Replace with tile X coordinate in the XYZ tiling system
Y = 0  # Replace with tile Y coordinate in the XYZ tiling system
TILE_URL = f"https://map-travel.net/tilesets/data/tiles/{ZOOM}/{X}/{Y}.pbf"
TILE_FILE = "tile.pbf"
DECODED_OUTPUT_FILE = "decoded_tile.json"

def download_tile(url, output_file):
    """Download the tile file and save it to the specified location."""
    print(f"Downloading tile from {url}...")
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()  # Raise an error for HTTP issues

        with open(output_file, "wb") as file:
            for chunk in response.iter_content(chunk_size=8192):
                file.write(chunk)

        print(f"Tile downloaded successfully to {output_file}")
    except requests.RequestException as e:
        print(f"Failed to download the tile: {e}")

def decode_tile(input_file, output_file):
    """Decode the .pbf tile and save the decoded output to a JSON file."""
    print(f"Decoding tile file: {input_file}...")
    try:
        with open(input_file, "rb") as file:
            tile_data = file.read()

        decoded_data = decode(tile_data)
        print(f"Decoded tile layers: {list(decoded_data.keys())}")

        with open(output_file, "w") as json_file:
            json.dump(decoded_data, json_file, indent=4)

        print(f"Decoded tile saved to {output_file}")
    except Exception as e:
        print(f"Error decoding tile: {e}")

def main():
    # Download the tile
    download_tile(TILE_URL, TILE_FILE)

    # Decode the downloaded tile
    decode_tile(TILE_FILE, DECODED_OUTPUT_FILE)

if __name__ == "__main__":
    main()
