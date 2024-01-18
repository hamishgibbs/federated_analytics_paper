suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

if (interactive()) {
  .args <- c(
    "data/mobility/clean/daily_county2county_2019_01_01_clean.csv",
    "output/analytics/base_analytics/gravity_transport/base_analytics_2019_01_01.csv",
    "data/geo/2019_us_county_distance_matrix.csv",
    "output/gravity/diagnostic/gravity_transport_2019_01_01_error.rds",
    "output/sensitivity/collective_model_sensitivity/collective_model_metrics_2019_01_01.png"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

.outputs <- tail(.args, 1)

empirical <- fread(.args[1], 
                   colClasses=c("geoid_o"="character", "geoid_d"="character"))
depr <- fread(.args[2],
              colClasses=c("geoid_o"="character", "geoid_d"="character"))
dist <- fread(.args[3],
              colClasses=c("GEOID_origin"="character", "GEOID_dest"="character"))

p_empirical <- readr::read_rds(.args[4])

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

p_depr <- ggplot(all_counties_long) + 
  geom_point(aes(x = id, y = value, color=variable), size=0.2) + 
  scale_y_continuous(trans="log10", labels = scales::comma) + 
  scale_x_continuous(trans="log10") + 
  scale_color_manual(values=c("black", "red")) + 
  labs(title="d-EPR",
       y = "P(i,j)",
       x = "Origin-Destination Pair") + 
  theme_classic() + 
  theme(legend.position = "none")

p <- cowplot::plot_grid(p_empirical + theme(legend.position = "none"), 
                   p_depr, nrow = 1)

ggsave(.outputs[1],
       p,
       width=10,
       height=6, 
       units="in")  
