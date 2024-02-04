suppressPackageStartupMessages({
  library(data.table)
  library(mobility)
  library(ggplot2)
})

if (interactive()) {
  .args <- c(
    "data/geo/division_lu.csv",
    "data/population/pop_est2019_clean.csv",
    "data/geo/2019_us_county_distance_matrix.csv",
    "data/mobility/clean/daily_county2county_2019_01_01_clean.csv",
    "100",
    "500",
    "2",
    "output/gravity/summary/departure-diffusion_exp_2019_01_01_d_2_summary.csv",
    "output/gravity/check/departure-diffusion_exp_2019_01_01_d_2_check.csv",
    "output/gravity/pij/departure-diffusion_exp_2019_01_01_d_2_pij.csv",
    "output/gravity/diagnostic/departure-diffusion_exp_2019_01_01_d_2_error.png",
    "output/gravity/diagnostic/departure-diffusion_exp_2019_01_01_d_2_error.rds"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

N_BURN <- as.numeric(.args[5])
N_SAMP <- as.numeric(.args[6])
division <- as.numeric(.args[7])
.outputs <- tail(.args, 5)

# Extract model type from output fn
model_type_extract <- unlist(stringr::str_split(basename(.outputs[1]), "_"))
MODEL <- model_type_extract[1]
MODEL_TYPE <- model_type_extract[2]
if (MODEL_TYPE == "powernorm"){
  MODEL_TYPE <- "power_norm"
}
if (MODEL_TYPE == "expnorm"){
  MODEL_TYPE <- "exp_norm"
}

# Define a subset of states for modelling
divisions <- fread(.args[1])
states <- subset(divisions, SUBDIVISION == division)$STATE

N <- fread(.args[2], 
        select=c("GEOID", "POPESTIMATE2019"),
        colClasses=c("GEOID"="character", "POPESTIMATE2019"="integer"))

N <- N[substr(N$GEOID, 1, 2) %in% states, ]

D <- fread(.args[3], 
        select=c("GEOID_origin", "GEOID_dest", "distance"),
        colClasses=c("GEOID_origin"="character", "GEOID_dest"="character", "distance"="numeric"))

D <- D[substr(D$GEOID_origin, 1, 2) %in% states & substr(D$GEOID_dest, 1, 2) %in% states, ]

M <- fread(.args[4],
        select=c("geoid_o", "geoid_d", "pop_flows"),
        colClasses=c("geoid_o"="character", "geoid_d"="character", "pop_flows"="numeric"))

M <- M[substr(M$geoid_o, 1, 2) %in% states & substr(M$geoid_d, 1, 2) %in% states, ]

N <- N[order(GEOID)]

model_inputs <- list()

model_inputs$N <- N$POPESTIMATE2019
names(model_inputs$N) <- N$GEOID

model_inputs$D <- reshape2::acast(D, GEOID_origin~GEOID_dest, value.var="distance")
model_inputs$D <- model_inputs$D[order(row.names(model_inputs$D)), ]

model_inputs$M <- reshape2::acast(M, geoid_o~geoid_d, value.var="pop_flows")
model_inputs$M <- model_inputs$M[order(row.names(model_inputs$M)), ]

res <- mobility(data=model_inputs,
         model=MODEL,
         type=MODEL_TYPE,
         n_chain=4,
         #n_burn=10000,
         #n_samp=50000,
         n_burn=N_BURN,
         n_samp=N_SAMP,
         n_thin=2,
         DIC=TRUE,
         parallel=TRUE)

res_summary <- res$summary
res_summary$param <- row.names(res_summary)

if (MODEL != 'radiation'){
  fwrite(res_summary, .outputs[1]) 
} else {
  fwrite(data.table(), .outputs[1])
}

res_check <- unlist(check(res))

res_check <- data.table(metric=names(res_check), value=res_check)
fwrite(res_check, .outputs[2]) 

pred <- predict(res)
pred <- pred / sum(pred)

pred_dt <- data.table(pred)
pred_dt$geoid_o <- row.names(pred)
pred_dt <- melt(pred_dt, id.vars = 'geoid_o', variable.name = 'geoid_d')

fwrite(pred_dt, .outputs[3])

pred <- data.table(reshape2::melt(pred))
colnames(pred) <- c("geoid_o", "geoid_d", "pred")
obs <- data.table(reshape2::melt(model_inputs$M))
colnames(obs) <- c("geoid_o", "geoid_d", "obs")
obs[, obs := obs / sum(obs)]

obs[pred, on = .(geoid_o, geoid_d), pred := pred]

obs <- obs[order(obs)]
obs[, id := rev(.I)]

obs <- melt(obs, id.vars = c('geoid_o', 'geoid_d', 'id'))

p <- ggplot(obs) + 
  geom_point(aes(x = id, y = value, color=variable), size=0.2) + 
  scale_y_continuous(trans="log10", labels = scales::comma) + 
  scale_x_continuous(trans="log10") + 
  scale_color_manual(values=c("black", "red")) + 
  labs(title=basename(.outputs[3]),
       y = "P(i,j)",
       x = "Origin-Destination Pair") + 
  theme_classic()

ggsave(.outputs[4],
       p,
       width=10,
       height=6, 
       units="in")  

readr::write_rds(p, .outputs[5])
