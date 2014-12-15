FROM ubuntu:14.04

MAINTAINER Alex Fraser <alex@vpac-innovations.com.au>

RUN export DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND noninteractive

# Suff for working with OSM data
# Note: nodejs from this PPA conflicts with nodejs-legacy; both provide the
# node executable so only this one is needed.
RUN apt-get update && \
    apt-get install -y \
        software-properties-common \
        --no-install-recommends && \
    add-apt-repository ppa:developmentseed/mapbox && \
    apt-get update && \
    apt-get install -y \
        libmapnik \
        mapnik-utils \
        nodejs \
        osm2pgsql \
        postgresql-client \
        tilemill \
        unzip \
        wget \
        --no-install-recommends
RUN apt-get install -y \
        git \
        python \
        --no-install-recommends && \
        rm -rf /var/lib/apt/lists/*
RUN npm install -g carto

RUN ln -s /usr/share/tilemill/index.js /usr/local/bin/tilemill

ENV NCPU 0
ENV SPOOL_DIR /var/spool/basemap
ENV STORAGE_DIR /var/lib/basemap

VOLUME ["/var/lib/basemap", "/var/spool/basemap"]

COPY basemap_build.sh /usr/local/bin/
COPY patch_mml.py /usr/local/bin/

CMD basemap_build.sh

