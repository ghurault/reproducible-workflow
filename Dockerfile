# Inspired by https://eliocamp.github.io/codigo-r/en/2021/08/docker-renv/
# and https://www.jaredlander.com/2021/03/automating-temperature-tracking/

FROM rocker/rstudio:4.1.3

LABEL maintainer="Guillem Hurault <guillem.hurault@hotmail.fr>"

# system libraries
RUN apt update && \
    apt install  -y --no-install-recommends \
    libxt6 \
    # for igraph
    libxml2-dev \
    libglpk-dev \
    libgmp3-dev \
    # for httr
    libcurl4-openssl-dev \
    libssl-dev && \
    # makes the image smaller
    rm -rf /var/lib/apt/lists/*

# Create a user variable
ENV USER=rstudio

# Create project directory and set it as working directory
WORKDIR /home/$USER/reproducible-workflow

# Install R packages to local library using renv
COPY [".Rprofile", "renv.lock", "./"]
COPY renv/activate.R ./renv/
RUN chown -R rstudio . \
 && sudo -u rstudio R -e 'renv::restore(confirm = FALSE)'
