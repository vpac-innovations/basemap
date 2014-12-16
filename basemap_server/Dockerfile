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
        python \
        python-mapnik \
        python-pil \
        python-pip \
        python-yaml \
        --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

RUN pip install mapproxy

ENV NCPU 0
ENV SPOOL_DIR /var/spool/basemap
ENV STORAGE_DIR /var/lib/basemap

EXPOSE 8080
VOLUME ["/var/lib/basemap", "/var/spool/basemap"]

# Link to Millstone cache; it's not configurable in Millstone itself yet.
RUN ln -s ${SPOOL_DIR}/cache /tmp/millstone-test

COPY basemap.yaml /usr/share/basemap/

CMD exec mapproxy-util serve-develop -b 0.0.0.0:8080 /usr/share/basemap/basemap.yaml

