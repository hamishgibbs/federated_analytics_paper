#%%
import sys
import numpy as np
from plotnine import *
import pandas as pd
import patchworklib as pw

if len(sys.argv) > 2:
    _args = sys.argv[1:]
else:
    _args = [
        "../output/analytics/base_analytics/departure-diffusion_exp/base_analytics_date_2019_01_01_d_2.csv",
        "../output/analytics/k_anonymous/departure-diffusion_exp/k_anonymous_analytics_date_2019_01_01_d_2.csv",
        "../output/analytics/gdp/departure-diffusion_exp/gdp_analytics_date_2019_01_01_d_2.csv",
        "../output/analytics/naive_ldp/departure-diffusion_exp/naive_ldp_analytics_date_2019_01_01_d_2.csv",
        "../output/analytics/cms/departure-diffusion_exp/cms_analytics_date_2019_01_01_d_2.csv",
        '../output/figs/k_anonymity_construction.png',
        '../output/figs/gdp_construction.png',
        '../output/figs/naive_ldp_construction.png',
        '../output/figs/cms_construction.png',
    ]

_outputs = _args[-4:]

# %%
base = pd.read_csv(_args[0], dtype={'geoid_o': str, 'geoid_d': str})
k_anonymous = pd.read_csv(_args[1], dtype={'geoid_o': str, 'geoid_d': str}).rename(columns={'count': 'count_k_anonymous'})
gdp = pd.read_csv(_args[2], dtype={'geoid_o': str, 'geoid_d': str}).rename(columns={'count': 'count_gdp'})
ldp = pd.read_csv(_args[3], dtype={'geoid_o': str, 'geoid_d': str}).rename(columns={'count': 'count_ldp'})
cms = pd.read_csv(_args[4], dtype={'geoid_o': str, 'geoid_d': str}).rename(columns={'count': 'count_cms'})

# truncate negative values to 0
gdp['count_gdp'] = gdp['count_gdp'].clip(lower=0)
ldp['count_ldp'] = ldp['count_ldp'].clip(lower=0)
cms['count_cms'] = cms['count_cms'].clip(lower=0)
# %%
base.sort_values(by='count', inplace=True, ascending=False)
base['id'] = range(1, base.shape[0] + 1)
# %%
base = pd.merge(base, k_anonymous, on=['geoid_o', 'geoid_d'], how='left',  validate='one_to_one')
base = pd.merge(base, gdp, on=['geoid_o', 'geoid_d'], how='left',  validate='one_to_one')
base = pd.merge(base, ldp, on=['geoid_o', 'geoid_d'], how='left',  validate='one_to_one')
base = pd.merge(base, cms, on=['geoid_o', 'geoid_d'], how='left',  validate='one_to_one')

#%%
# Compute pull values for manuscript
top_percentage = 0.99
threshold = base['id'].quantile(1 - top_percentage)
base['id_top_thresh'] = base['id'] < threshold
base['ape_count_gdp'] = np.abs(base['count'] - base['count_gdp']) / base['count']
base['ape_count_ldp'] = np.abs(base['count'] - base['count_ldp']) / base['count']
base['ape_count_cms'] = np.abs(base['count'] - base['count_cms']) / base['count']

print(base.groupby('id_top_thresh')[['ape_count_gdp', 'ape_count_ldp', 'ape_count_cms']].mean() * 100)
print("N top threshold:", base['id_top_thresh'].sum())
print("N bottom threshold:", base.shape[0] - base['id_top_thresh'].sum())
#%%
k_anonymity_suppressed = base[pd.isna(base['count_k_anonymous'])]
print(f"K-anonymity suppressed: {1-(k_anonymity_suppressed.shape[0] / base.shape[0]):%} OD pairs,  {1-(k_anonymity_suppressed['count'].sum() / base['count'].sum()):%} trips")

# %%
base_long = pd.melt(base, id_vars=['id', 'geoid_o', 'geoid_d', 'count'], value_vars=['count_k_anonymous', 'count_gdp', 'count_ldp', 'count_cms'], var_name='mechanism')
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
            y = "Number of trips (log scale)") + 
            theme_classic() + 
            theme(axis_text_x=element_blank(),
                axis_ticks_major_x=element_blank())
        )
# %%
pb = plot_privacy(base_long, 'count_gdp', ymin=0)
pc = plot_privacy(base_long, 'count_ldp', ymin=0)
pd = plot_privacy(base_long, 'count_cms', ymin=0)
# %%
trunc_thresh = 100
pb_trunc = plot_privacy(base_long.loc[base_long['count'] > trunc_thresh], 'count_gdp', ymin=trunc_thresh)
pc_trunc = plot_privacy(base_long.loc[base_long['count'] > trunc_thresh], 'count_ldp', ymin=trunc_thresh)
pd_trunc = plot_privacy(base_long.loc[base_long['count'] > trunc_thresh], 'count_cms', ymin=trunc_thresh)
# %%
width = 7
height = 4

pa.save(_outputs[0], width=width, height=height, dpi=300)
pb.save(_outputs[1], width=width, height=height, dpi=300)
pc.save(_outputs[2], width=width, height=height, dpi=300)
pd.save(_outputs[3], width=width, height=height, dpi=300)
