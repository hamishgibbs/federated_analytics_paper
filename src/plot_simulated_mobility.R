suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(igraph)
})

if (interactive()) {
  .args <- c(
    "data/mobility/clean/daily_county2county_date_2019_04_08_clean.csv",
    "output/gravity/pij/departure-diffusion_exp_date_2019_04_08_d_2_pij.csv",
    "output/analytics/base_analytics/departure-diffusion_exp/base_analytics_date_2019_04_08_d_2.csv",
    "data/geo/2019_us_county_distance_matrix.csv",
    "output/figs/empirical_network_map.png",
    "output/figs/depr_network_map.png"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

.outputs <- tail(.args, 2)

empirical <- fread(.args[1], 
                   colClasses=c("geoid_o"="character", "geoid_d"="character"))
gravity <- fread(.args[2], 
                   colClasses=c("geoid_o"="character", "geoid_d"="character"))
depr <- fread(.args[3],
              colClasses=c("geoid_o"="character", "geoid_d"="character"))
dist <- fread(.args[4],
              colClasses=c("GEOID_origin"="character", "GEOID_dest"="character"))

# filter for states
states <- unique(substr(depr$geoid_o, 1, 2))

empirical <- empirical[
  substr(empirical$geoid_o, 1, 2) %in% states & 
  substr(empirical$geoid_d, 1, 2) %in% states, ]

dist <- dist[
  substr(dist$GEOID_origin, 1, 2) %in% states & 
  substr(dist$GEOID_dest, 1, 2) %in% states, ]

colnames(empirical) <- c("geoid_o", "geoid_d", "weight")
colnames(depr) <- c("geoid_o", "geoid_d", "weight")
empirical <- subset(empirical, weight > 0)
depr <- subset(depr, weight > 0)

g_empirical <- graph_from_data_frame(empirical, directed=F)
g_depr <- graph_from_data_frame(depr, directed=F)

empirical$betweenness <- edge_betweenness(g_empirical)
depr$betweenness <- edge_betweenness(g_depr)

dist[empirical, 
     on=c("GEOID_origin" = "geoid_o", "GEOID_dest" = "geoid_d"), 
     empirical_weight := weight]

dist[depr, 
     on=c("GEOID_origin" = "geoid_o", "GEOID_dest" = "geoid_d"), 
     depr_weight := weight]
dist[is.na(dist)] <- 0
dist[, empirical_pij := empirical_weight / sum(empirical_weight, na.rm=T)]
dist[, depr_pij := depr_weight / sum(depr_weight, na.rm=T)]

dist <- subset(dist, GEOID_origin != GEOID_dest)

dist <- dist[order(empirical_pij)]
dist[, id := rev(.I)]

dist_empirical <- dist[, .(lng_origin, lat_origin, lng_dest, lat_dest, id, empirical_pij)]
dist_empirical[, pij := empirical_pij]
dist_depr <- dist[, .(lng_origin, lat_origin, lng_dest, lat_dest, id, depr_pij)]
dist_depr[, pij := depr_pij]

plot_pij_network <- function(dist, title, zoom_y, zoom_x, color){
  
  ymin <- min(c(dist$lat_origin, dist$lat_dest))
  ymax <- max(c(dist$lat_origin, dist$lat_dest))
  xmin <- min(c(dist$lng_origin, dist$lng_dest))
  xmax <- max(c(dist$lng_origin, dist$lng_dest))
  
  ggplot(dist_depr) + 
    ggutils::plot_basemap(countryname="United States of America",
                          world_fill="white",
                          country_fill = "white") + 
    geom_segment(aes(
      x = lng_origin, y = lat_origin, 
      xend = lng_dest, yend = lat_dest, 
      size=pij), color=color, alpha=0.8) + 
    scale_size_continuous(range=c(0.001, 0.5)) + 
    ylim(c(ymin*(1-zoom_y), ymax*(1+zoom_y))) + 
    xlim(c(xmin*(1+zoom_x), xmax*(1-zoom_x))) + 
    theme_void() + 
    theme(legend.position="none") + 
    labs(title=title)
}

zoom_y <- 0.005
zoom_x <- 0.005
p_empirical <- plot_pij_network(dist_empirical, NULL, zoom_y, zoom_x, "black")
p_depr <- plot_pij_network(dist_depr, NULL, zoom_y, zoom_x, "red")

ggsave(.outputs[1],
       p_empirical,
       width=10,
       height=5, 
       units="in")  

ggsave(.outputs[2],
       p_depr,
       width=10,
       height=5, 
       units="in")  

dist_empirical

# d-epr to empirical comparison
dist[gravity, on=c("GEOID_origin"="geoid_o", "GEOID_dest"="geoid_d"), gravity_pij := value]
dist[, gravity_pij := gravity_pij / sum(gravity_pij)]

dist <- dist[order(distance)]
dist[, id := .I]

# Compare gravity with depr distance kernel
ggplot(dist) + 
  geom_point(aes(x = distance, y = gravity_pij), color="blue", size=0.2) + 
  geom_point(aes(x = distance, y = depr_pij), color="red", size=0.2) + 
  scale_y_continuous(trans="pseudo_log", labels=scales::comma) + 
  scale_x_continuous(trans="pseudo_log")

ggplot() + 
  geom_point(data=dist_empirical, aes(x = id, y = pij), size=0.2) + 
  geom_point(data=dist_depr, aes(x = id, y = pij), color='red', size=0.2) + 
  scale_y_continuous(trans="log10", labels=scales::comma) + 
  scale_x_continuous(trans="log10")

