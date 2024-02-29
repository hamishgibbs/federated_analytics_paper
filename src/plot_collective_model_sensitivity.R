suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

if (interactive()) {
  .args <- c(
    "data/mobility/clean/daily_county2county_date_2019_04_08_clean.csv",
    "output/gravity/check/gravity_basic_date_2019_04_08_d_2_check.csv",
    "output/gravity/check/gravity_power_date_2019_04_08_d_2_check.csv",
    "output/gravity/pij/gravity_basic_date_2019_04_08_d_2_pij.csv",
    "output/gravity/pij/gravity_power_date_2019_04_08_d_2_pij.csv",
    "output/sensitivity/collective_model_sensitivity/collective_error_comparison_date_2019_04_08_d_2.png",
    "output/sensitivity/collective_model_sensitivity/collective_model_metrics_date_2019_04_08_d_2.png",
    "output/sensitivity/collective_model_sensitivity/collective_model_metrics_date_2019_04_08_d_2.csv"
  )
  N_COLLECTIVE_MODELS <- 2
} else {
  .args <- commandArgs(trailingOnly = T)
  N_COLLECTIVE_MODELS <- 8
}

.outputs <- tail(.args, 3)

empirical <- fread(.args[1], 
                   colClasses=c("geoid_o"="character", "geoid_d"="character"))

metrics_fn <- .args[2:(N_COLLECTIVE_MODELS+1)]
pij_fn <- .args[(N_COLLECTIVE_MODELS+2):(N_COLLECTIVE_MODELS+N_COLLECTIVE_MODELS+1)]

read_model <- function(fn, stub, colClasses){
  model_name <- gsub(stub, "", basename(fn)) 
  df <- fread(fn, colClasses=colClasses)
  df$model <- model_name
  df
}

metrics <- do.call(rbind, 
                   lapply(metrics_fn, read_model, stub="_date_2019_04_08_d_2_check.csv",
                          colClasses=c()))
pij <- do.call(rbind, 
               lapply(pij_fn, read_model, stub="_date_2019_04_08_d_2_pij.csv",
                      colClasses=c("geoid_o"="character", "geoid_d"="character")))

empirical[, obs := pop_flows / sum(pop_flows)]

pij[empirical, on=c("geoid_o", "geoid_d"), obs := obs]

pij <- pij[order(obs)]
pij[, id := rev(.I)]

pij <- melt(pij, id.vars = c("geoid_o", "geoid_d", "model", "id"))

model_order <- subset(metrics, metric=="RMSE")[order(-value)]$model
model_labels <- stringr::str_to_title(gsub("_", " ", model_order))

pij[, model := factor(model, levels=model_order, labels=model_labels)]

p <- ggplot(pij) + 
  geom_point(aes(x = id, y = value, color=variable), size=0.2) + 
  scale_y_continuous(trans="log10") + 
  scale_x_continuous(trans="log10") + 
  scale_color_manual(values=c("obs"="black", "value"="red")) + 
  facet_wrap(~model, nrow = 4, ncol=2, scales="free_y") + 
  labs(y = expression(P['i,j']),
       x = "Origin-Destination Pair") + 
  theme_classic() + 
  theme(legend.position="none",
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        text = element_text(size=15))

ggsave(.outputs[1],
       p,
       width=8,
       height=10, 
       units="in")  

metrics <- metrics[order(metric, model)]

metrics[, model := factor(model, levels=model_order, labels=model_labels)]

metrics[, metric := factor(metric, levels=c("RMSE", "MAPE", "DIC", "R2"))]

p <- ggplot(metrics) + 
  geom_point(aes(x = model, y = value, color=model), size=1.5) + 
  facet_wrap(~metric, scales='free_y') + 
  theme_minimal() + 
  theme(legend.position = "none",
        plot.background = element_rect(fill="white"),
        axis.text.x = element_text(angle = 45, hjust = 1),
        strip.text = element_text(face="bold"),
        text = element_text(size=15)) + 
  labs(y = "Value",
       x = NULL)

p

ggsave(.outputs[2],
       p,
       width=10,
       height=6, 
       units="in")  

metrics[, value := round(value, 2)]

fwrite(dcast(metrics, model ~ metric), .outputs[3])

