# Params to govern number of states in modelling
# Params to govern number of days of modelling

collective_types = [
    "gravity_basic", 
    "gravity_transport",
    "gravity_power",
    "gravity_exp",
    "gravity_powernorm",
    "gravity_expnorm",
    "radiation_basic",
    "radiation_finite",
    "departure-diffusion_power",
    "departure-diffusion_exp",
    "departure-diffusion_radiation"
    ]

rule all:
    input:
        "data/geo/2019_us_county_distance_matrix.csv",
        "data/population/pop_est2019_clean.csv",
        expand("output/sensitivity/collective_model_sensitivity/{collective_type}_2019_01_01_error_comparison.png", collective_type=collective_types),
        "output/sensitivity/collective_model_sensitivity/collective_model_metrics_2019_01_01.png"

# rule to download mobility data by date pattern

rule counties_to_centroids:
    input:
        "data/geo/tl_2019_us_county/tl_2019_us_county.shp"
    output:
        "data/geo/tl_2019_us_county_centroid.csv"
    shell:
        """
        ogr2ogr -f "CSV" {output} {input} -dialect sqlite -sql "SELECT ST_X(ST_Centroid(geometry)) AS lng, ST_Y(ST_Centroid(geometry)) AS lat, * FROM 'tl_2019_us_county'"
        """

rule distance_matrix:
    input:
        "data/geo/tl_2019_us_county_centroid.csv",
        "data/population/pop_est2019_clean.csv"
    output:
        "data/geo/2019_us_county_distance_matrix.csv"
    shell:
        """
        python src/distance_matrix.py {input} {output}
        """

rule clean_pop:
    input:
        "data/population/co-est2019-alldata-utf8.csv"
    output:
        "data/population/pop_est2019_clean.csv"
    shell:
        """
        python src/clean_pop.py {input} {output}
        """

rule clean_mob:
    input:
        "data/mobility/daily_county2county_2019_01_01.csv",
        "data/population/pop_est2019_clean.csv"
    output:
        "data/mobility/clean/daily_county2county_2019_01_01_clean.csv"
    shell:
        """
        python src/clean_mob.py {input} {output}
        """

rule collective_model_sensitivity:
    input:
        "src/fit_gravity.R",
        "data/population/pop_est2019_clean.csv",
        "data/geo/2019_us_county_distance_matrix.csv",
        "data/mobility/clean/daily_county2county_2019_01_01_clean.csv"
    params:
        n_burn=100,
        n_samp=500,
    output:
        "output/gravity/summary/{collective_type}_2019_01_01_summary.csv",
        "output/gravity/check/{collective_type}_2019_01_01_check.csv",
        "output/gravity/pij/{collective_type}_2019_01_01_pij.csv",
        "output/gravity/diagnostic/{collective_type}_2019_01_01_error.png",
        "output/gravity/diagnostic/{collective_type}_2019_01_01_error.rds"
    shell:
        """
        Rscript {input} {params.n_burn} {params.n_samp} {output}
        """

rule simulate_depr:
    input:
        "src/depr.py",
        "data/population/pop_est2019_clean.csv",
        "output/gravity/pij/{collective_type}_2019_01_01_pij.csv"
    output:
        "output/depr/{collective_type}/simulated_depr_2019_01_01.csv"
    shell:
        """
        python {input} {output}
        """

rule base_analytics:
    input:
        "src/base_analytics.py",
        "output/depr/{collective_type}/simulated_depr_2019_01_01.csv"
    output:
        "output/analytics/base_analytics/{collective_type}/base_analytics_2019_01_01.csv"
    shell:
        """
        python {input} {output}
        """

rule plot_collective_model_sensitivity:
    input:
        "src/plot_collective_model_sensitivity.R",
        "data/mobility/clean/daily_county2county_2019_01_01_clean.csv",
        "output/analytics/base_analytics/{collective_type}/base_analytics_2019_01_01.csv",
        "data/geo/2019_us_county_distance_matrix.csv",
        "output/gravity/diagnostic/{collective_type}_2019_01_01_error.rds"
    output:
        "output/sensitivity/collective_model_sensitivity/{collective_type}_2019_01_01_error_comparison.png"
    shell:
        """
        Rscript {input} {output}
        """

rule plot_collective_model_metrics_sensitivity:
    input:
        "src/plot_collective_model_metrics_sensitivity.R",
        expand("output/gravity/check/{collective_type}_2019_01_01_check.csv", collective_type=collective_types)
    output:
        "output/sensitivity/collective_model_sensitivity/collective_model_metrics_2019_01_01.png"
    shell:
        """
        Rscript {input} {output}
        """

# rule fit_collective: # full-scale fitting for the chosen model (if its a model that needs fitting)