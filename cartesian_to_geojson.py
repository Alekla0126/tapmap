import math
import json
import sys

def convert_to_geojson(input_data):
    """
    Converts Cartesian coordinates from input_data to GeoJSON format.
    """
    extent = input_data["mylayer"]["extent"]  # Extract the extent
    features = input_data["mylayer"]["features"]  # Extract the features list
    
    geojson_features = []
    
    for feature in features:
        x, y = feature["geometry"]["coordinates"]
        
        # Convert Cartesian coordinates to longitude and latitude
        longitude = (x / extent) * 360 - 180
        latitude = 90 - 360 * math.atan(math.exp(-((y / extent) * 2 * math.pi - math.pi))) / math.pi
        
        # Append the converted feature to the GeoJSON list
        geojson_features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [longitude, latitude]
            },
            "properties": feature["properties"]  # Keep the original properties
        })
    
    # Create the final GeoJSON
    geojson_output = {
        "type": "FeatureCollection",
        "features": geojson_features
    }
    
    return geojson_output


def main(file_path):
    """
    Main function to process a file and convert Cartesian coordinates to GeoJSON.
    """
    try:
        # Read the input file
        with open(file_path, 'r', encoding='utf-8') as f:
            input_data = json.load(f)
        
        # Convert the data to GeoJSON
        geojson_result = convert_to_geojson(input_data)
        
        # Print the GeoJSON to stdout
        print(json.dumps(geojson_result, indent=2, ensure_ascii=False))
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python cartesian_to_geojson.py <file_path>")
    else:
        main(sys.argv[1])
