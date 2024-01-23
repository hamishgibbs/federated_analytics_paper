import sys
import polars as pl
import numpy as np
from pure_ldp.frequency_oracles.apple_cms import CMSClient, CMSServer

def k_anonymous_sum(data, group, T):
    
    return (data.groupby(group)
            .agg([pl.col('count').sum().alias('count')])
            .filter(pl.col('count') >= T))

def add_laplace_noise(count, epsilon, sensitivity):
    scale = sensitivity / epsilon
    noise = np.random.laplace(0, scale)
    return count + noise

def sample_n(group: pl.DataFrame, n) -> pl.DataFrame:
        return group.sample(n=min(n, len(group)), with_replacement=False)

def bounded_sum_gdp(data, group, sensitivity, epsilon):

    # Select total rows per uid <= sensitivity
    data = data.groupby('uid').apply(lambda x: sample_n(x, sensitivity))
    
    data = (data.groupby(group)
            .agg([pl.col('count').sum().alias('count')]))

    return data.with_columns(
        pl.col('count').apply(lambda x: add_laplace_noise(x, epsilon, sensitivity)).alias('count')
    )

def sum_ldp(data, group, sensitivity, epsilon):

    # Select total rows per uid <= sensitivity
    data = data.groupby('uid').apply(lambda x: sample_n(x, sensitivity))
    
    return (data.groupby(['uid'] + group)
            .agg([pl.col('count').sum().alias('count')])
            .with_columns(
               pl.col('count').apply(lambda x: add_laplace_noise(x, epsilon, sensitivity)).alias('count')
               )
            .groupby(group)
            .agg([pl.col('count').sum().alias('count')])
            )

def freq_cms(domain, data, m, k, v, epsilon):
    """
    domain: polars dataframe with all pairs of geoid_o and geoid_d
    data: simulated individual trajectories
    m: size of hash domain
    k: number of hash functions
    v: number of rows per uid
    epsilon: privacy budget
    """     
    # Select total rows per uid <= v
    data = data.groupby('uid').apply(lambda x: sample_n(x, v))

    data = data.join(domain, on=['geoid_o', 'geoid_d'], how='left')

    server = CMSServer(epsilon, k, m, is_hadamard=False)
    client = CMSClient(epsilon, server.get_hash_funcs(), m, is_hadamard=False)

    for od_id in data['od_id'].to_list():
        server.aggregate(client.privatise(od_id))

    freq = []
    for od_id in domain['od_id'].to_list():
        freq.append(server.estimate(od_id))
    
    domain = domain.with_columns(pl.Series("count", freq))

    domain = domain.drop('od_id')

    domain = domain.with_columns(pl.col('count').apply(lambda x: np.max([x, 0])).alias('count'))

    return domain     


def main():

    _outputs = sys.argv[-4:]

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
    
    domain = depr.select([pl.col('geoid_o'), pl.col('geoid_d')]).unique()
    domain = domain.with_columns(pl.Series("od_id", range(domain.height)))

    depr = depr.with_columns(pl.lit(1).alias('count'))

    k_anonymous = k_anonymous_sum(depr, ['geoid_o', 'geoid_d'], T=10)

    gdp = bounded_sum_gdp(depr, ['geoid_o', 'geoid_d'], 
                          sensitivity=10, 
                          epsilon=10)
    
    ldp = sum_ldp(depr, ['geoid_o', 'geoid_d'], 
                  sensitivity=10, 
                  epsilon=10)

    cms = freq_cms(domain, 
                   depr, 
                   m=1024, 
                   k=10, 
                   v=10,
                   epsilon=10)

    k_anonymous.write_csv(_outputs[0])
    gdp.write_csv(_outputs[1])
    ldp.write_csv(_outputs[2])
    cms.write_csv(_outputs[3])
    

if __name__ == '__main__':
    main()
