import sys
import polars as pl
import numpy as np
from pure_ldp.frequency_oracles.apple_cms import CMSClient, CMSServer
from alive_progress import alive_bar

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

def freq_cms(domain, data, m, k, sensitivity, epsilon):
    """
    domain: polars dataframe with all pairs of geoid_o and geoid_d
    data: simulated individual trajectories
    m: size of hash domain
    k: number of hash functions
    v: number of rows per uid
    epsilon: privacy budget
    """     
    # Select total rows per uid <= v
    data = data.groupby('uid').apply(lambda x: sample_n(x, sensitivity))

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

    return domain     
