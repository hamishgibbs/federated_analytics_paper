suppressPackageStartupMessages({
  library(data.table)
})

if (interactive()) {
  .args <- c(
    'data/population/co-est2019-alldata-utf8.csv',
    "data/geo/division_lu.csv"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

states <- fread(.args[1],
                select = c("DIVISION", "COUNTY", "STATE", "STNAME"))

# Size of OD matrix for each division
states[, .(m_size = .N**2), by=c("DIVISION")]

# Exclude the Pacific Division
division_lu <- unique(subset(states, DIVISION != 9)[, .(DIVISION, STATE)])

division_lu[, STATE := stringr::str_pad(STATE, 2, side="left", pad=0)]

fwrite(division_lu, tail(.args, 1))
