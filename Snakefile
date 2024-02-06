import os
from dotenv import load_dotenv
from datetime import datetime, timedelta
from src.calc_sensitivity_dates import sensitivity_dates

load_dotenv()

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
DIVISIONS = [str(i) for i in [1, 2, 8, 9]]

SPACE_K=list(range(5, 85, 10))
TIME_T=list(range(1, 8))

rule all:
    input:
        "rulegraph.png",
        "output/figs/empirical_network_map.png",
        'output/figs/spacetime_prism.png',
        "output/figs/k_anonymity_example.png",
        "output/figs/spatiotemporal_r2_by_date_type.png",
        expand("output/sensitivity/collective_model_sensitivity/collective_error_comparison_date_{date}_d_{division}.png", date=FOCUS_DATE, division=FOCUS_DIVISION),
        "output/figs/k_anonymity_construction.png",
        "output/figs/construction_epsilon_mape.png",
        "output/figs/spacetime_raster.png"

rule current_rulegraph: 
  input: 
      "Snakefile"
  output:
      "rulegraph.png"
  shell:
      "snakemake --rulegraph | dot -Tpng > {output}"

rule download_population: 
    output:
        "data/population/co-est2019-alldata-utf8.csv"
    shell:
        """
        wget -O {output} https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/counties/totals/co-est2019-alldata.csv
        """

rule division_lu:
    input:
        "data/population/co-est2019-alldata-utf8.csv"
    output:
        "data/geo/division_lu.csv"
    shell:
        """
        Rscript src/division_lu.R {input} {output}
        """

rule download_counties:
    output:
        "data/geo/tl_2019_us_county/tl_2019_us_county.shp"
    params:
        zip_file="data/geo/tl_2019_us_county.zip",
        unzip_dir="data/geo/tl_2019_us_county"
    shell:
        """
        wget -O {params.zip_file} https://www2.census.gov/geo/tiger/TIGER2019/COUNTY/tl_2019_us_county.zip
        unzip -d {params.unzip_dir} {params.zip_file}
        """

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
        "data/mobility/raw/daily_county2county_date_{date}.csv"
    shell:
        """
        wget -O {output} https://github.com/GeoDS/COVID19USFlows-DailyFlows/raw/master/daily_flows/county2county/daily_county2county_{wildcards.date}.csv
        """

rule clean_mob:
    input:
        "data/mobility/raw/daily_county2county_date_{date}.csv",
        "data/population/pop_est2019_clean.csv"
    output:
        "data/mobility/clean/daily_county2county_date_{date}_clean.csv"
    shell:
        """
        python src/clean_mob.py {input} {output}
        """

rule plot_space_time_prism:
    input:
        "src/plot_space_time_prism.py",
        "data/geo/tl_2019_us_county/tl_2019_us_county.shp"
    output:
        'output/figs/spacetime_prism.png'
    shell:
        """
        python {input} {output}
        """

rule plot_simulated_mobility:
    input:
        "src/plot_simulated_mobility.R",
        f"data/mobility/clean/daily_county2county_date_{FOCUS_DATE}_clean.csv",
        f"output/analytics/base_analytics/departure-diffusion_exp/base_analytics_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        "data/geo/2019_us_county_distance_matrix.csv"
    output:
        "output/figs/empirical_network_map.png",
        "output/figs/depr_network_map.png"
    shell:
        """
        Rscript {input} {output}
        """

rule plot_gdp_examples:
    input:
        "src/plot_gdp_examples.py",
    output:
        "output/figs/k_anonymity_example.png",
        "output/figs/gdp_naive_example.png",
        "output/figs/ldp_naive_example.png"
    shell:
        """
        python {input} {output}
        """

rule fit_gravity:
    input:
        "src/fit_gravity.R",
        "data/geo/division_lu.csv",
        "data/population/pop_est2019_clean.csv",
        "data/geo/2019_us_county_distance_matrix.csv",
        "data/mobility/clean/daily_county2county_date_{date}_clean.csv"
    params:
        n_burn=100,
        n_samp=500,
        division=lambda wildcards: wildcards.division,
    output:
        "output/gravity/summary/{collective_type}_date_{date}_d_{division}_summary.csv",
        "output/gravity/check/{collective_type}_date_{date}_d_{division}_check.csv",
        "output/gravity/pij/{collective_type}_date_{date}_d_{division}_pij.csv",
        "output/gravity/diagnostic/{collective_type}_date_{date}_d_{division}_error.png",
        "output/gravity/diagnostic/{collective_type}_date_{date}_d_{division}_error.rds"
    shell:
        """
        Rscript {input} {params.n_burn} {params.n_samp} {params.division} {output}
        """

