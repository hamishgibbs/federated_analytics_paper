import click
import polars as pl
from privacy import bounded_sum_gdp, sum_ldp, freq_cms

@click.command()
@click.option('--infn')
@click.option('--construction')
@click.option('--epsilon')
@click.option('--sensitivity')
@click.option('--k')
@click.option('--m')
@click.option('--outfn')
def aggregate_with_privacy(
    infn,
    construction,
    epsilon,
    sensitivity,
    k,
    m,
    outfn):

    depr = pl.read_csv(
        infn,
        columns=['uid', 'time', 'geoid'],
        dtypes={'geoid': pl.Utf8}
    )

    depr = depr.sort(["uid", "time"]) \
       .groupby("uid") \
       .apply(lambda group: group.with_columns(group["geoid"].shift(-1).alias("geoid_d"))) \
       .rename({'geoid': 'geoid_o'}) \
       .filter(pl.col('geoid_d').is_not_null())
    
    domain = depr.select([pl.col('geoid_o'), pl.col('geoid_d')]).unique()
    domain = domain.with_columns(pl.Series("od_id", range(domain.height)))

    depr = depr.with_columns(pl.lit(1).alias('count'))

    if construction == "GDP":
        res = bounded_sum_gdp(
            depr, 
            ['geoid_o', 'geoid_d'], 
            sensitivity=int(sensitivity), 
            epsilon=float(epsilon)
        )
    elif construction == "naive_LDP":
         res = sum_ldp(domain,
                  depr, 
                  ['geoid_o', 'geoid_d'], 
                  sensitivity=int(sensitivity), 
                  epsilon=float(epsilon))
    elif construction == "CMS":
         k = int(k)
         m = int(m)
         res = freq_cms(domain, 
                   depr, 
                   k=k,
                   m=m,
                   sensitivity=int(sensitivity),
                   epsilon=float(epsilon))

    else:
        raise ValueError("Unknown construction")
    
    res = res.with_columns(
            pl.lit(construction).alias('construction'),
            pl.lit(epsilon).alias('epsilon'),
            pl.lit(sensitivity).alias('sensitivity'),
            pl.lit(m).alias('m'), 
            pl.lit(k).alias('k')
    )

    res.write_csv(outfn)

if __name__ == '__main__':
    aggregate_with_privacy()