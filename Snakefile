from src.calc_sensitivity_dates import sensitivity_dates

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
        "k": [1, 5, 10, 100, 1000, 10000],
        "m": [2**i for i in range(6, 14, 2)],
        "epsilon": epsilons,
        "sensitivity": sensitivities
    },
    "naive_LDP": {
        "epsilon": epsilons,
        "sensitivity": 10
    },
}

FOCUS_DATE = "2019_01_01"
FOCUS_DIVISION = "2"
DATES = sensitivity_dates()
DIVISIONS = [str(i) for i in range(1, 9)]

rule all:
    input:
        "data/geo/2019_us_county_distance_matrix.csv",
        "data/population/pop_est2019_clean.csv",
        expand("output/sensitivity/collective_model_sensitivity/collective_error_comparison_{date}_d_{division}.png", date=FOCUS_DATE, division=FOCUS_DIVISION),
        "output/figs/k_anonymity_construction.png",
        #f"output/analytics/sensitivity/privacy_sensitivity_errors_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        "output/figs/construction_epsilon_mape.png",
        "output/sensitivity/spatio_temporal_sensitivity/test.csv"

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

rule download_mob:
    output:
        "data/mobility/daily_county2county_{date}.csv"
    shell:
        """
        wget -O {output} https://github.com/GeoDS/COVID19USFlows-DailyFlows/raw/master/daily_flows/county2county/daily_county2county_{wildcards.date}.csv
        """

rule clean_mob:
    input:
        "data/mobility/daily_county2county_{date}.csv",
        "data/population/pop_est2019_clean.csv"
    output:
        "data/mobility/clean/daily_county2county_{date}_clean.csv"
    shell:
        """
        python src/clean_mob.py {input} {output}
        """

rule collective_model_sensitivity:
    input:
        "src/fit_gravity.R",
        "data/population/pop_est2019_clean.csv",
        "data/geo/2019_us_county_distance_matrix.csv",
        "data/mobility/clean/daily_county2county_{date}_clean.csv"
    params:
        n_burn=500,
        n_samp=1000,
        division=lambda wildcards: wildcards.division,
    output:
        "output/gravity/summary/{collective_type}_{date}_d_{division}_summary.csv",
        "output/gravity/check/{collective_type}_{date}_d_{division}_check.csv",
        "output/gravity/pij/{collective_type}_{date}_d_{division}_pij.csv",
        "output/gravity/diagnostic/{collective_type}_{date}_d_{division}_error.png",
        "output/gravity/diagnostic/{collective_type}_{date}_d_{division}_error.rds"
    shell:
        """
        Rscript {input} {params.n_burn} {params.n_samp} {params.division} {output}
        """

rule plot_collective_model_sensitivity:
    input:
        "src/plot_collective_model_sensitivity.R",
        "data/mobility/clean/daily_county2county_{date}_clean.csv",
        lambda wildcards: expand("output/gravity/check/{collective_type}_{date}_d_{division}_check.csv", 
            collective_type=collective_types,
            date=wildcards.date,
            division=wildcards.division),
        lambda wildcards: expand("output/gravity/pij/{collective_type}_{date}_d_{division}_pij.csv", 
            collective_type=collective_types,
            date=wildcards.date,
            division=wildcards.division)
    output:
        "output/sensitivity/collective_model_sensitivity/collective_error_comparison_{date}_d_{division}.png",
        "output/sensitivity/collective_model_sensitivity/collective_model_metrics_{date}_d_{division}.png",
        "output/sensitivity/collective_model_sensitivity/collective_model_metrics_{date}_d_{division}.csv"
    shell:
        """
        Rscript {input} {output}
        """

rule simulate_depr:
    input:
        "src/depr.py",
        "data/population/pop_est2019_clean.csv",
        "output/gravity/pij/{collective_type}_{date}_d_{division}_pij.csv"
    output:
        "output/depr/{collective_type}/simulated_depr_{date}_d_{division}.csv"
    shell:
        """
        python {input} {output}
        """

rule base_analytics:
    input:
        "src/base_analytics.py",
        "output/depr/{collective_type}/simulated_depr_{date}_d_{division}.csv"
    output:
        "output/analytics/base_analytics/{collective_type}/base_analytics_{date}_d_{division}.csv"
    shell:
        """
        python {input} {output}
        """

