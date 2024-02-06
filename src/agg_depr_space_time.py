import sys
import polars as pl

#combine files based on t
# Alter timestamps to make sure days are reflected correctly
#Select GEOIDs based on k


def main():

    space_k = int(sys.argv[1])
    time_t = int(sys.argv[2])

    geoid_lu = pl.read_csv(sys.argv[3],
                           dtypes={'GEOID': pl.Utf8,
                                   "k": pl.Int32,
                                   "cluster": pl.Utf8,
                                   "k_cluster": pl.Utf8})
    
    geoid_lu_k = geoid_lu.filter(geoid_lu['k'] == space_k)
    
    depr_fn = sys.argv[(3+1):(3+1+time_t)]

    depr_concat = pl.DataFrame({'uid': [],
                         'time': [],
                         'geoid': []},
                         schema={'uid': pl.Utf8,
                                 'time': pl.Float32,
                                 'geoid': pl.Utf8})

    for i, fn in enumerate(depr_fn):
        depr = pl.read_csv(fn,
                           dtypes={'uid': pl.Utf8,
                                   'time': pl.Float32,
                                   'geoid': pl.Utf8})
        
        depr = depr.with_columns(
            # Increment time by (24*day number) hours
            # This is important because applying privacy involves sorting by time
            (depr['time'] + (i*24)).cast(pl.Float32).alias('time')
        )

        depr = depr.join(geoid_lu_k.select(["GEOID", "k_cluster"]), left_on='geoid', right_on="GEOID",  
                         how='left')
        
        depr = depr.with_columns(
            depr['k_cluster'].alias('geoid')
        )

        depr = depr.drop('k_cluster')

        depr_concat = pl.concat([depr_concat, depr])

    depr_concat.write_csv(sys.argv[-1])    

if __name__ == "__main__":
    main()