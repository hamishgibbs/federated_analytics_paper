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
