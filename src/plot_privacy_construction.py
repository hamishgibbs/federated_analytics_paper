#%%
import sys
import numpy as np
from plotnine import *
import pandas as pd
import matplotlib.pyplot as plt


if len(sys.argv) > 2:
    _args = sys.argv[1:]
else:
    _args = [
        "../output/analytics/base_analytics/departure-diffusion_exp/base_analytics_date_2019_04_08_d_2.csv",
        "../output/analytics/k_anonymous/departure-diffusion_exp/k_anonymous_analytics_date_2019_04_08_d_2.csv",
        "../output/analytics/sensitivity/GDP/GDP_analytics_s_10_e_1_k_NA_m_NA_date_2019_04_08_d_2.csv",
        "../output/analytics/sensitivity/CMS/CMS_analytics_s_10_e_5_k_20_m_2340_date_2019_04_08_d_2.csv",
        '../output/figs/k_anonymity_construction.png',
        '../output/figs/gdp_construction.png',
        '../output/figs/cms_construction.png',
    ]

_outputs = _args[-3:]

# %%
base = pd.read_csv(_args[0], dtype={'geoid_o': str, 'geoid_d': str})
k_anonymous = pd.read_csv(_args[1], dtype={'geoid_o': str, 'geoid_d': str}).rename(columns={'count': 'count_k_anonymous'})
gdp = pd.read_csv(_args[2], dtype={'geoid_o': str, 'geoid_d': str}).rename(columns={'count': 'count_gdp'})
cms = pd.read_csv(_args[3], dtype={'geoid_o': str, 'geoid_d': str}).rename(columns={'count': 'count_cms'})
# %%
base.sort_values(by='count', inplace=True, ascending=False)
base['id'] = range(1, base.shape[0] + 1)
# %%
base = pd.merge(base, k_anonymous, on=['geoid_o', 'geoid_d'], how='left',  validate='one_to_one')
base = pd.merge(base, gdp, on=['geoid_o', 'geoid_d'], how='left',  validate='one_to_one')
base = pd.merge(base, cms, on=['geoid_o', 'geoid_d'], how='left',  validate='one_to_one')

#%%
# Compute pull values for manuscript
# Suppression with k-anonymity

base_k_anonymous_suppressed = base[pd.isna(base['count_k_anonymous'])]

od_pairs_suppressed_k_anonymous = 1- (base_k_anonymous_suppressed.shape[0] / base.shape[0])
trips_suppressed_k_anonymous = 1- (base_k_anonymous_suppressed['count'].sum() / base['count'].sum())
print(f"K-anonymity retained: {od_pairs_suppressed_k_anonymous:.2%} OD pairs,  {trips_suppressed_k_anonymous:.2%} trips")

base['ape_count_gdp'] = np.abs(base['count'] - base['count_gdp']) / base['count']
base['ape_count_cms'] = np.abs(base['count'] - base['count_cms']) / base['count']

accuracy_threshold = 0.1

base_gdp_suppressed = base[base['ape_count_gdp'] > accuracy_threshold]

od_pairs_suppressed_gdp = 1-(base_gdp_suppressed.shape[0] / base.shape[0])
trips_suppressed_gdp = 1-(base_gdp_suppressed['count'].sum() / base['count'].sum())
print(f"GDP retained: {od_pairs_suppressed_gdp:.2%} OD pairs,  {trips_suppressed_gdp:.2%} trips")

base_cms_suppressed = base[base['ape_count_cms'] > accuracy_threshold]

od_pairs_suppressed_cms = 1-(base_cms_suppressed.shape[0] / base.shape[0])
trips_suppressed_cms = 1-(base_cms_suppressed['count'].sum() / base['count'].sum())
print(f"CMS retained: {od_pairs_suppressed_cms:.2%} OD pairs,  {trips_suppressed_cms:.2%} trips")

# truncate negative values to 0
gdp['count_gdp'] = gdp['count_gdp'].clip(lower=0)
cms['count_cms'] = cms['count_cms'].clip(lower=0)

#%%
k_anonymity_suppressed = base[pd.isna(base['count_k_anonymous'])]
print(f"K-anonymity suppressed: {1-(k_anonymity_suppressed.shape[0] / base.shape[0]):%} OD pairs,  {1-(k_anonymity_suppressed['count'].sum() / base['count'].sum()):%} trips")

# %%
base_long = pd.melt(base, id_vars=['id', 'geoid_o', 'geoid_d', 'count'], value_vars=['count_k_anonymous', 'count_gdp', 'count_cms'], var_name='mechanism')
# %%
start_exp=0
max_value = base_long['value'].max(skipna=True)
end_exp = np.log10(max_value) 

pa = (ggplot(base_long.loc[base_long['mechanism'] == 'count_k_anonymous']) + 
 geom_point(aes(x='id', y='count'), color='blue', size=0.1) + 
 geom_point(aes(x='id', y='value'), color='red', size=0.1) + 
 geom_hline(yintercept=10, color='black', linetype='dashed') +
 scale_y_continuous(trans='pseudo_log', limits=[base_long['value'].min(skipna=True), base_long['value'].max(skipna=True)],
                    breaks = [0] + [10**x for x in range(0, int(end_exp)+2)]) + 
 scale_x_continuous(trans='pseudo_log') + 
 labs(x = "Origin-destination pair (log scale)",
      y = "Number of trips (log scale)") + 
    theme_classic() + 
    theme(axis_text_x=element_blank(),
          axis_ticks_major_x=element_blank())
)
# %%
def plot_privacy(data, mechanism, ymin):

    return (ggplot(data.loc[base_long['mechanism'] == mechanism]) + 
        geom_point(aes(x='id', y='value'), color='red', size=0.1) + 
        geom_point(aes(x='id', y='count'), color='blue', size=0.1) + 
        scale_y_continuous(trans='pseudo_log', limits=[ymin, base_long['value'].max(skipna=True)],
                           breaks = [0] + [10**x for x in range(0, int(end_exp)+2)]) + 
        scale_x_continuous(trans='pseudo_log') + 
        labs(x = "Origin-destination pair (log scale)",
            y = "") + 
            theme_classic() + 
            theme(axis_text_x=element_blank(),
                axis_ticks_major_x=element_blank())
        )
# %%
pb = plot_privacy(base_long, 'count_gdp', ymin=0)
pc = plot_privacy(base_long, 'count_cms', ymin=0)
# %%
width = 4.5
height = 5

pa.save(_outputs[0], width=width, height=height, dpi=300)
pb.save(_outputs[1], width=width, height=height, dpi=300)
pc.save(_outputs[2], width=width, height=height, dpi=300)

# %%
