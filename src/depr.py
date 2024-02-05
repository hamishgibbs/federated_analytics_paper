import sys
import polars as pl
import numpy as np
import powerlaw
from alive_progress import alive_bar

def calc_waiting_time(beta, tau):
    return powerlaw.Power_Law(0, parameters=[1.+ beta, 1.0/tau]).generate_random(1)[0]

def preferential_exploration(current_location, pij):
    """
    Preferential exploration based on gravity model
    """
    weights = pij.filter(pij['geoid_o'] == current_location)[:, 1:].to_numpy()[0]
    weights = weights / np.sum(weights)

    return np.random.choice(pij.columns[1:], size=1, p=weights)[0]

def preferential_return(trips):
    """
    Preferential return based on frequency of previously visited locations
    """
    
    # weight is based on the number of times a location has been visited
    weights = np.unique(trips[:, 1], return_counts=True)[1]
    weights = weights / np.sum(weights)

    return np.random.choice(np.unique(trips[:, 1]), size=1, p=weights)[0]

def choose_next_location(trips, pij, rho, gamma):
    """
    Choose next location based on whether to explore or return
    """

    current_location = trips[-1][1]    
    n_visited_locations = len(np.unique(trips[:, 1]))

    p_new = np.random.uniform(0, 1)
    if (p_new <= rho * np.power(n_visited_locations, -gamma)) \
        or (n_visited_locations == 1):
        return preferential_exploration(current_location, pij)
    else:
        return preferential_return(trips)

def depr(uid, start_location, pij, rho, gamma, beta, tau, duration):
    """
    Simulate a single individual based on the DEPR model
    """

    total_time = 0
    trips = np.array([(0, start_location)])
    while total_time < duration:
        time_to_next_visit = calc_waiting_time(beta, tau)

        next_location = choose_next_location(trips, pij, rho, gamma)

        total_time += time_to_next_visit

        trips = np.vstack((trips, (total_time, next_location)))

    trips = np.hstack((np.full((trips.shape[0], 1), uid), trips))
    
    # drop last row as it is over duration
    trips = trips[:-1, :]

    # convert to structured array
    dtype = [('uid', 'i4'), ('time', 'f4'), ('geoid', 'U10')]
    return np.array([tuple(row) for row in trips], dtype=dtype)

def population_depr(pop_sample, pij, rho, gamma, beta, tau, duration):
    """
    Simulate a population of individuals based on the DEPR model
    """

    # TODO: Could pre-allocate and clean up memory after use if needed

    all_trips = np.array([], dtype=[('uid', 'i4'), ('time', 'f4'), ('geoid', 'U10')])

    uid = 0

    with alive_bar(pop_sample['pop_sample'].sum()) as bar:
        for row in pop_sample.to_dicts():
            if row['pop_sample']:
                for _ in range(row['pop_sample']):
                    trips = depr(uid, row['GEOID'], pij, rho, gamma, beta, tau, duration)
                    all_trips = np.hstack((all_trips, trips))
                    uid += 1
                    bar()
    
    return pl.DataFrame(all_trips)


def sample_population(pop, pop_sample_rate):
    
    pop = pop.with_columns(
        (pop['POPESTIMATE2019'] * pop_sample_rate).cast(pl.Int32).alias('pop_sample')
    )

    pop = pop.drop('POPESTIMATE2019')

    return pop

if __name__ == '__main__':

    POP_SAMPLE_RATE = 0.01
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

    # TODO: For now, allocate individuals equally
    # In future, may be more realistic to sample based on population (more than population weighted)
    pop_sample = sample_population(pop, POP_SAMPLE_RATE)

    print(f"Simulating {pop_sample['pop_sample'].sum():,} individuals")

    pij = pij.sort(["geoid_o", "geoid_d"])

    pij = pij.pivot(
        index="geoid_o", 
        columns="geoid_d", 
        values="value",
        aggregate_function='first'
    ).fill_null(0)

    all_trips = population_depr(
        pop_sample, 
        pij, 
        RHO, 
        GAMMA, 
        BETA, 
        TAU, 
        DURATION
    )

    all_trips.write_csv(sys.argv[-1])



