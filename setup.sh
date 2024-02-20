# Check if conda is installed
if ! command -v conda &> /dev/null
then
    echo "Conda could not be found, please install it first."
    exit
fi

# Create a conda environment
conda create --name fed_analytics_paper python=3.11

# Install Python dependencies
conda run --name fed_analytics_paper pip install -r requirements.txt

# Install R
conda run --name fed_analytics_paper conda install -y -c r r

# Install JAGS
conda run --name fed_analytics_paper conda install -y -c conda-forge jags

# Install gdal
conda run --name fed_analytics_paper conda install -y -c conda-forge gdal

# Install R dependencies
conda run --name fed_analytics_paper conda install -c conda-forge r-data.table r-ggplot2 r-igraph r-devtools r-readr r-cowplot r-sf r-terra r-s2 r-ggdendro r-rnaturalearth r-rnaturalearthdata r-timedate r-ggdendro r-lubridate

# Install development R packages
conda run --name fed_analytics_paper Rscript -e "devtools::install_github('COVID-19-Mobility-Data-Network/mobility')"
conda run --name fed_analytics_paper Rscript -e "devtools::install_github('hamishgibbs/ggutils', dependencies=FALSE)"
 