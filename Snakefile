# Params to govern number of states in modelling
# Params to govern number of days of modelling

collective_types = [
    "gravity_basic", 
    "gravity_transport",
    "gravity_power",
    "gravity_exp",
    "gravity_powernorm",
    "gravity_expnorm",
    "departure-diffusion_power",
    "departure-diffusion_exp"
    ]

epsilons = [0.1, 0.5, 1, 5, 10, 15]
sensitivities = [1, 2, 5, 10]

sensitivity_params = {
    "GDP": {
        "epsilon": epsilons,
        "sensitivity": sensitivities
    },
    "CMS": {
        "k": [1, 5, 10, 100, 1000],
        "m": [2**i for i in range(2, 14, 2)],
        "epsilon": epsilons,
        "sensitivity": sensitivities
    },
    "naive_LDP": {
        "epsilon": epsilons,
        "sensitivity": 10
    },
}

rule all:
    input:
        "data/geo/2019_us_county_distance_matrix.csv",
        "data/population/pop_est2019_clean.csv",
        "output/sensitivity/collective_model_sensitivity/collective_model_metrics_2019_01_01.png",
        "output/analytics/base_analytics/departure-diffusion_exp/base_analytics_2019_01_01.csv",
        "output/analytics/k_anonymous/departure-diffusion_exp/k_anonymous_analytics_2019_01_01.csv",
        "output/figs/k_anonymity_construction.png",
        "output/analytics/sensitivity/privacy_sensitivity_2019_01_01.csv"

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
        expand("output/gravity/check/{collective_type}_2019_01_01_check.csv", collective_type=collective_types),
        expand("output/gravity/pij/{collective_type}_2019_01_01_pij.csv", collective_type=collective_types)
    output:
        "output/sensitivity/collective_model_sensitivity/collective_error_comparison_2019_01_01.png",
        "output/sensitivity/collective_model_sensitivity/collective_model_metrics_2019_01_01.png",
        "output/sensitivity/collective_model_sensitivity/collective_model_metrics_2019_01_01.csv"
    shell:
        """
        Rscript {input} {output}
        """

rule compare_privacy_construction:
    input:
        "src/privacy.py",
        "output/depr/departure-diffusion_exp/simulated_depr_2019_01_01.csv"
    output:
        "output/analytics/k_anonymous/departure-diffusion_exp/k_anonymous_analytics_2019_01_01.csv",
        "output/analytics/gdp/departure-diffusion_exp/gdp_analytics_2019_01_01.csv",
        "output/analytics/naive_ldp/departure-diffusion_exp/naive_ldp_analytics_2019_01_01.csv",
        "output/analytics/cms/departure-diffusion_exp/cms_analytics_2019_01_01.csv"
    shell:
        """
        python {input} {output}
        """

rule plot_privacy_construction:
    input:
        "src/plot_privacy_construction.ipynb",
        "output/analytics/base_analytics/departure-diffusion_exp/base_analytics_2019_01_01.csv",
        "output/analytics/k_anonymous/departure-diffusion_exp/k_anonymous_analytics_2019_01_01.csv",
        "output/analytics/gdp/departure-diffusion_exp/gdp_analytics_2019_01_01.csv",
        "output/analytics/naive_ldp/departure-diffusion_exp/naive_ldp_analytics_2019_01_01.csv",
        "output/analytics/cms/departure-diffusion_exp/cms_analytics_2019_01_01.csv"
    output:
        'output/figs/k_anonymity_construction.png',
        'output/figs/gdp_construction.png',
        'output/figs/naive_ldp_construction.png',
        'output/figs/cms_construction.png'
    shell:
        """
        jupyter nbconvert --to notebook --execute {input[0]}
        """

rule all_privacy_sensitivity:
    input:
        "src/calc_privacy_error.py",
        expand("output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_2019_01_01.csv", 
        construction="GDP",
        sensitivity=sensitivity_params["GDP"]["sensitivity"],
        epsilon=sensitivity_params["GDP"]["epsilon"],
        k="NA",
        m="NA"),
        expand("output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_2019_01_01.csv", 
        construction="naive_LDP",
        sensitivity=sensitivity_params["naive_LDP"]["sensitivity"],
        epsilon=sensitivity_params["naive_LDP"]["epsilon"],
        k="NA",
        m="NA"),
        expand("output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_2019_01_01.csv", 
        construction="CMS",
        sensitivity=sensitivity_params["CMS"]["sensitivity"],
        epsilon=sensitivity_params["CMS"]["epsilon"],
        k=sensitivity_params["CMS"]["k"],
        m=sensitivity_params["CMS"]["m"])
    output:
        "output/analytics/sensitivity/privacy_sensitivity_2019_01_01.csv"
    shell:
        "python {input} {output}"

rule privacy_sensitivity:
    input:
        "src/privacy_sensitivity.py",
        "output/depr/departure-diffusion_exp/simulated_depr_2019_01_01.csv"
    params:
        construction=lambda wildcards: wildcards.construction,
        epsilon=lambda wildcards: wildcards.epsilon,
        sensitivity=lambda wildcards: wildcards.sensitivity,
        k=lambda wildcards: wildcards.k,
        m=lambda wildcards: wildcards.m
    output:
        "output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_2019_01_01.csv"
    shell:
        """
        python {input[0]} --infn {input[1]} --construction {params.construction} --epsilon {params.epsilon} --sensitivity {params.sensitivity} --k {params.k} --m {params.m} --outfn {output}
        """


# rule fit_collective: # full-scale fitting for the chosen model (if its a model that needs fitting)