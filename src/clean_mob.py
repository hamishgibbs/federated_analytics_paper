import sys
import polars as pl

def main():

    # Read observed data
    mob = pl.read_csv(sys.argv[1], 
                      columns=[
                          "geoid_o", 
                          "geoid_d", 
                          "pop_flows"], 
                      dtypes={
                          'geoid_o': pl.Utf8, 
                          'geoid_d': pl.Utf8
                        })

    pop = pl.read_csv(
        sys.argv[2], 
        columns=["GEOID"],
        dtypes={'GEOID': pl.Utf8}
    )

    mob = mob.with_columns(pl.col("pop_flows").cast(pl.Int64))
    
    # Same - some counties are missing population data
    mob = mob.filter(mob["geoid_o"].is_in(pop["GEOID"]) & mob["geoid_d"].is_in(pop["GEOID"]))

    mob_full = pop.join(pop, how='cross')

    mob_full = mob_full.rename({
        'GEOID': 'geoid_o', 
        'GEOID_right': 'geoid_d'
        })
    
    mob_full = mob_full.join(mob, on=["geoid_o", "geoid_d"], how="left")

    mob_full = mob_full.fill_null(0)

    mob_full.write_csv(sys.argv[3])

if __name__ == "__main__":
    main()