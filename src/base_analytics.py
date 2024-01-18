import sys
import polars as pl

def main():

    depr = pl.read_csv(
        sys.argv[1],
        columns=['uid', 'time', 'geoid'],
        dtypes={'geoid': pl.Utf8}
    )

    depr = depr.sort(["uid", "time"]) \
       .groupby("uid") \
       .apply(lambda group: group.with_columns(group["geoid"].shift(-1).alias("geoid_d"))) \
       .rename({'geoid': 'geoid_o'}) \
       .filter(pl.col('geoid_d').is_not_null())

    od = depr.groupby(['geoid_o', 'geoid_d']).count()

    od.write_csv(sys.argv[-1])

if __name__ == '__main__':
    main()