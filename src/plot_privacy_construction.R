suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

if (interactive()) {
  .args <- c(
    "output/analytics/sensitivity/privacy_sensitivity_errors_date_2019_04_08_d_2.csv",
    "output/analytics/k_anonymous/departure-diffusion_exp/k_anonymous_analytics_date_2019_04_08_d_2.csv",
    "output/figs/construction_comparison.png"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

.outputs <- tail(.args, 1)

errors <- fread(.args[1])

error_cols <- c('weight', 'squared_error',
                'weighted_squared_error', 'absolute_percentage_error',
                'weighted_absolute_percentage_error')
errors[, (error_cols) := NULL]
errors[, construction := ifelse(construction == "GDP", "CDP", construction)]
errors[, count := as.integer(count)]
errors[, count_private := as.integer(count_private)]

k_anon <- fread(.args[2])
k_anon[, count := as.integer(count)]
errors[, count_private := as.integer(count_private)]

# Select representative examples of the CDP and CMS mechanisms
errors_gdp <- subset(errors, 
                     construction == "CDP" & epsilon == 1 & sensitivity == 10
)

errors_cms <- subset(errors, 
                     construction == "CMS" & epsilon == 5 & sensitivity == 10 & 
                       k == 205 & m == 2340
)

errors_gdp_cms_comparison <- rbind(errors_gdp, errors_cms)
param_cols <- c('epsilon', 'sensitivity', 'm', 'k')
errors_gdp_cms_comparison[, (param_cols) := NULL]

# Compute origin-destination pair frequency rank based on true count
od_counts <- unique(errors[, .(geoid_o, geoid_d, count)])
od_counts <- od_counts[order(-count)]
od_counts[, id := .I]

# Format k-anonymity data for comparison
colnames(k_anon) <- c('geoid_o', 'geoid_d', 'count_private')

k_anon_full <- od_counts[, .(geoid_o, geoid_d, count)]
k_anon <- k_anon_full[k_anon, on=c('geoid_o', 'geoid_d'), count_private := count_private]
k_anon[, construction := 'K-anonymity']

# Combine all three privacy mechanisms
errors_comparison <- rbind(errors_gdp_cms_comparison, k_anon)

# Assign frequency ranks
errors_comparison[od_counts, on=c("geoid_o", "geoid_d"), id := id]
k_anon[od_counts, on=c("geoid_o", "geoid_d"), id := id]

# Pivot data to compare private counts with true counts
errors_comparison_long <- melt(errors_comparison, 
     id.vars = c("geoid_o", "geoid_d", "construction", "id"),
     variable.name = "privacy")

errors_comparison_long[, construction := factor(
  construction,
  levels=c("K-anonymity", "CDP", "CMS"),
  labels=c("K-anonymity",
           "Central DP",
           "Local DP (CMS)"))]

k_anon[, construction := factor(
  construction,
  levels=c("K-anonymity", "CDP", "CMS"),
  labels=c("K-anonymity",
           "Central DP",
           "Local DP (CMS)"))]

errors_comparison_long[, privacy := factor(
  privacy,
  levels=c("count", "count_private"),
  labels=c("True value",
           "Privatised value"))]

k_anon[, privacy := factor(
  "count_private",
  levels=c("count_private"),
  labels=c("Privatised value"))]

p <- ggplot(subset(errors_comparison_long, !is.na(value))) + 
  geom_point(aes(x = id, y = pmax(value, 0), color=privacy),
             size=0.1) + 
  geom_point(data=k_anon, aes(x = id, y=count_private, color=privacy),
             size=0.1) + 
  geom_hline(data = subset(errors_comparison_long, construction == "K-anonymity" & !is.na(value)),
             aes(yintercept = 10), color = "black", linetype='dashed', size=0.2) +
  facet_wrap(~construction, nrow=2) + 
  scale_y_continuous(trans="log10", labels = scales::comma,
                     breaks=c(0.1, 1, 10, 100, 1000, 10000)) + 
  scale_color_manual(values = c("Privatised value" = "red", "True value" = "blue")) +
  theme_classic() + 
  theme(legend.position = c(0.75, 0.22),
        strip.background = element_rect(size=0),
        strip.text = element_text(face='bold')) + 
  scale_x_continuous(trans="log10", 
                     breaks=c(1, max(errors_comparison_long$id)),
                     labels = c("High", "Low")) + 
  labs(color="Privacy",
       x = expression(paste("Origin-destination pair frequency rank (", log[10], " scale)")),
       y = expression(paste("Number of trips (", log[10], " scale)")))

ggsave(.outputs[1],
       p,
       width=8,
       height=6, 
       units="in")