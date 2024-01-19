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