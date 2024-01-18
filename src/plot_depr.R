suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(igraph)
})

if (interactive()) {
  .args <- c(
    "data/mobility/clean/daily_county2county_2019_01_01_clean.csv",
    "output/analytics/base_analytics/gravity_transport/base_analytics_2019_01_01.csv",
    "data/geo/2019_us_county_distance_matrix.csv",
    ""
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

empirical <- fread(.args[1], 
                   colClasses=c("geoid_o"="character", "geoid_d"="character"))
depr <- fread(.args[2],
              colClasses=c("geoid_o"="character", "geoid_d"="character"))
dist <- fread(.args[3],
              colClasses=c("GEOID_origin"="character", "GEOID_dest"="character"))

# filter for states
states <- unique(substr(depr$geoid_o, 1, 2))

empirical <- empirical[
  substr(empirical$geoid_o, 1, 2) %in% states & 
  substr(empirical$geoid_d, 1, 2) %in% states, ]

dist <- dist[
  substr(dist$GEOID_origin, 1, 2) %in% states & 
  substr(dist$GEOID_dest, 1, 2) %in% states, ]

all_counties <- unique(c(
  empirical$geoid_o,
  empirical$geoid_d,
  depr$geoid_o,
  depr$geoid_o))

all_counties <- data.table(gtools::permutations(n=length(all_counties), r=2, v=all_counties, repeats.allowed = T))
colnames(all_counties) <- c("geoid_o", "geoid_d")
all_counties <- all_counties[order(geoid_o, geoid_d)]

all_counties[empirical, on=c("geoid_o", "geoid_d"), empirical := pop_flows]
all_counties[depr, on=c("geoid_o", "geoid_d"), depr := count]

all_counties[is.na(all_counties)] <- 0

all_counties[, empirical := empirical / sum(empirical)]
all_counties[, depr := depr / sum(depr)]

all_counties <- all_counties[order(empirical)]
all_counties[, id := rev(.I)]

all_counties_long <- melt(all_counties, id.vars = c('geoid_o', 'geoid_d', 'id'))

p <- ggplot(all_counties_long) + 
  geom_point(aes(x = id, y = value, color=variable), size=0.2) + 
  scale_y_continuous(trans="log10", labels = scales::comma) + 
  scale_x_continuous(trans="log10") + 
  scale_color_manual(values=c("black", "red")) + 
  labs(title=basename(.outputs[3]),
       y = "P(i,j)",
       x = "Origin-Destination Pair") + 
  theme_classic()  

# looks to me like dEPR is just reflecting error in the gravity model.
# Could be much worse than this
p

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
     empirical_btw := betweenness]
dist[empirical, 
     on=c("GEOID_origin" = "geoid_o", "GEOID_dest" = "geoid_d"), 
     empirical_weight := weight]

dist[depr, 
     on=c("GEOID_origin" = "geoid_o", "GEOID_dest" = "geoid_d"), 
     depr_btw := betweenness]
dist[depr, 
     on=c("GEOID_origin" = "geoid_o", "GEOID_dest" = "geoid_d"), 
     depr_weight := weight]
dist[is.na(dist)] <- 0
dist[, empirical_pij := empirical_weight / sum(empirical_weight, na.rm=T)]
dist[, depr_pij := depr_weight / sum(depr_weight, na.rm=T)]

dist <- subset(dist, GEOID_origin != GEOID_dest)
dist

ggplot(dist) + 
  geom_segment(aes(
    x = lng_origin, y = lat_origin, 
    xend = lng_dest, yend = lat_dest, 
    size=empirical_pij)) + 
  scale_size_continuous(range=c(0.001, 0.5))

ggplot(dist) + 
  geom_segment(aes(
    x = lng_origin, y = lat_origin, 
    xend = lng_dest, yend = lat_dest, 
    size=depr_pij)) + 
  scale_size_continuous(range=c(0.001, 0.5))
  