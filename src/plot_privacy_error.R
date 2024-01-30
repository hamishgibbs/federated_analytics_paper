suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

if (interactive()) {
  .args <- c(
    "output/analytics/sensitivity/privacy_sensitivity_2019_01_01.csv",
    ""
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

.outputs <- tail(.args, 1)

error_metrics <- fread(.args[1])

epsilon_construction_df <- rbind(subset(error_metrics, sensitivity == 5 & construction %in% c("GDP")),
      subset(error_metrics, sensitivity == 5 & k == 1000 & m == 4096 & construction %in% c("CMS")))[
        order(construction, epsilon)
      ]

ggplot(epsilon_construction_df) + 
  geom_path(aes(x = epsilon, y = rmse, color=construction)) + 
  geom_point(aes(x = epsilon, y = rmse, color=construction))

