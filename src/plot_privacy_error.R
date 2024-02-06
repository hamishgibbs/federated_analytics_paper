suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

if (interactive()) {
  .args <- c(
    "output/analytics/sensitivity/privacy_sensitivity_errors_date_2019_01_01_d_2.csv",
    "output/analytics/sensitivity/privacy_sensitivity_date_2019_01_01_d_2.csv",
    "data/geo/2019_us_county_distance_matrix.csv",
    "output/figs/construction_epsilon_mape.png",
    "output/figs/construction_epsilon_ape_threshold.png",
    "output/figs/construction_epsilon_ape_threshold_full.png",
    "output/figs/construction_epsilon_freq_ape.png",
    "output/figs/construction_sensitivity_sensitivity.png",
    "output/figs/construction_m_k_sensitivity.png"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

.outputs <- tail(.args, 6)

errors <- fread(.args[1])
error_metrics <- fread(.args[2])
distance <- fread(.args[3])

epsilon_construction_df <- rbind(subset(error_metrics, sensitivity == 10 & construction %in% c("GDP", "naive_LDP")),
      subset(error_metrics, sensitivity == 10 & k == 1000 & m == 4096 & construction %in% c("CMS")))[
        order(construction, epsilon)
      ]

epsilon_construction_df[, construction := factor(construction, 
                                                 levels=c("GDP", "naive_LDP", "CMS"),
                                                 labels=c("GDP", "Naive LDP", "CMS"))]

p_construction_epsilon <- ggplot(epsilon_construction_df) + 
  geom_path(aes(x = epsilon, y = mape, color=construction)) + 
  geom_point(aes(x = epsilon, y = mape, color=construction)) + 
  scale_y_continuous(trans="log10", labels=scales::comma, breaks=10^(2:5)) + 
  geom_vline(xintercept=0, linetype="dashed", size=0.2) + 
  geom_hline(yintercept=100, linetype="dashed", size=0.2) + 
  theme_classic() + 
  theme(legend.position=c(0.8, 0.8)) + 
  labs(y = "Mean Absolute Percentage Error (%)", 
       x="Epsilon", 
       color="Privacy method")

ggsave(.outputs[1],
       p_construction_epsilon,
       width=6,
       height=4, 
       units="in")  


# Percentage of OD pairs below a certain error threshold
# Percentage of true observations below a certain error threshold
# CMS & GDP

# Utility thresholds (absolute percentage error): 1% 5% 10% 100%
# For different methods (GDP, CMS)
# 2 panel facet - number of OD pairs and proportion of true trips
gdp_error <- subset(errors, 
                         sensitivity == 10 & 
                           construction == "GDP")

cms_error <- subset(errors, 
                         sensitivity == 10 & 
                         construction == "CMS" & 
                         m == 4096 & 
                         k == 1000)

error_threshold <- rbind(cms_error, gdp_error)
error_threshold <- subset(error_threshold, epsilon %in% c(0.1, 0.5, 1, 5, 10, 15))

ape_threshold_res <- list()
ape_thresholds <- c(1, 5, 10, 100)
for (i in 1:length(ape_thresholds)){
  ape_threshold <- ape_thresholds[i]
  thresh_res <- error_threshold[, .(prop_od = sum(absolute_percentage_error < ape_threshold) / .N,
                      prop_count = sum(count[absolute_percentage_error < ape_threshold]) / sum(count)), 
                  by = .(construction, epsilon, sensitivity, m, k)] 
  thresh_res[, ape_threshold := ape_threshold]
  ape_threshold_res[[i]] <- thresh_res
}

ape_threshold_res <- do.call(rbind, ape_threshold_res)

# Pull values for manusript
subset(ape_threshold_res, construction=="GDP" & ape_threshold == 5)
subset(ape_threshold_res, construction=="CMS" & ape_threshold == 5)

ape_threshold_res_long <- melt(ape_threshold_res, id.vars = c('construction', 'epsilon', 'sensitivity', 'm', 'k', 'ape_threshold'))

ape_threshold_res_long[, ape_threshold := factor(ape_threshold, levels=ape_thresholds,
                                                 labels=c("1%", "5%", "10%", "100%"))]
ape_threshold_res_long[, label := factor(paste0(construction, " (ϵ=", epsilon, ")"), 
                                         levels=c("GDP (ϵ=0.1)", "GDP (ϵ=0.5)", "GDP (ϵ=1)", "GDP (ϵ=5)", "GDP (ϵ=10)", "GDP (ϵ=15)",
                                                  "CMS (ϵ=0.1)", "CMS (ϵ=0.5)", "CMS (ϵ=1)", "CMS (ϵ=5)", "CMS (ϵ=10)", "CMS (ϵ=15)"))]
ape_threshold_res_long[, variable := factor(variable, levels=c("prop_od", "prop_count"),
                                            labels=c("Origin-Destination Pairs", "Trips"))]

construction_epsilon_pal <- c(
  '#edf8fb','#b2e2e2','#66c2a4','#238b45',
  '#f1eef6','#bdc9e1','#74a9cf','#0570b0'
)

p_ape_thresh <- ggplot(subset(ape_threshold_res_long, epsilon %in% c(1, 5, 10, 15))) + 
  geom_vline(xintercept=c(0, 0.25, 0.5, 0.75, 1), size=0.1, linetype='dashed') + 
  geom_bar(aes(x = value, 
               y = ape_threshold, fill=label), 
           stat='identity', position="dodge") + 
  scale_fill_manual(values=construction_epsilon_pal) + 
  scale_x_continuous(limits=c(0, 1), labels=scales::percent) + 
  facet_wrap(~variable) + 
  labs(y = "Absolute Percent Error Threshold",
       x = "Percentage below threshold",
       fill=NULL) + 
  theme_classic() + 
  theme(legend.position = "right", #c(0.35, 0.4),
        strip.background = element_blank(),
        strip.text = element_text(face='bold'))

ggsave(.outputs[2],
       p_ape_thresh,
       width=7,
       height=4.5, 
       units="in")  

# Supplement version
construction_epsilon_pal <- c(
  '#c7e9c0','#a1d99b','#74c476','#41ab5d','#238b45','#006d2c',
  '#c6dbef','#9ecae1','#6baed6','#4292c6','#2171b5','#08519c'
)

p_ape_thresh <- ggplot(ape_threshold_res_long) + 
  geom_vline(xintercept=c(0, 0.25, 0.5, 0.75, 1), size=0.1, linetype='dashed') + 
  geom_bar(aes(x = value, 
               y = ape_threshold, fill=label), 
           stat='identity', position="dodge") + 
  scale_fill_manual(values=construction_epsilon_pal) + 
  scale_x_continuous(limits=c(0, 1), labels=scales::percent) + 
  facet_wrap(~variable) + 
  labs(y = "Absolute Percent Error Threshold",
       x = "Percentage below threshold",
       fill=NULL) + 
  theme_classic() + 
  theme(legend.position = "right", #c(0.35, 0.4),
        strip.background = element_blank(),
        strip.text = element_text(face='bold'))

ggsave(.outputs[3],
       p_ape_thresh,
       width=10,
       height=8, 
       units="in")  

# Error by frequency
od_counts <- unique(errors[, .(geoid_o, geoid_d, count)])
od_counts <- od_counts[order(count)]
od_counts[, id := .I]

od_counts[, freq_cat := cut(
  id, breaks = quantile(
    id, probs = seq(0, 1, by = 0.02)), 
  include.lowest = TRUE, labels = FALSE)
]

max_q <- max(unique(od_counts$freq_cat))
q_labels <- c("Low Frequency", 2:(max_q-1), "High Frequency")
od_counts[, freq_cat := factor(freq_cat, levels = 1:max_q, 
                               labels = q_labels)]

cms_gdp_errors <- subset(errors, construction %in% c("GDP", "CMS"))

cms_gdp_errors[od_counts, on=c("geoid_o", "geoid_d"), freq_cat := freq_cat]

quantiles_by_groups <- function(data, groups){
  data[, .(
    q90_upper = quantile(absolute_percentage_error, 0.95, na.rm = TRUE),
    q90_lower = quantile(absolute_percentage_error, 0.05, na.rm = TRUE),
    q70_upper = quantile(absolute_percentage_error, 0.85, na.rm = TRUE),
    q70_lower = quantile(absolute_percentage_error, 0.15, na.rm = TRUE),
    q50_upper = quantile(absolute_percentage_error, 0.75, na.rm = TRUE),
    q50_lower = quantile(absolute_percentage_error, 0.25, na.rm = TRUE),
    median = median(absolute_percentage_error, na.rm = TRUE)
  ), by = groups]
}

cms_gdp_errors_cat <- quantiles_by_groups(cms_gdp_errors, 
                                          c("construction", "epsilon", "sensitivity", "freq_cat",
                                            "m", "k"))
cms_gdp_errors_cat <- cms_gdp_errors_cat[order(freq_cat)]

gdp_freq_error <- subset(cms_gdp_errors_cat, 
                         sensitivity == 10 & 
                         epsilon %in% c(0.1, 1, 10) & 
                         construction == "GDP")

cms_freq_error <- subset(cms_gdp_errors_cat, 
       sensitivity == 10 & 
       epsilon %in% c(1, 10, 15) & 
       construction == "CMS" & 
       m == 4096 & 
       k == 1000)

freq_error_data <- rbind(gdp_freq_error, cms_freq_error)

plot_freq_error <- function(data, title){
  ggplot(data) + 
    geom_ribbon(aes(ymax = q70_upper, ymin = q70_lower, 
                    x = freq_cat, group=epsilon,
                    fill=as.character(epsilon)), alpha=0.2) + 
    geom_ribbon(aes(ymax = q50_upper, ymin = q50_lower, 
                    x = freq_cat, group=epsilon,
                    fill=as.character(epsilon)), alpha=0.2) + 
    geom_path(aes(x = freq_cat, y = median, group=epsilon), size=0.4) + 
    scale_y_continuous(trans="log10", labels = scales::comma) + 
    scale_x_discrete(labels=c(q_labels[1], rep("", max_q-2), tail(q_labels, 1))) + 
    scale_fill_manual(values=c("0.1" = '#e41a1c','1' = '#377eb8','10'='#4daf4a','15'='#ff7f00')) + 
    geom_hline(yintercept=c(100, 10, 1), linetype="dashed", size=0.2) + 
    theme_classic() + 
    labs(x = paste0("Origin-destination pairs by frequency (", max_q, " quantiles)"),
         y = "Absolute Percentage Error (%)",
         title=title,
         fill="Epsilon") + 
    theme(axis.ticks.x = element_blank())
}

combined_legend <- cowplot::get_legend(plot_freq_error(freq_error_data, ""))

p_gdp_freq_error <- plot_freq_error(gdp_freq_error, NULL) + 
  theme(legend.position = "none") + 
  labs(x="")
p_cms_freq_error <- plot_freq_error(cms_freq_error, NULL) + theme(legend.position = "none")

p_panels <- cowplot::plot_grid(p_gdp_freq_error, 
                   p_cms_freq_error, nrow=2)

p_freq_error <- cowplot::plot_grid(p_panels, combined_legend, 
                   ncol=2, rel_widths = c(0.8, 0.2))

ggsave(.outputs[4],
       p_freq_error,
       width=7,
       height=7, 
       units="in")  

# Plot of cms and GDP analytics for different sensitivities
# Read in CMS and GDP analytics
# Freq rank by highest sensitivity count
# plot remaining counts to show systematic decreases

sensitivity_errors_cms <- subset(errors, construction == "CMS" & 
                                   epsilon == 10 & 
                                   m == 4096 & 
                                   k == 10000)
sensitivity_errors_gdp <- subset(errors, construction == "GDP" & 
                                   epsilon == 10 )

sensitivity_errors_cms_rank <- subset(sensitivity_errors_cms, sensitivity==10)
sensitivity_errors_cms_rank <- sensitivity_errors_cms_rank[order(-count)]
sensitivity_errors_cms_rank[, id := .I]

sensitivity_errors_gdp_rank <- subset(sensitivity_errors_gdp, sensitivity==10)
sensitivity_errors_gdp_rank <- sensitivity_errors_gdp_rank[order(-count)]
sensitivity_errors_gdp_rank[, id := .I]

sensitivity_errors_cms[sensitivity_errors_cms_rank, on=c("geoid_o", "geoid_d"), id := id]
sensitivity_errors_gdp[sensitivity_errors_gdp_rank, on=c("geoid_o", "geoid_d"), id := id]

sensitivity_errors <- rbind(sensitivity_errors_cms,sensitivity_errors_gdp)
sensitivity_errors[, sensitivity := factor(sensitivity, levels = c("1", "2", "5", "10"))]

sensitivity_errors[, count_private := ifelse(count_private < 0, 0, count_private)]

p_sensitivity <- ggplot(sensitivity_errors) + 
  geom_point(aes(x = id, y = count_private, color=sensitivity), size=0.2) + 
  scale_y_continuous(trans="pseudo_log", breaks=10^(0:5), labels = scales::comma) + 
  scale_x_continuous(trans="pseudo_log") + 
  facet_wrap(~construction) + 
  theme_classic() + 
  labs(color="Sensitivity",
       y = "Number of trips (log scale)",
       x = "Origin-destination pair (log scale)") + 
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank())

ggsave(.outputs[5],
       p_sensitivity,
       width=10,
       height=5, 
       units="in") 

sensitivity_errors_cms <- subset(errors, construction == "CMS" & 
                                   epsilon == 10 & 
                                   sensitivity == 10 & 
                                   k == 10000)
sensitivity_errors_cms[, m := factor(m, levels = c("64", "256", "1024", "4096"))]

p_m_sensitivity <- ggplot(sensitivity_errors_cms) + 
  geom_boxplot(aes(x = absolute_percentage_error, y=m, fill=m), 
               alpha=1, outlier.shape = NA) + 
  colorspace::scale_fill_discrete_qualitative("Warm") + 
  scale_x_continuous(trans="pseudo_log", breaks=10^(0:5), labels = scales::comma) + 
  labs(title='a',
       subtitle="Sensitivity for values of m",
       x = "Distribution of Absolute Percentage Error",
       y = "Values of m") + 
  theme_classic() + 
  theme(legend.position = "none")

sensitivity_errors_cms <- subset(errors, construction == "CMS" & 
                                   epsilon == 10 & 
                                   sensitivity == 10 & 
                                   m == 4096 & 
                                   k != 5)
sensitivity_errors_cms[, k := factor(k, levels = as.character(c(1, 5, 10, 100, 1000, 10000)))]

p_k_sensitivity <- ggplot(sensitivity_errors_cms) + 
  geom_boxplot(aes(x = absolute_percentage_error, y=k, fill=k), 
               alpha=1, outlier.shape = NA) + 
  colorspace::scale_fill_discrete_qualitative("Cold") + 
  scale_x_continuous(trans="pseudo_log", breaks=10^(0:5), labels = scales::comma) + 
  labs(title='b',
       subtitle="Sensitivity for values of k",
       x = "Distribution of Absolute Percentage Error",
       y = "Values of k") + 
  theme_classic() + 
  theme(legend.position = "none")


p_m_k_sensitivity <- cowplot::plot_grid(p_m_sensitivity, p_k_sensitivity)

ggsave(.outputs[6],
       p_m_k_sensitivity,
       width=10,
       height=5, 
       units="in") 
