suppressPackageStartupMessages({
  library(data.table)
  library(sf)
  library(ggplot2)
  library(ggdendro)
})

if (interactive()) {
  .args <- c(
    "output/space_time_scale/spatial_cluster_mean_area.csv",
    list.files("output/space_time_scale/agg", 
               pattern = ".csv",
               full.names = T),
    list.files("output/space_time_scale/analytics/CMS",
               pattern = ".csv",
               full.names = T),
    "output/figs/spacetime_raster.png",
    "output/figs/time_agg_freq_mape.png",
    "output/figs/space_time_epsilon.png"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

.outputs <- tail(.args, 3)

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

freq_q_thresh <- 0.1
private_analytics <- private_analytics[order(-count, space, t)]
private_analytics[, id := 1:.N, by = .(space, t)]
private_analytics[, freq_q := quantile(id, freq_q_thresh), by = .(space, t)]

top_e_value <- 10
private_analytics_top_freq <- subset(private_analytics, id <= freq_q & epsilon==top_e_value)
private_analytics_bottom_freq <- subset(private_analytics, id > freq_q & epsilon==top_e_value)

private_analytics_top_freq_mape <- private_analytics_top_freq[, 
                                      .(mape = mean(ape)), by = .(space, t)]

private_analytics_top_freq_mape[, space_label := factor(space,
                                    levels = rev(sort(unique(private_analytics$space))),
                                    labels = rev(round(space_mean_area$mean_area, 1)))]

p_spacetime_raster <- ggplot(private_analytics_top_freq_mape) + 
  geom_raster(aes(x = t, y=space_label, fill=mape)) + 
  theme_classic() + 
  colorspace::scale_fill_continuous_sequential("Teal", labels=scales::percent) + 
  scale_x_continuous(breaks = unique(private_analytics$t)) + 
  labs(x = "Time aggregation (Days)",
       y = expression("Mean area km"^2~"(1000s)"),
       fill="MAPE")

ggsave(.outputs[1],
       p_spacetime_raster,
       width=6,
       height=6, 
       units="in") 

private_analytics_bottom_freq_mape <- private_analytics_bottom_freq[, .(mape = mean(ape)), by = .(space, t)]
private_analytics_bottom_freq_mape[, freq := paste0("Bottom ", scales::percent(1-freq_q_thresh))]
private_analytics_top_freq_mape[, freq := paste0("Top ", scales::percent(freq_q_thresh))]

private_analytics_bottom_freq_mape[, space_label := factor(space,
                                                           levels = rev(sort(unique(private_analytics$space))),
                                                           labels = rev(round(space_mean_area$mean_area, 1)))]

top_bottom_mape <- rbind(private_analytics_top_freq_mape,
      private_analytics_bottom_freq_mape)[order(space, t)]

reference_mape <- subset(top_bottom_mape, t==1)
reference_mape[, reference_mape := mape]
top_bottom_mape[reference_mape, on=c("freq", "space"), reference_mape := reference_mape]

top_bottom_mape[, mape_change := (mape - reference_mape) / reference_mape]

label_df <- subset(top_bottom_mape, freq == paste0("Bottom ", scales::percent(1-freq_q_thresh)) & 
                     t == 7)

p_time_agg_freq <- ggplot(top_bottom_mape) + 
  geom_path(aes(x = t, y = mape_change, color=freq,
                group=paste(space, freq)), size=0.2) + 
  geom_point(aes(x = t, y = mape_change, color=freq), size=0.4) + 
  geom_hline(yintercept=0, linetype='dashed', color='black') + 
  geom_hline(yintercept=-1, linetype='dashed', color='black', size=0.2) + 
  ggrepel::geom_label_repel(data=label_df, aes(x = t, y = mape_change, label=paste0(space_label)),
                            nudge_x = 1.2, segment.size=0.2,
                            color="black") + 
  theme_classic() + 
  labs(color="Trip Frequency",
       x = "Time aggregation (days)",
       y = "Change in MAPE") + 
  theme(legend.position = c(0.2, 0.8)) + 
  scale_y_continuous(breaks = c(-1, 0, 2, 4, 6), labels=scales::percent) + 
  scale_x_continuous(limits = c(1, 9)) + 
  scale_color_manual(values=c("#E84855", "#255C99"))

ggsave(.outputs[2],
       p_time_agg_freq,
       width=6,
       height=4, 
       units="in") 

# Sensitivity analysis for different e

private_analytics_top_freq <- subset(private_analytics, id <= freq_q)
private_analytics_bottom_freq <- subset(private_analytics, id > freq_q)

private_analytics_top_freq_space_epsilon <- subset(private_analytics_top_freq, t==1)[, 
                                                      .(mape = mean(ape)), by = .(space, epsilon)]
private_analytics_top_freq_space_epsilon[, label := paste0("Top ", scales::percent(freq_q_thresh))]
private_analytics_bottom_freq_space_epsilon <- subset(private_analytics_bottom_freq, t==1)[, 
                                                      .(mape = mean(ape)), by = .(space, epsilon)]
private_analytics_bottom_freq_space_epsilon[, label := paste0("Bottom ", scales::percent(1-freq_q_thresh))]

private_analytics_top_freq_time_epsilon <- subset(private_analytics_top_freq, space==45)[, 
                                                      .(mape = mean(ape)), by = .(t, epsilon)]
private_analytics_top_freq_time_epsilon[, label := paste0("Top ", scales::percent(freq_q_thresh))]
private_analytics_bottom_freq_time_epsilon <- subset(private_analytics_bottom_freq, space==45)[, 
                                                      .(mape = mean(ape)), by = .(t, epsilon)]
private_analytics_bottom_freq_time_epsilon[, label := paste0("Bottom ", scales::percent(1-freq_q_thresh))]

space_epsilon <- rbind(
  private_analytics_top_freq_space_epsilon,
  private_analytics_bottom_freq_space_epsilon
)
space_epsilon[, label := factor(label, levels = c(
  paste0("Top ", scales::percent(freq_q_thresh)),
  paste0("Bottom ", scales::percent(1-freq_q_thresh))
))]
space_epsilon_reference_mape <- subset(space_epsilon, space == 75)
space_epsilon_reference_mape[, reference_mape := mape]
space_epsilon[space_epsilon_reference_mape, on=c("label", "epsilon"), reference_mape := reference_mape]
space_epsilon[, mape_change := (mape - reference_mape) / reference_mape]

space_epsilon[, space_label := factor(space,
                        levels = rev(sort(unique(private_analytics$space))),
                        labels = rev(round(space_mean_area$mean_area, 1)))]


time_epsilon <- rbind(
  private_analytics_top_freq_time_epsilon,
  private_analytics_bottom_freq_time_epsilon
)
time_epsilon[, label := factor(label, levels = c(
  paste0("Top ", scales::percent(freq_q_thresh)),
  paste0("Bottom ", scales::percent(1-freq_q_thresh))
))]
time_epsilon_reference_mape <- subset(time_epsilon, t == 1)
time_epsilon_reference_mape[, reference_mape := mape]
time_epsilon[time_epsilon_reference_mape, on=c("label", "epsilon"), reference_mape := reference_mape]
time_epsilon[, mape_change := (mape - reference_mape) / reference_mape]

p_space_epsilon <- ggplot(space_epsilon) + 
  geom_path(aes(x = space_label, y = mape_change, color=as.character(epsilon),
                group=epsilon), size=0.2) + 
  geom_point(aes(x = space_label, y = mape_change, color=as.character(epsilon)), size=0.2) + 
  geom_hline(yintercept=0, linetype="dashed", size=0.2) + 
  facet_wrap(~label, scales="free_y", nrow=2) + 
  scale_y_continuous(labels = scales::percent) + 
  theme_classic() + 
  labs(y = "Change in MAPE",
       x = expression("Mean area km"^2~"(1000s)"),
       color = "Epsilon") + 
  theme(legend.position = "none")

p_time_epsilon <- ggplot(time_epsilon) + 
  geom_path(aes(x = t, y = mape_change, color=as.character(epsilon)), size=0.2) + 
  geom_point(aes(x = t, y = mape_change, color=as.character(epsilon)), size=0.2) + 
  geom_hline(yintercept=0, linetype="dashed", size=0.2) + 
  facet_wrap(~label, scales="free_y", nrow=2) + 
  scale_y_continuous(labels = scales::percent) + 
  scale_x_continuous(breaks = 1:7) + 
  theme_classic() + 
  labs(y = "Change in MAPE",
       x = "Time aggregation (days)",
       color = "Epsilon") + 
  theme(legend.position = "none")

p_comb <- cowplot::plot_grid(p_space_epsilon, p_time_epsilon, 
                   nrow=1)

p_space_time_epsilon <- cowplot::plot_grid(
  p_comb,
  cowplot::get_legend(p_space_epsilon + theme(legend.position = "right")),
  rel_widths = c(0.9, 0.1)
)

ggsave(.outputs[3],
       p_space_time_epsilon,
       width=6,
       height=4, 
       units="in") 

