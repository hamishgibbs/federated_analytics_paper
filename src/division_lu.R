states <- fread('data/population/co-est2019-alldata-utf8.csv',
                select = c("DIVISION", "COUNTY", "STATE", "STNAME"))

# Size of OD matrix for each division
states[, .(m_size = .N**2), by=c("DIVISION")]

# Exclude the Pacific Division
division_lu <- unique(subset(states, DIVISION != 9)[, .(DIVISION, STATE)])

division_lu[, STATE := stringr::str_pad(STATE, 2, side="left", pad=0)]

fwrite(division_lu, "data/geo/division_lu.csv")
