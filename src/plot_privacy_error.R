suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

if (interactive()) {
  .args <- c(
    "output/analytics/sensitivity/privacy_sensitivity_errors_date_2019_04_08_d_2.csv",
    "output/analytics/sensitivity/privacy_sensitivity_date_2019_04_08_d_2.csv",
    "data/geo/2019_us_county_distance_matrix.csv",
    "output/figs/construction_error.png",
    "output/figs/construction_error_freq.png",
    "output/figs/cms_parameter_sesitivity.png"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

.outputs <- tail(.args, 3)

errors <- fread(.args[1])
error_metrics <- fread(.args[2])
distance <- fread(.args[3])

abs_error_quantiles_by_groups <- function(data, groups){
  data[, .(
    q90_upper = quantile(abs(error), 0.95, na.rm = TRUE),
    q90_lower = quantile(abs(error), 0.05, na.rm = TRUE),
    q70_upper = quantile(abs(error), 0.85, na.rm = TRUE),
    q70_lower = quantile(abs(error), 0.15, na.rm = TRUE),
    q50_upper = quantile(abs(error), 0.75, na.rm = TRUE),
    q50_lower = quantile(abs(error), 0.25, na.rm = TRUE),
    median = median(abs(error), na.rm = TRUE)
  ), by = groups]
}

errors[, construction := ifelse(construction == "GDP", "CDP", construction)]

errors_gdp <- subset(errors, 
  construction == "CDP" & epsilon == 1 & sensitivity == 10
)

errors_cms <- subset(errors, 
     construction == "CMS" & epsilon == 5 & sensitivity == 10 & 
       k == 205 & m == 2340
)

errors_gdp_cms_comparison <- rbind(errors_gdp, errors_cms)

errors_gdp_cms_comparison[, error := count - count_private]

od_counts <- unique(errors[, .(geoid_o, geoid_d, count)])
od_counts <- od_counts[order(-count)]
od_counts[, id := .I]

errors_gdp_cms_comparison[od_counts, on=c("geoid_o", "geoid_d"), id := id]

p_error <- ggplot(errors_gdp_cms_comparison) + 
  geom_point(aes(x = id, y = error), size=0.1) + 
  facet_wrap(~construction, nrow=1) + 
  labs(x = "Origin-destination pair (frequency ranked)",
       y = "Error") + 
  theme_bw() + 
  theme(strip.background = element_rect(fill="white",
                                        size = 0))

ggsave(.outputs[1],
     p_error,
     width=10,
     height=5, 
     units="in") 

# Pull value for average noise x CMS to GDP
errors_gdp_cms_comparison[, .(mean_absolute_error = mean(abs(error))), by = c("construction")]

construction_pal <- c('#34a0a4', '#023e8a')

p_error_density <- ggplot(errors_gdp_cms_comparison) + 
  geom_density(aes(x = error, fill=construction), size=0) + 
  labs(x = "Error",
       y = "Density",
       title='a') + 
  facet_wrap(~construction, scales="free", nrow=2) + 
  scale_fill_manual(values = construction_pal) + 
  theme_classic() + 
  theme(legend.position = "none",
        strip.background = element_rect(size=0))

# quantile of empirical error distribution for each mechanism
# with observed error
errors_gdp_cms_comparison <- errors_gdp_cms_comparison[abs_error_quantiles_by_groups(errors_gdp_cms_comparison, "construction"),
                          on="construction"]

# truncating at count of 10 to focus on higher frequency journeys
errors_gdp_cms_comparison_high_freq <- subset(errors_gdp_cms_comparison, count>10)
p_error_freq <- ggplot(errors_gdp_cms_comparison_high_freq) + 
  geom_point(aes(x = id, y = abs(error)/count, color=construction), size=0.001,
             alpha=0.9) + 
  scale_color_manual(values = construction_pal) + 
  geom_ribbon(aes(x = id, ymin = q90_lower/count, ymax=q90_upper/count),
              color="black", fill="transparent", size=0.4) + 
  geom_ribbon(aes(x = id, ymin = q50_lower/count, ymax=q50_upper/count),
              color="black", fill="transparent", size=0.4, linetype="dashed") + 
  geom_hline(aes(yintercept=0.1), linetype="dashed", size=0.4, color="red") + 
  scale_y_continuous(trans="log10",
                     breaks=c(0.0001, 0.001, 0.01, 0.1, 1, 10, 100, 1000)) + 
  scale_x_continuous(breaks=c(0, max(errors_gdp_cms_comparison_high_freq$id)),
                     labels = c("High", "Low")) + 
  facet_wrap(~construction, nrow=1) + 
  theme_classic() + 
  theme(axis.text.x = element_text(angle = -45, hjust = 0),
        strip.background = element_rect(size=0),
        legend.position = 'none') +
  labs(y = "Error %", 
       x = "Origin-destination pair frequency", 
       title='b')

p <- cowplot::plot_grid(p_error_density, p_error_freq, 
                   rel_widths = c(0.3, 0.7))

ggsave(.outputs[2],
       p,
       width=10,
       height=5, 
       units="in") 

# Sensitivity analysis for different CMS parameters

errors_cms <- subset(errors, construction == "CMS")

errors_cms[, error := count - count_private]

error_cms_sd <- errors_cms[, .(error_sd = sd(error)), 
             by = c("construction", "epsilon", "sensitivity", "m", "k")]

sd_model <- lm(error_sd~epsilon+sensitivity+m+k, data=error_cms_sd)

res_lmg_boot <- relaimpo::boot.relimp(sd_model, type="lmg", rela=T, R=1000)
res_lmg_boot_ci <- relaimpo::booteval.relimp(res_lmg_boot, bty = "perc", 
                                             level = 0.95)
res <- relaimpo::calc.relimp(sd_model, type="lmg", rela=T)
res_lmg <- data.table(param=res_lmg_boot@namen[2:5],
           lmg=res$lmg,
           lower=as.numeric(res_lmg_boot_ci@lmg.lower),
           upper=as.numeric(res_lmg_boot_ci@lmg.upper))

res_lmg[, param := factor(param, 
                          levels=rev(c("epsilon", "sensitivity", "m", "k")),
                          labels=rev(c("ε", "s", "m", "k")))]

sensitivity_pal <- c('blue', '#ffe808', '#ffce00', '#ff9a00', '#ff5a00')
m_pal <- c('#48cae4', '#00b4d8', '#0077b6', '#023e8a','#03045e')
k_pal <- c('#e0aaff', '#c77dff', '#7b2cbf', '#3c096c')

# Color this by parameter (first color of each param pal?)
p_param_r2 <- ggplot(res_lmg) + 
  geom_errorbar(aes(y = param, xmin=lower, xmax=upper,
                    color=param), width=0.2) + 
  geom_point(aes(y = param, x = lmg, color=param), stat="identity", 
             size=1) + 
  geom_text(aes(y = param, x = upper+0.12, 
                label=scales::percent(lmg)),
            size=3.5) + 
  geom_vline(xintercept=1, linetype="dashed", size=0.2) + 
  scale_color_manual(values=rev(c('#95d5b2', sensitivity_pal[2], m_pal[1], k_pal[1]))) + 
  labs(title="a",
       x = "Parameter",
       y = expression(paste("Partial ", R^2, " for error SD"))) + 
  theme_classic() + 
  theme(legend.position = "none") + 
  scale_x_continuous(breaks=c(0, 0.25, 0.5, 0.75, 1),
                     limits = c(0, 1.2))

# Plot of decreasing counts for each sensitivity
errors_cms_s <- subset(errors_cms, epsilon==10 & m == 2340 & k == 2056)
errors_cms_s[od_counts, on=c("geoid_o", "geoid_d"), id := id]
errors_cms_s <- errors_cms_s[, .(id, count_private, sensitivity)]
colnames(errors_cms_s) <- c('id', 'value', 'sensitivity')

errors_cms_true <- od_counts[, .(id, count)]
errors_cms_true[, sensitivity := "True"]
colnames(errors_cms_true) <- c('id', 'value', 'sensitivity')

errors_cms_s <- rbind(errors_cms_s, errors_cms_true)

s_levels <- c("True", "1", "2", "5", "10")
s_labels <- c("True distribution", paste(c(1, 2, 5, 10), c("OD Pair", rep("OD Pairs", 3))))
      
errors_cms_s[, sensitivity := factor(sensitivity, 
         levels = s_levels,
         labels = s_labels)]

p_param_s <- ggplot(errors_cms_s) + 
  geom_point(aes(x = id, y = pmax(value, 0), color=sensitivity),
             size=0.1) + 
  scale_y_continuous(trans="log10") + 
  scale_x_continuous(trans="log10",
                     breaks=c(1, max(errors_cms_s$id)),
                     labels = c("High", "Low")) + 
  scale_color_manual(values=sensitivity_pal) + 
  theme_classic() + 
  labs(title="b",
       color="s",
       x = expression(paste("Origin-destination pair frequency rank (", log[10], " scale)")),
       y = expression(paste("Number of trips (", log[10], " scale)"))) + 
  theme(legend.position = c(0.2, 0.4),
        legend.title = element_text(face="italic")) + 
  guides(color = guide_legend(override.aes = list(size = 2)))

# Plot error for changing m
errors_cms_m <- subset(errors_cms, epsilon==10 & sensitivity == 10 & k == 2056)

errors_cms_m[, m := factor(m,
                           levels = sort(unique(errors_cms_m$m)),
                           labels = paste(c(0.005, 0.01, 0.1, 0.5), "× N OD pairs"))]

p_param_m <- ggplot(errors_cms_m) + 
  geom_density(aes(x = error, color=as.character(m))) + 
  geom_vline(xintercept=0, linetype="dashed", size=0.2) + 
  geom_hline(yintercept=0, size=0.2) + 
  scale_color_manual(values=m_pal) + 
  theme_classic() + 
  theme(legend.position = c(0.2, 0.6),
        legend.title = element_text(face="italic")) + 
  labs(title="c",
       color="m",
       x="Error",
       y="Density")

# Plot error for changing k
errors_cms_k <- subset(errors_cms, epsilon==10 & sensitivity == 10 & m == 2340)

errors_cms_k[, k := factor(k,
                           levels = sort(unique(errors_cms_k$k)),
                           labels = paste(sprintf("%.4f", c(0.0001, 0.001, 0.01, 0.1)), 
                                        "× N devices"))]

p_param_k <- ggplot(errors_cms_k) + 
  geom_density(aes(x = error, color=as.character(k))) + 
  geom_vline(xintercept=0, linetype="dashed", size=0.2) + 
  geom_hline(yintercept=0, size=0.2) + 
  scale_color_manual(values=k_pal) + 
  theme_classic() + 
  theme(legend.position = c(0.2, 0.6),
        legend.title = element_text(face="italic")) + 
  xlim(-1000, 400) + 
  labs(title="d",
       color="k",
       x="Error",
       y="Density")

p <- cowplot::plot_grid(
  p_param_r2, p_param_s, p_param_m, p_param_k,
  nrow=2
)

ggsave(.outputs[3],
       p,
       width=10,
       height=7, 
       units="in")

