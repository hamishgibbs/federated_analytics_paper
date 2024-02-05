#%%
import sys
import numpy as np
from plotnine import *
import pandas as pd
# %%
if len(sys.argv) > 1:
    _args = sys.argv[1:]
else:
    _args = [
        '../output/figs/k_anonymity_example.png',
        '../output/figs/gdp_naive_example.png',
        '../output/figs/ldp_naive_example.png'
    ]
# %%
data = [1, 0, 2, 4, 5, 6, 4, 2, 0, 1]
df = pd.DataFrame({"count": data,
                   "id": range(len(data))})
# %%
epsilon = 2.0
sensitivity = 1

def add_laplace_noise(count, epsilon, sensitivity):
    scale = sensitivity / epsilon
    noise = np.random.laplace(0, scale)
    return count + noise

df['dp_count_naive'] = df['count'].apply(lambda x: add_laplace_noise(x, epsilon, sensitivity))

df = pd.melt(df, id_vars=['id'], value_vars=['count', 'dp_count_naive'])
# %%
# k-anonymity example with hline - red annotations
df_kanon = df[[x in ['count'] for x in df['variable']]]
df_kanon['value'] = df_kanon['value'].apply(lambda x: 0 if x < 2 else x)

p = (ggplot(df_kanon) +
 geom_bar(aes(x='id', y='value', fill='variable'), stat='identity', position='dodge') + 
 geom_hline(yintercept=0, size=0.5) +
 geom_hline(yintercept=2, linetype='dashed', size=0.5) +
 scale_fill_manual(values=('black', '#8f7cc3')) + 
 theme_void() + 
 theme(legend_position='none')
)
p
# save to png file
p.save(_args[0], width=6, height=1, dpi=300)

# %%
p = (ggplot(df[[x in ['count', 'dp_count_naive'] for x in df['variable']]]) +
 geom_bar(aes(x='id', y='value', fill='variable'), stat='identity', position='dodge') + 
 geom_hline(yintercept=0, size=0.5) +
 scale_fill_manual(values=('black', '#8f7cc3')) + 
 theme_void() + 
 theme(legend_position='none')
)

# save to png file
p.save(_args[1], width=5, height=1.2, dpi=300)

# %%
# two local dps (smaller)
data1 = [1, 0, 2, 0, 2, 1, 4, 2, 0, 1]
data2 = [1, 2, 4, 3, 2, 1, 2, 1, 0, 1]
df = pd.DataFrame({"count": data1 + data2,
                    "uid": ['1']*len(data1) + ['2']*len(data2),
                   "id": list(range(len(data1))) + list(range(len(data2)))})
df['dp_count'] = df['count'].apply(lambda x: add_laplace_noise(x, epsilon, sensitivity))

df = pd.melt(df, id_vars=['id', 'uid'], value_vars=['count', 'dp_count'])

df

# %%
p = (ggplot(df) +
 geom_bar(aes(x='id', y='value', fill='variable'), stat='identity', position='dodge') + 
 geom_hline(yintercept=0, size=0.5) +
 scale_fill_manual(values=('black', '#8f7cc3')) + 
 facet_wrap('uid', nrow=2) +
 theme_void() + 
 theme(legend_position='none',
 strip_text=element_blank())
)

p.save(_args[2], width=5, height=1.2, dpi=300)