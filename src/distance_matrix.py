import sys
import polars as pl
import numpy as np

def haversine(lat1, lon1, lat2, lon2):
    R = 6371.0

    lat1_rad, lon1_rad, lat2_rad, lon2_rad = map(np.radians, [lat1, lon1, lat2, lon2])

    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad

    a = np.sin(dlat / 2)**2 + np.cos(lat1_rad) * np.cos(lat2_rad) * np.sin(dlon / 2)**2
    c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1 - a))

    return R * c

def main():

    centroids = pl.read_csv(
        sys.argv[1],
        columns=['GEOID', 'lat', 'lng'],
        dtypes={'GEOID': pl.Utf8}
    )

    pop = pl.read_csv(
        sys.argv[2], 
        columns=["GEOID", "POPESTIMATE2019"],
        dtypes={'GEOID': pl.Utf8}
    )
    
    pop = pop.sort("GEOID")

    dist = centroids.join(centroids, how='cross')

    dist = dist.rename({
        'GEOID': 'GEOID_origin', 
        'GEOID_right': 'GEOID_dest',
        'lat': 'lat_origin',
        'lng': 'lng_origin',
        'lat_right': 'lat_dest',
        'lng_right': 'lng_dest'
        })
        
    distances = haversine(dist['lat_origin'], dist['lng_origin'], dist['lat_dest'], dist['lng_dest'])

    dist = dist.with_columns(distances.alias('distance'))

    # Some counties are missing population data
    dist = dist.filter(dist["GEOID_origin"].is_in(pop["GEOID"]) & dist["GEOID_dest"].is_in(pop["GEOID"]))

    dist.write_csv(sys.argv[3])

if __name__ == '__main__':
    main()