# TODO: Division and date sensitivity here
rule spatio_temporal_sensitivity:
    input:
        expand("output/gravity/summary/departure-diffusion_exp_{date}_d_{division}_summary.csv", date=DATES, division=DIVISIONS)
    output:
        "output/sensitivity/spatio_temporal_sensitivity/test.csv"
    shell:
        "touch {output}"

rule compare_privacy_construction:
    input:
        "src/privacy.py",
        f"output/depr/departure-diffusion_exp/simulated_depr_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv"
    output:
        f"output/analytics/k_anonymous/departure-diffusion_exp/k_anonymous_analytics_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/gdp/departure-diffusion_exp/gdp_analytics_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/naive_ldp/departure-diffusion_exp/naive_ldp_analytics_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/cms/departure-diffusion_exp/cms_analytics_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv"
    shell:
        """
        python {input} {output}
        """

rule plot_privacy_construction:
    input:
        "src/plot_privacy_construction.ipynb",
        f"output/analytics/base_analytics/departure-diffusion_exp/base_analytics_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/k_anonymous/departure-diffusion_exp/k_anonymous_analytics_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/gdp/departure-diffusion_exp/gdp_analytics_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/naive_ldp/departure-diffusion_exp/naive_ldp_analytics_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/cms/departure-diffusion_exp/cms_analytics_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv"
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
        "output/analytics/base_analytics/departure-diffusion_exp/base_analytics_{date}_d_{division}.csv",
        lambda wildcards: expand("output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_{date}_d_{division}.csv", 
        construction="GDP",
        sensitivity=sensitivity_params["GDP"]["sensitivity"],
        epsilon=sensitivity_params["GDP"]["epsilon"],
        k="NA",
        m="NA",
        date=wildcards.date,
        division=wildcards.division),
        lambda wildcards: expand("output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_{date}_d_{division}.csv", 
        construction="naive_LDP",
        sensitivity=sensitivity_params["naive_LDP"]["sensitivity"],
        epsilon=sensitivity_params["naive_LDP"]["epsilon"],
        k="NA",
        m="NA",
        date=wildcards.date,
        division=wildcards.division),
        lambda wildcards: expand("output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_{date}_d_{division}.csv", 
        construction="CMS",
        sensitivity=sensitivity_params["CMS"]["sensitivity"],
        epsilon=sensitivity_params["CMS"]["epsilon"],
        k=sensitivity_params["CMS"]["k"],
        m=sensitivity_params["CMS"]["m"],
        date=wildcards.date,
        division=wildcards.division)
    output:
        "output/analytics/sensitivity/privacy_sensitivity_errors_{date}_d_{division}.csv",
        "output/analytics/sensitivity/privacy_sensitivity_{date}_d_{division}.csv"
    shell:
        "python {input} {output}"

rule privacy_sensitivity:
    input:
        "src/privacy_sensitivity.py",
        "output/depr/departure-diffusion_exp/simulated_depr_{date}_d_{division}.csv"
    params:
        construction=lambda wildcards: wildcards.construction,
        epsilon=lambda wildcards: wildcards.epsilon,
        sensitivity=lambda wildcards: wildcards.sensitivity,
        k=lambda wildcards: wildcards.k,
        m=lambda wildcards: wildcards.m
    output:
        "output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_{date}_d_{division}.csv"
    shell:
        """
        python {input[0]} --infn {input[1]} --construction {params.construction} --epsilon {params.epsilon} --sensitivity {params.sensitivity} --k {params.k} --m {params.m} --outfn {output}
        """

rule plot_privacy_error:
    input: 
        "src/plot_privacy_error.R",
        f"output/analytics/sensitivity/privacy_sensitivity_errors_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/sensitivity/privacy_sensitivity_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        "data/geo/2019_us_county_distance_matrix.csv"
    output:
        "output/figs/construction_epsilon_mape.png",
        "output/figs/construction_epsilon_ape_threshold.png",
        "output/figs/construction_epsilon_freq_ape.png"
    shell:
        "Rscript {input} {output}"