options(repos = c(CRAN = "https://cloud.r-project.org"))

install.packages(c(
    "data.table",
    "ggplot2",
    "igraph",
    "devtools"
), Ncpus = detectCores())

devtools::install_github('COVID-19-Mobility-Data-Network/mobility')