suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(timeDate)
})

if (interactive()) {
  .args <- c(
    list.files(
      "output/gravity/check",
      pattern="*.csv",
      full.names = TRUE
      ),
    "output/figs/spatiotemporal_r2_by_date_type.png",
    "output/figs/spatiotemporal_r2_by_month.png",
    "output/figs/spatiotemporal_error_metrics_summary.csv"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

.outputs <- tail(.args, 3)

check_fn <- .args[grep("departure-diffusion_exp", .args)]

read_check <- function(fn){
  fn_date <- lubridate::ymd(gsub("output/gravity/check/departure-diffusion_exp_date_", "", 
                                 gsub("_d_.*_check.csv", "", fn)))
  
  fn_division <- gsub("output/gravity/check/departure-diffusion_exp_date_.*_d_", "", 
                      gsub("_check.csv", "", fn))  
  check <- fread(fn)
  check[, date := fn_date]
  check[, division := fn_division]
}

check <- do.call(rbind, lapply(check_fn, read_check))

check <- subset(check, division %in% as.character(c(1, 2, 8, 9)))

get_holiday_dates <- function(holiday_func_name, year) {
  holiday_func <- get(holiday_func_name, envir = asNamespace('timeDate'))
  holiday_dates <- as.character(holiday_func(year = year))
  return(holiday_dates)
}

us_holiday_dates <- as.Date(unlist(lapply(listHolidays(pattern = "US"), 
                           get_holiday_dates, year = 2019)))

check[, month := factor(month.name[lubridate::month(date)], levels = month.name)]
check[, weekend := lubridate::wday(date) %in% c(1, 7)]
check[, holiday := date %in% us_holiday_dates]
check[, date_type := ifelse(weekend, "Weekend", "Weekday")]
check[, date_type := ifelse(holiday, "Holiday", date_type)]

check[, division := factor(division, 
                           levels=as.character(c(1, 2, 8, 9)),
                           labels=paste("Region", 1:4))]
check[, date_type := factor(date_type, 
                           levels=c("Weekday", "Weekend", "Holiday"))]

r2_check <- subset(check, metric == "R2")
r2_check <- r2_check[order(division, date)]

r2_check_sum <- r2_check[, .(mean_r2 = mean(value),
                         min_r2 = min(value),
                         max_r2 = max(value)), by=.(metric, division, date_type)]

p_r_date_type <- ggplot(r2_check_sum) + 
  geom_jitter(data = r2_check, aes(x = division, y = value),
              size=0.2, width = 0.3, height = 0) + 
  geom_point(aes(x = division, y = mean_r2, color=division)) + 
  geom_errorbar(aes(x = division, ymin=min_r2, ymax=max_r2,
                    color=division)) + 
  facet_wrap(~date_type) + 
  theme_classic() + 
  labs(y="Correlation Coefficient",
       x="Region",
       color=NULL) + 
  theme(strip.background = element_blank(),
        strip.text = element_text(face="bold"),
        panel.border = element_rect(size=0.2, color="black", fill="transparent"),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank())
ggsave(.outputs[1],
       p_r_date_type,
       width=10,
       height=5, 
       units="in")  

p_r_time <- ggplot(subset(r2_check, date_type %in% c("Weekday", "Weekend"))) + 
  geom_path(aes(x = date, y = value, color=division), size=0.2) + 
  geom_point(aes(x = date, y = value, color=division), size=0.2) + 
  facet_wrap(~month, scales="free_x") +
  theme_classic() + 
  labs(y="Correlation Coefficient",
       x=NULL,
       color=NULL) 

ggsave(.outputs[2],
       p_r_time,
       width=10,
       height=8, 
       units="in")  


error_summary <- subset(check, metric != "DIC")[, .(min_value = round(min(value), 2), 
          max_value = round(max(value), 2), 
          mean_value = round(mean(value), 2),
          median_value = round(median(value), 2)), by =c("metric", "division")]

error_summary <- error_summary[, value_label := paste0(mean_value, " (", min_value, " - ", max_value, ")")]

error_summary <- dcast(error_summary[, .(metric, division, value_label)], 
      formula = division ~ metric,
      value.var = "value_label")
      

fwrite(error_summary, .outputs[3])


