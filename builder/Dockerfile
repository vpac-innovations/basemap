FROM ubuntu:14.04

MAINTAINER Alex Fraser <alex@vpac-innovations.com.au>

RUN export DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND noninteractive

# MapBox PPA (common to other basemap Dockerfiles)
RUN apt-get update && \
    apt-get install -y \
        software-properties-common \
        --no-install-recommends && \
    add-apt-repository ppa:developmentseed/mapbox && \
    apt-get update && \
    apt-get install -y \
        libmapnik \
        mapnik-input-plugin-postgis && \
    rm -rf /var/lib/apt/lists/*

# Suff for working with OSM data
# Note: nodejs from this PPA conflicts with nodejs-legacy; both provide the
# node executable so only this one is needed.
RUN apt-get update && \
    apt-get install -y \
        git \
        mapnik-utils \
        nodejs \
        osm2pgsql \
        postgresql-client \
        python \
        python-mapnik \
        wget \
        --no-install-recommends &&\
    rm -rf /var/lib/apt/lists/*

RUN npm -g config set user "root"
RUN npm install -g carto && \
    npm install -g millstone

ENV NCPU 0
ENV SPOOL_DIR /var/spool/basemap
ENV STORAGE_DIR /var/lib/basemap

VOLUME ["/var/lib/basemap", "/var/spool/basemap"]

COPY basemap_build.sh /usr/local/bin/
COPY patch_mml.py /usr/local/bin/

CMD ["basemap_build.sh"]