rule plot_collective_model_sensitivity:
    input:
        "src/plot_collective_model_sensitivity.R",
        "data/mobility/clean/daily_county2county_date_{date}_clean.csv",
        lambda wildcards: expand("output/gravity/check/{collective_type}_date_{date}_d_{division}_check.csv", 
            collective_type=collective_types,
            date=wildcards.date,
            division=wildcards.division),
        lambda wildcards: expand("output/gravity/pij/{collective_type}_date_{date}_d_{division}_pij.csv", 
            collective_type=collective_types,
            date=wildcards.date,
            division=wildcards.division)
    output:
        "output/sensitivity/collective_model_sensitivity/collective_error_comparison_date_{date}_d_{division}.png",
        "output/sensitivity/collective_model_sensitivity/collective_model_metrics_date_{date}_d_{division}.png",
        "output/sensitivity/collective_model_sensitivity/collective_model_metrics_date_{date}_d_{division}.csv"
    shell:
        """
        Rscript {input} {output}
        """

rule simulate_depr:
    input:
        "src/depr.py",
        "data/population/pop_est2019_clean.csv",
        "output/gravity/pij/{collective_type}_date_{date}_d_{division}_pij.csv"
    output:
        "output/depr/{collective_type}/simulated_depr_date_{date}_d_{division}.csv"
    shell:
        """
        time python {input} {output}
        """

rule base_analytics:
    input:
        "src/base_analytics.py",
        "output/depr/{collective_type}/simulated_depr_date_{date}_d_{division}.csv"
    output:
        "output/analytics/base_analytics/{collective_type}/base_analytics_date_{date}_d_{division}.csv"
    shell:
        """
        python {input} {output}
        """

rule spatio_temporal_sensitivity:
    input:
        "src/plot_spatio_temporal_sensitivity.R",
        expand("output/gravity/check/departure-diffusion_exp_date_{date}_d_{division}_check.csv", date=DATES, division=DIVISIONS)
    output:
        "output/figs/spatiotemporal_r2_by_date_type.png",
        "output/figs/spatiotemporal_r2_by_month.png",
        "output/figs/spatiotemporal_error_metrics_summary.csv"
    shell:
        """
        Rscript  {input} {output}
        """

rule compare_privacy_construction:
    input:
        "src/privacy.py",
        f"output/depr/departure-diffusion_exp/simulated_depr_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv"
    output:
        f"output/analytics/k_anonymous/departure-diffusion_exp/k_anonymous_analytics_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/gdp/departure-diffusion_exp/gdp_analytics_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/naive_ldp/departure-diffusion_exp/naive_ldp_analytics_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/cms/departure-diffusion_exp/cms_analytics_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv"
    shell:
        """
        python {input} {output}
        """

rule plot_privacy_construction:
    input:
        "src/plot_privacy_construction.py",
        f"output/analytics/base_analytics/departure-diffusion_exp/base_analytics_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/k_anonymous/departure-diffusion_exp/k_anonymous_analytics_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/gdp/departure-diffusion_exp/gdp_analytics_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/naive_ldp/departure-diffusion_exp/naive_ldp_analytics_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/cms/departure-diffusion_exp/cms_analytics_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv"
    output:
        'output/figs/k_anonymity_construction.png',
        'output/figs/gdp_construction.png',
        'output/figs/naive_ldp_construction.png',
        'output/figs/cms_construction.png',
    shell:
        """
        python {input} {output}
        """

rule all_privacy_sensitivity:
    input:
        "src/calc_privacy_error.py",
        "output/analytics/base_analytics/departure-diffusion_exp/base_analytics_date_{date}_d_{division}.csv",
        lambda wildcards: expand("output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_date_{date}_d_{division}.csv", 
        construction="GDP",
        sensitivity=sensitivity_params["GDP"]["sensitivity"],
        epsilon=sensitivity_params["GDP"]["epsilon"],
        k="NA",
        m="NA",
        date=wildcards.date,
        division=wildcards.division),
        lambda wildcards: expand("output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_date_{date}_d_{division}.csv", 
        construction="naive_LDP",
        sensitivity=sensitivity_params["naive_LDP"]["sensitivity"],
        epsilon=sensitivity_params["naive_LDP"]["epsilon"],
        k="NA",
        m="NA",
        date=wildcards.date,
        division=wildcards.division),
        lambda wildcards: expand("output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_date_{date}_d_{division}.csv", 
        construction="CMS",
        sensitivity=sensitivity_params["CMS"]["sensitivity"],
        epsilon=sensitivity_params["CMS"]["epsilon"],
        k=sensitivity_params["CMS"]["k"],
        m=sensitivity_params["CMS"]["m"],
        date=wildcards.date,
        division=wildcards.division)
    output:
        "output/analytics/sensitivity/privacy_sensitivity_errors_date_{date}_d_{division}.csv",
        "output/analytics/sensitivity/privacy_sensitivity_date_{date}_d_{division}.csv"
    shell:
        "python {input} {output}"

