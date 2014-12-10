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
        tilemill \
        --no-install-recommends && \
    apt-get install -y \
        postgresql \
        postgis \
        unzip \
        --no-install-recommends && \
    apt-get install -y \
        virtualenvwrapper \
        python-pip \
        --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/share/tilemill/index.js /usr/local/bin/tilemill

RUN groupadd gis && useradd -g gis -m gis

# Set up database to allow import.
USER postgres
RUN /etc/init.d/postgresql start && \
    psql --command "CREATE USER gis;" && \
    createdb --owner gis gis && \
    psql --dbname=gis --file=/usr/share/postgresql/9.3/contrib/postgis-2.1/postgis.sql && \
    psql --dbname=gis --file=/usr/share/postgresql/9.3/contrib/postgis-2.1/spatial_ref_sys.sql && \
    psql --dbname=gis --file=/usr/share/postgresql/9.3/contrib/postgis-2.1/postgis_comments.sql && \
    psql --dbname=gis --command="GRANT SELECT ON spatial_ref_sys TO PUBLIC;" && \
    psql --dbname=gis --command="GRANT ALL ON geometry_columns TO gis;" && \
    echo "local gis gis peer" >> /etc/postgresql/9.3/main/pg_hba.conf

EXPOSE 8000

ENV SPOOL_DIR /var/spool/basemap
ENV STORAGE_DIR /var/lib/basemap
VOLUME ["${STORAGE_DIR}", "${SPOOL_DIR}"]

COPY basemap.sh /usr/local/bin/

# Start application. This runs as the gis user, which lets it use peer
# authentication with PostgreSQL (no password required).
# Note that the file provided as input must be readable by the gis user in the
# container.
USER gis
CMD basemap.sh

