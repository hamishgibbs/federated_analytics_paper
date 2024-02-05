#%%
import sys
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon
from mpl_toolkits.mplot3d import Axes3D
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from matplotlib.ticker import FuncFormatter
import geopandas as gpd

# %%
if len(sys.argv) > 1:
    _args = sys.argv[1:]
else:
    _args = [
        "../data/geo/tl_2019_us_county/tl_2019_us_county.shp",
        '../output/figs/spacetime_prism.png'
    ]

# %%
shapefile = gpd.read_file(_args[0])
counties = ['42101', '42017', '42045', '42091']
counties = shapefile[[x in counties for x in shapefile['GEOID']]]
county_polys = [list(x.exterior.coords) for x in counties['geometry']]
# %%
type(list(shapefile[shapefile['STATEFP'] == "42"]['geometry'])[0])
# %%
ys = []
xs = []
for x in county_polys:
    for coord in x:
        ys.append(coord[1])
        xs.append(coord[0])
# %%
places = np.array([
    (-75.172462, 40.198047),
    (-75.128977, 40.311564),
    (-75.314389, 40.022198)
])
visits = np.array([
    (0, 0),
    (0, 6),
    (1, 7),
    (1, 14),
    (2, 15),
    (2, 19),
    (0, 20),
    (0, 24)
])
x = [places[x[0]][0] for x in visits]
y = [places[x[0]][1] for x in visits]
z = [x[1] for x in visits]

lines = []
for i in range(len(places)):
    lines.append([
        [places[i][0], places[i][0]],
        [places[i][1], places[i][1]],
        [0, np.max(visits[:, 1][visits[:, 0] == i])]
    ])
# %%
def time_formatter(x, pos):
    hours = int(x)
    minutes = int((x - hours) * 60)
    return f'{hours:02d}:{minutes:02d}'
# %%
fig = plt.figure()
ax = fig.add_subplot(111, projection='3d')

# Scatter plot
ax.scatter(x, y, z, color='black', alpha=1)

ax.plot(x, y, z, color='red')

x_line = x[0]
y_line = y[0]
z_min = min(z) - 1
z_max = 24

for line in lines:
    ax.plot(line[0], line[1], line[2],
            color='black', 
            linestyle='dashed', 
            linewidth=0.7, 
            alpha=0.5)

z_plane = min(z_min, np.min(z)) 
for poly in county_polys:
    poly3d = [[x, y, z_plane] for x, y in poly]
    polygon = Poly3DCollection([poly3d], alpha=0, edgecolors='k', linewidths=0.5, facecolor="white")  # Black outline
    ax.add_collection3d(polygon)


ax.set_zlim([z_plane, max(z_max, 24)])

ax.set_xlabel('')
ax.set_ylabel('')
ax.set_zlabel('')

ax.set_title('')

ax.grid(False)
ax.xaxis.pane.fill = False
ax.yaxis.pane.fill = False
ax.zaxis.pane.fill = False
ax.xaxis.pane.set_edgecolor('black')
ax.yaxis.pane.set_edgecolor('black')
ax.zaxis.pane.set_edgecolor('black')

ax.set_xlim([np.min(xs), np.max(xs)])
ax.set_ylim([np.min(ys), np.max(ys)])
ax.set_zlim([0, 24])

ax.set_xticklabels([])
ax.set_yticklabels([])

ax.set_xticks([])
ax.set_yticks([])

ax.set_zticks([])

ax.zaxis.set_major_formatter(FuncFormatter(time_formatter))

fig.subplots_adjust(left=0.1, right=0.9, bottom=0.1, top=0.9)

ax.view_init(elev=25., azim=300-180)

ax.set_box_aspect((1.1, 1.1, 1.5))

fig.set_size_inches(6, 10)


plt.savefig(_args[-1], dpi=300)