rule apply_privacy:
    input:
        "src/privacy_sensitivity.py",
        "output/depr/departure-diffusion_exp/simulated_depr_date_{date}_d_{division}.csv"
    params:
        construction=lambda wildcards: wildcards.construction,
        epsilon=lambda wildcards: wildcards.epsilon,
        sensitivity=lambda wildcards: wildcards.sensitivity,
        k=lambda wildcards: wildcards.k,
        m=lambda wildcards: wildcards.m
    output:
        "output/analytics/sensitivity/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_date_{date}_d_{division}.csv"
    shell:
        """
        time python {input[0]} --infn {input[1]} --construction {params.construction} --epsilon {params.epsilon} --sensitivity {params.sensitivity} --k {params.k} --m {params.m} --outfn {output}
        """

rule plot_privacy_error:
    input: 
        "src/plot_privacy_error.R",
        f"output/analytics/sensitivity/privacy_sensitivity_errors_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        f"output/analytics/sensitivity/privacy_sensitivity_date_{FOCUS_DATE}_d_{FOCUS_DIVISION}.csv",
        "data/geo/2019_us_county_distance_matrix.csv"
    output:
        "output/figs/construction_epsilon_mape.png",
        "output/figs/construction_epsilon_ape_threshold.png",
        "output/figs/construction_epsilon_ape_threshold_full.png",
        "output/figs/construction_epsilon_freq_ape.png",
        "output/figs/construction_sensitivity_sensitivity.png",
        "output/figs/construction_m_k_sensitivity.png"
    shell:
        "Rscript {input} {output}"

rule cluster_counties:
    input:
        "src/cluster_counties.R",
        "data/geo/tl_2019_us_county/tl_2019_us_county.shp",
        "output/depr/departure-diffusion_exp/simulated_depr_date_2019_01_01_d_2.csv"
    output:
        "output/figs/counties_cluster_dendro.png",
        "output/figs/counties_cluster_area.png",
        "output/figs/counties_cluster_map.png",
        "output/space_time_scale/spatial_cluster_geoids.csv",
        "output/space_time_scale/spatial_cluster_mean_area.csv"
    shell:
        "Rscript {input} {output}"

def generate_dates(start_date, t):
    start = datetime.strptime(start_date, "%Y_%m_%d")
    return [(start + timedelta(days=d)).strftime("%Y_%m_%d") for d in range(int(t))]

rule agg_depr_space_time:
    input:
        script="src/agg_depr_space_time.py",
        geoid="output/space_time_scale/spatial_cluster_geoids.csv",
        depr=lambda wildcards: expand("output/depr/departure-diffusion_exp/simulated_depr_date_{date}_d_{division}.csv", 
            date=generate_dates(FOCUS_DATE, wildcards.t), division=FOCUS_DIVISION)
    params:
        space=lambda wildcards: wildcards.space,
        t=lambda wildcards: wildcards.t
    output:
        "output/space_time_scale/agg/simulated_depr_space_{space}_time_{t}.csv"
    shell:
        "python {input.script} {params.space} {params.t} {input.geoid} {input.depr} {output}"

rule apply_privacy_space_time:
    input:
        "src/privacy_sensitivity.py",
        "output/space_time_scale/agg/simulated_depr_space_{space}_time_{t}.csv"
    params:
        construction=lambda wildcards: wildcards.construction,
        epsilon=lambda wildcards: wildcards.epsilon,
        sensitivity=lambda wildcards: wildcards.sensitivity,
        k=lambda wildcards: wildcards.k,
        m=lambda wildcards: wildcards.m
    output:
        "output/space_time_scale/analytics/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_space_{space}_time_{t}.csv"
    shell:
        """
        time python {input[0]} --infn {input[1]} --construction {params.construction} --epsilon {params.epsilon} --sensitivity {params.sensitivity} --k {params.k} --m {params.m} --outfn {output}
        """

rule plot_privacy_error_space_time:
    input:
        "src/plot_privacy_error_space_time.R",
        "output/space_time_scale/spatial_cluster_mean_area.csv",
        expand("output/space_time_scale/agg/simulated_depr_space_{space}_time_{t}.csv", 
            space=SPACE_K,
            t=TIME_T),
        expand("output/space_time_scale/analytics/{construction}/{construction}_analytics_s_{sensitivity}_e_{epsilon}_k_{k}_m_{m}_space_{space}_time_{t}.csv", 
            construction=["CMS"],
            sensitivity=[1000],
            epsilon=[1, 5, 10, 15],
            k=[10_000],
            m=[4096],
            space=SPACE_K,
            t=TIME_T
        )
    output:
        "output/figs/spacetime_raster.png",
        "output/figs/time_agg_freq_mape.png",
        "output/figs/space_time_epsilon.png"
    shell:
        "Rscript {input} {output}"

# Utility rule to collect outputs from a remote server

rule download_output: # Download compressed output directory (execute locally)
    shell:
        f"scp -r {os.getenv('REMOTE_USER')}@{os.getenv('REMOTE_HOST')}:{os.getenv('REMOTE_OUTPUT_DIR')}/output output"
    
