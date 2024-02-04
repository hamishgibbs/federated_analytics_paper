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

division_names <- data.table(
  DIVISION = 1:9,
  DIVISION_NAME =c(
    "New England",
    "Middle Atlantic",
    "East North Central",
    "West North Central",
    "South Atlantic",
    "East South Central",
    "West South Central",
    "Mountain",
    "Pacific"
  ) 
)

# A set of custom divisions
sub_divisions <- data.table(
  SUBDIVISION=c(
    rep(1, 6),
    rep(2, 3),
    rep(3, 3),
    rep(4, 2),
    rep(5, 3),
    rep(6, 2),
    rep(8, 4),
    rep(9, 3)
  ),
  STNAME=c(
    "Connecticut",
    "Maine",
    "Massachusetts",
    "New Hampshire",
    "Rhode Island",
    "Vermont",
    "New Jersey",
    "New York",
    "Pennsylvania",
    "Indiana",
    "Michigan",
    "Ohio",
    "Iowa",
    "Missouri",
    "Florida",
    "Georgia",
    "South Carolina",
    "Kentucky",
    "Tennessee",
    "Arizona",
    "Colorado",
    "New Mexico",
    "Utah",
    "California",
    "Oregon",
    "Washington"
  )
)

states <- fread(.args[1],
                select = c("DIVISION", "COUNTY", "STATE", "STNAME"))

states[division_names, on=c("DIVISION"), DIVISION_NAME := DIVISION_NAME]

states[sub_divisions, on=c("STNAME"), SUBDIVISION := SUBDIVISION]

states <- subset(states, !is.na(SUBDIVISION))

# Size of OD matrix for each division
states[, .(m_size = .N**2), by=c("SUBDIVISION")][order(SUBDIVISION)]

division_lu <- unique(states[, .(STATE, STNAME, SUBDIVISION)])[order(SUBDIVISION, STNAME)]

division_lu[, STATE := stringr::str_pad(STATE, 2, side="left", pad=0)]

fwrite(division_lu, tail(.args, 1))
