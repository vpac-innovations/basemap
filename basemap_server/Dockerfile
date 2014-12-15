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

RUN apt-get update && \
    apt-get install -y \
        build-essential \
        python \
        python-mapnik \
        python-pip \
        --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

RUN pip install mapproxy

ENV NCPU 0
ENV SPOOL_DIR /var/spool/basemap
ENV STORAGE_DIR /var/lib/basemap

VOLUME ["/var/lib/basemap", "/var/spool/basemap"]

CMD /bin/bash

