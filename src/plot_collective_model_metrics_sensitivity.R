suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

if (interactive()) {
  .args <- c(
    "output/gravity/check/gravity_basic_2019_01_01_check.csv",
    "output/gravity/check/gravity_power_2019_01_01_check.csv",
    "output/sensitivity/collective_model_sensitivity/collective_model_error_2019_01_01.png"
  )
  N_COLLECTIVE_MODELS <- 2
} else {
  .args <- commandArgs(trailingOnly = T)
  N_COLLECTIVE_MODELS <- 11
}

read_model <- function(fn){
  model_name <- gsub("_2019_01_01_check.csv", "", basename(fn)) 
  metrics <- fread(fn)
  metrics$model <- model_name
  metrics
}

metrics <- do.call(rbind, lapply(head(.args, N_COLLECTIVE_MODELS), read_model))

metrics <- metrics[order(metric, model)]

p <- ggplot(metrics) + 
  geom_path(aes(x = model, y = value, group=metric), size=0.2) + 
  geom_point(aes(x = model, y = value,
                 color=model)) + 
  facet_wrap(~metric, scales='free_y') + 
  theme_minimal() + 
  theme(legend.position = "none",
        plot.background = element_rect(fill="white"),
        axis.text.x = element_text(angle = 45, hjust = 1),
        strip.text = element_text(face="bold"))

ggsave(tail(.args, 1),
       p,
       width=10,
       height=6, 
       units="in")  

