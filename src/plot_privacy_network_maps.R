suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(igraph)
})

if (interactive()) {
  .args <- c(
    "output/analytics/sensitivity/privacy_sensitivity_errors_date_2019_04_08_d_2.csv",
    "data/geo/2019_us_county_distance_matrix.csv",
    "output/figs/privacy_acceptable_error_map.png"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

.outputs <- tail(.args, 1)
errors <- fread(.args[1],
                colClasses=c("geoid_o"="character", "geoid_d"="character"))
errors[, construction := ifelse(construction == "GDP", "CDP", construction)]

dist <- fread(.args[2],
              colClasses=c("GEOID_origin"="character", "GEOID_dest"="character"))


# Select representative examples of the CDP and CMS mechanisms
errors_gdp <- subset(errors, 
                     construction == "CDP" & epsilon == 1 & sensitivity == 10
)

errors_cms <- subset(errors, 
                     construction == "CMS" & epsilon == 5 & sensitivity == 10 & 
                       k == 205 & m == 2340
)

# Filter distance matrix for states
states <- unique(substr(errors_gdp_cms_comparison$geoid_o, 1, 2))
dist <- dist[
  substr(dist$GEOID_origin, 1, 2) %in% states & 
    substr(dist$GEOID_dest, 1, 2) %in% states, ]


# Construct networks for comparison
true_network <- unique(errors_gdp[, .(geoid_o, geoid_d, count)])

gdp_network <- subset(
  errors_gdp, absolute_percentage_error <= 10)[, 
  .(geoid_o, geoid_d, count_private)]

cms_network <- subset(
  errors_cms, absolute_percentage_error <= 10)[, 
  .(geoid_o, geoid_d, count_private)]

# Join travel volumes onto distance matrix
dist[true_network,
     on=c("GEOID_origin" = "geoid_o", "GEOID_dest" = "geoid_d"), 
     count_true := count]
dist[gdp_network,
     on=c("GEOID_origin" = "geoid_o", "GEOID_dest" = "geoid_d"), 
     count_gdp := count_private]
dist[cms_network,
     on=c("GEOID_origin" = "geoid_o", "GEOID_dest" = "geoid_d"), 
     count_cms := count_private]

zoom_y <- 0.005
zoom_x <- 0.005

ymin <- min(c(dist$lat_origin, dist$lat_dest))
ymax <- max(c(dist$lat_origin, dist$lat_dest))
xmin <- min(c(dist$lng_origin, dist$lng_dest))
xmax <- max(c(dist$lng_origin, dist$lng_dest))

p_gdp <- ggplot(subset(dist, !is.na(count_true))) + 
  ggutils::plot_basemap(countryname="United States of America",
                        world_fill="white",
                        country_fill = "white") + 
  geom_segment(aes(
    x = lng_origin, y = lat_origin, 
    xend = lng_dest, yend = lat_dest, 
    size=count_true/sum(count_true)), color="black") +
  geom_segment(aes(
    x = lng_origin, y = lat_origin, 
    xend = lng_dest, yend = lat_dest, 
    size=count_gdp/sum(count_true)), color="red") +
  scale_size_continuous(range=c(0.001, 0.8)) + 
  ylim(c(ymin*(1-zoom_y), ymax*(1+zoom_y))) + 
  xlim(c(xmin*(1+zoom_x), xmax*(1-zoom_x))) + 
  theme_void() + 
  theme(legend.position="none") + 
  labs(title='a')


p_cms <- ggplot(subset(dist, !is.na(count_true))) + 
  ggutils::plot_basemap(countryname="United States of America",
                        world_fill="white",
                        country_fill = "white") + 
  geom_segment(aes(
    x = lng_origin, y = lat_origin, 
    xend = lng_dest, yend = lat_dest, 
    size=count_true/sum(count_true)), color="black") +
  geom_segment(aes(
    x = lng_origin, y = lat_origin, 
    xend = lng_dest, yend = lat_dest, 
    size=count_cms/sum(count_true)), color="red") +
  scale_size_continuous(range=c(0.001, 0.8)) + 
  ylim(c(ymin*(1-zoom_y), ymax*(1+zoom_y))) + 
  xlim(c(xmin*(1+zoom_x), xmax*(1-zoom_x))) + 
  theme_void() + 
  theme(legend.position="none") + 
  labs(title='b')

p <- cowplot::plot_grid(p_gdp, p_cms)

ggsave(.outputs[1],
       p,
       width=10,
       height=5.5, 
       units="in")


