import sys
import polars as pl
import numpy as np
import powerlaw
from alive_progress import alive_bar

def calc_waiting_time(beta, tau):
    return powerlaw.Power_Law(0, parameters=[1.+ beta, 1.0/tau]).generate_random(1)[0]

def preferential_exploration(current_location, pij_weights):
    """
    Preferential exploration based on gravity model
    """
    weights = np.array(pij_weights[current_location])

    # Choosing destination (column) based on weights. 
    # Requires that pij_weights.keys() values correspond to the ordering of weights
    return np.random.choice(list(pij_weights.keys()), size=1, p=weights)[0]

def preferential_return(trips):
    """
    Preferential return based on frequency of previously visited locations
    """
    
    # weight is based on the number of times a location has been visited
    weights = np.unique(trips[:, 1], return_counts=True)[1]
    weights = weights / np.sum(weights)

    return np.random.choice(np.unique(trips[:, 1]), size=1, p=weights)[0]

def choose_next_location(trips, pij_weights, rho, gamma):
    """
    Choose next location based on whether to explore or return
    """

    current_location = trips[-1][1]    
    n_visited_locations = len(np.unique(trips[:, 1]))

    p_new = np.random.uniform(0, 1)
    if (p_new <= rho * np.power(n_visited_locations, -gamma)) \
        or (n_visited_locations == 1):
        return preferential_exploration(current_location, pij_weights)
    else:
        return preferential_return(trips)

def depr(uid, start_location, pij_weights, rho, gamma, beta, tau, duration):
    """
    Simulate a single individual based on the DEPR model
    """

    total_time = 0
    trips = np.array([(0, start_location)])
    while total_time < duration:
        time_to_next_visit = calc_waiting_time(beta, tau)

        next_location = choose_next_location(trips, pij_weights, rho, gamma)

        total_time += time_to_next_visit

        trips = np.vstack((trips, (total_time, next_location)))

    trips = np.hstack((np.full((trips.shape[0], 1), uid), trips))
    
    # drop last row as it is over duration
    trips = trips[:-1, :]

    # convert to structured array
    dtype = [('uid', 'i4'), ('time', 'f4'), ('geoid', 'U10')]
    return np.array([tuple(row) for row in trips], dtype=dtype)

def population_depr(pop_sample, pij_weights, rho, gamma, beta, tau, duration):
    """
    Simulate a population of individuals based on the DEPR model
    """

    n_uids = pop_sample['pop_sample'].sum()
    
    # NOTE: Pre-allocating memory to speed up modelling. 
    # Estimating that each individual will make 10 trips 
    # This is an optimization dependent on duration and waiting time distribution
    max_trips = n_uids * 10 

    all_trips = np.zeros(max_trips, dtype=[('uid', 'i4'), ('time', 'f4'), ('geoid', 'U10')])

    uid = 0
    trip_counter = 0

    with alive_bar(n_uids) as bar:
        for row in pop_sample.to_dicts():
            if row['pop_sample']:
                for _ in range(row['pop_sample']):
                    trips = depr(uid, row['GEOID'], pij_weights, rho, gamma, beta, tau, duration)
                    num_trips = len(trips)

                    if trip_counter + num_trips > max_trips:
                        raise ValueError("Exceeded pre-allocated trip storage.")
                    
                    all_trips[trip_counter:trip_counter + num_trips] = trips

                    trip_counter += num_trips
                    uid += 1
                    bar()

    all_trips = all_trips[:trip_counter]
    
    return pl.DataFrame(all_trips)


def sample_population(pop, pop_sample_rate):
    
    pop = pop.with_columns(
        (pop['POPESTIMATE2019'] * pop_sample_rate).cast(pl.Int32).alias('pop_sample')
    )

    pop = pop.drop('POPESTIMATE2019')

    return pop

def build_pij_weights(pij: pl.DataFrame) -> dict:
    """
    Build a dictionary of weights for each origin location
    """
    pij = pij.sort(["geoid_o", "geoid_d"])

    pij = pij.pivot(
        index="geoid_o", 
        columns="geoid_d", 
        values="value",
        aggregate_function='first'
    ).fill_null(0)
    pij_weights = pij[:, 1:] / pij[:, 1:].sum(axis=1)
    pij_weights = pij_weights.insert_column(0, pij['geoid_o'])

    pij_weights_dict = {}

    for row in pij_weights.to_dicts():
        key = row['geoid_o']
        values = [row[col] for col in pij_weights.columns[1:]]
        pij_weights_dict[key] = values

    return pij_weights_dict

if __name__ == '__main__':

    POP_SAMPLE_RATE = 0.001
    RHO = 0.6
    GAMMA = 0.21
    BETA = 0.8
    TAU = 17
    DURATION = 24

    pop = pl.read_csv(
        sys.argv[1],
        columns=['GEOID', 'POPESTIMATE2019'],
        dtypes={'GEOID': pl.Utf8}
    )

    pij = pl.read_csv(
        sys.argv[2],
        columns=['geoid_o', 'geoid_d', 'value'],
        dtypes={'geoid_o': pl.Utf8, 'geoid_d': pl.Utf8}
    )

    # Get a list of unique first 2 characters of geoid_o from pij (state)
    # then filter pop to only include those geoids
    states = pij['geoid_o'].str.slice(0, 2).unique().to_list()
    pop = pop.filter(pop['GEOID'].str.slice(0, 2).is_in(states))

    # TODO: Allocate individuals equally accorting to census population
    pop_sample = sample_population(pop, POP_SAMPLE_RATE)
    print(f"Simulating {pop_sample['pop_sample'].sum():,} individuals")

    pij_weights = build_pij_weights(pij)
    
    # TODO: queue this up for parallel processing with cores provided by job

    all_trips = population_depr(
        pop_sample, 
        pij_weights, 
        RHO, 
        GAMMA, 
        BETA, 
        TAU, 
        DURATION
    )

    all_trips.write_csv(sys.argv[-1])



