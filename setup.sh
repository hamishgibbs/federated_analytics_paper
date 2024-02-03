#!/bin/bash

# Check if conda is installed
if ! command -v conda &> /dev/null
then
    echo "Conda could not be found, please install it first."
    exit
fi

# Check if JAGS is installed
if ! command -v jags &> /dev/null
then
    echo "JAGS is not installed. Installing JAGS..."
    sudo apt-get update && apt-get install -y jags
else
    echo "JAGS is already installed."
fi

# Create a conda environment
conda create --name fed_analytics_paper python=3.11
conda activate fed_analytics_paper

# Install Python dependencies
conda run --name fed_analytics_paper pip install -r requirements.txt

# Install R
conda run --name fed_analytics_paper conda install -c r r

# Install R dependencies
conda run --name fed_analytics_paper Rscript install_packages.R

echo "Setup completed successfully."