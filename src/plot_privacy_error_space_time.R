suppressPackageStartupMessages({
  library(data.table)
  library(sf)
  library(ggplot2)
  library(ggdendro)
})

if (interactive()) {
  .args <- c(
    "output/space_time_scale/spatial_cluster_mean_area.csv",
    "output/figs/spatial_cluster_example.rds",
    list.files("output/space_time_scale/agg", 
               pattern = ".csv",
               full.names = T),
    list.files("output/space_time_scale/analytics/CMS",
               pattern = ".csv",
               full.names = T),
    "output/figs/spacetime_raster.png",
    "output/figs/spacetime_epsilon.png"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

.outputs <- tail(.args, 2)

space_mean_area <- fread(.args[1])
space_mean_area[, mean_area := mean_area / 1000]

depr_agg_fns <- .args[grep("simulated_depr", .args)]

private_analytics_fns <- .args[grep("CMS", .args)]

# Aggregate base analytics into new regions

aggregate_base_analytics <- function(fn){
  depr_agg <- fread(fn)[order(uid, time)]
  depr_agg[, geoid_o := geoid]
  depr_agg[, geoid_d := shift(geoid, type="lead")]
  depr_agg[, geoid := NULL]
  depr_agg <- subset(depr_agg, !is.na(geoid_d))
  
  depr_agg_count <- depr_agg[, .(count = .N), by = .(geoid_o, geoid_d)]
  
  depr_agg_count$space <- as.numeric(sub(".*space_([0-9]+)_.*", "\\1", fn))
  depr_agg_count$t <- as.numeric(sub(".*time_([0-9]+)\\.csv", "\\1", fn))
  depr_agg_count
}

read_private_analytics <- function(fn){
  private_analytics <- fread(fn)
  private_analytics$space <- as.numeric(sub(".*space_([0-9]+)_.*", "\\1", fn))
  private_analytics$t <- as.numeric(sub(".*time_([0-9]+)\\.csv", "\\1", fn))
  private_analytics
}

base_analytics <- do.call(rbind, lapply(depr_agg_fns, aggregate_base_analytics))

private_analytics <- do.call(rbind, lapply(private_analytics_fns, read_private_analytics))

# Add true count to privatized analytics
private_analytics[, count_private := count]
private_analytics[, count := NULL]
private_analytics[base_analytics, on=c("geoid_o", "geoid_d", "space", "t"),
                  count := count]

private_analytics[, ape := abs(count - count_private) / count]

freq_q_thresh <- 0.05
private_analytics <- private_analytics[order(-count, space, t)]
private_analytics[, id := 1:.N, by = .(space, t, epsilon)]
private_analytics[, freq_q := quantile(id, freq_q_thresh), by = .(space, t, epsilon)]

private_analytics_top_freq <- subset(private_analytics, id <= freq_q)

# Only retain OD pairs present in top freq for all days
stable_od <- subset(private_analytics_top_freq[, .(n_days = length(unique(t))), by = .(geoid_o, geoid_d, space)],
                    n_days == max(private_analytics_top_freq$t))

private_analytics_top_freq <- private_analytics_top_freq[stable_od, on=c("geoid_o", "geoid_d", "space")]

private_analytics_top_freq_mape <- private_analytics_top_freq[, 
                                      .(mape = mean(ape)), by = .(space, t, epsilon)]

private_analytics_top_freq_mape[, space_label := factor(space,
                                    levels = rev(sort(unique(private_analytics$space))),
                                    labels = rev(round(space_mean_area$mean_area, 1)))]

top_e_value <- 5
p_spacetime_raster <- ggplot(subset(private_analytics_top_freq_mape, epsilon==top_e_value)) + 
  geom_raster(aes(x = t, y=space_label, fill=mape)) + 
  theme_classic() + 
  colorspace::scale_fill_continuous_sequential("Teal", labels=scales::percent) + 
  scale_x_continuous(breaks = unique(private_analytics$t)) + 
  labs(x = "Time aggregation (Days)",
       y = expression("Mean area km"^2~"(1000s)"),
       fill="MAPE",
       title="b")

private_analytics_top_freq[, space_label := factor(space,
                              levels = rev(sort(unique(private_analytics$space))),
                              labels = rev(round(space_mean_area$mean_area, 1)))]

space_aggregation <- subset(private_analytics_top_freq, t==7 & epsilon %in% c(5, 10))
space_aggregation <- space_aggregation[, .(
  q50_upper = quantile(ape, 0.75),
  q50_lower = quantile(ape, 0.25),
  ape_median = median(ape)),
  by = .(space_label, epsilon)]
space_aggregation[, agg_label := space_label]

space_aggregation[, epsilon := factor(epsilon, levels = c("5", "10"))]

dodge_width <- 0.8

p_space_epsilon <- ggplot(space_aggregation) + 
  geom_errorbar(aes(x=agg_label, 
                  ymin=q50_lower, 
                  ymax=q50_upper, color=epsilon,
                  group=epsilon), 
                position = position_dodge(width = dodge_width)) + 
  geom_point(aes(x = agg_label, 
                 y = ape_median, color=epsilon), 
             position = position_dodge(width = dodge_width)) + 
  geom_hline(yintercept=0, linetype='dashed', size=0.4) + 
  geom_hline(yintercept=c(0.1), linetype='dashed', size=0.2) + 
  scale_color_manual(values=c("5" = '#33a02c','10' = '#377eb8')) + 
  scale_y_continuous(labels = scales::percent) + 
  theme_classic() + 
  labs(y = "APE",
       x = expression("Mean area km"^2~"(1000s)"),
       color = "ε",
       title="c")

time_aggregation <- subset(private_analytics_top_freq, space==75 & epsilon %in% c(5, 10))

# Restrict to only OD pairs that are present in the top_freq for all 7 days
stable_pairs <- time_aggregation[, .(n_days = length(unique(t))), by = .(geoid_o, geoid_d)]

time_aggregation <- time_aggregation[, .(
  q50_upper = quantile(ape, 0.75),
  q50_lower = quantile(ape, 0.25),
  ape_median = median(ape)),
  by = .(t, epsilon)]
time_aggregation[, agg_label := t]
time_aggregation[, epsilon := factor(epsilon, levels = c("5", "10"))]

dodge_width <- 0.8

p_time_epsilon <- ggplot(time_aggregation) + 
  geom_errorbar(aes(x=agg_label, 
                    ymin=q50_lower, 
                    ymax=q50_upper, color=epsilon,
                    group=epsilon), 
                position = position_dodge(width = dodge_width)) + 
  geom_point(aes(x = agg_label, 
                 y = ape_median, color=epsilon), 
             position = position_dodge(width = dodge_width)) + 
  geom_hline(yintercept=0, linetype='dashed', size=0.4) + 
  geom_hline(yintercept=c(0.1), linetype='dashed', size=0.2) + 
  scale_color_manual(values=c("5" = '#33a02c','10' = '#377eb8')) + 
  scale_y_continuous(breaks=c(0, 0.1, 0.25, 0.5, 0.75),
                     labels = scales::percent) + 
  scale_x_continuous(breaks=1:7) + 
  theme_classic() + 
  labs(y = "APE",
       x = "Time aggregation (Days)",
       color = "ε",
       title="d")

p_cluster_example <- readr::read_rds(.args[2])

p_space_time_epsilon <- cowplot::plot_grid(
  p_space_epsilon + theme(legend.position = "none"),
  p_time_epsilon + theme(legend.position = "none"),
  nrow=2
)

p_space_time_epsilon_legend <- cowplot::plot_grid(
  p_space_time_epsilon, cowplot::get_legend(p_space_epsilon),
  rel_widths = c(0.9, 0.1)
)

p_right <- cowplot::plot_grid(p_spacetime_raster, p_space_time_epsilon_legend,
                              nrow=2)

p <- cowplot::plot_grid(p_cluster_example, p_right,
                        nrow=1, 
                        rel_widths  = c(0.4, 0.6))

ggsave(.outputs[1],
       p,
       width=10,
       height=7, 
       units="in") 


res <- subset(private_analytics_top_freq, space==75 & epsilon %in% c(5))

# This plot helps set the freq_q_thresh value to focus on only the OD pairs
# With high enough frequency to overwhelm the effect of the noise 
# through time aggregations
ggplot(res) + 
  geom_path(aes(x = t, y = count_private, group=paste(geoid_o, geoid_d)), 
            alpha=0.2) + 
  scale_y_continuous(trans="log10")

# x increase in spatial resolution leads to x increase in % OD pairs with high accuracy

