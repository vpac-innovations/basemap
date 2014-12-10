FROM ubuntu:14.04

MAINTAINER Alex Fraser <alex@vpac-innovations.com.au>

RUN export DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND noninteractive

# Suff for working with OSM data
# Note: nodejs from this PPA conflicts with nodejs-legacy; both provide the
# node executable so only this one is needed.
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:developmentseed/mapbox && \
    apt-get update && \
    apt-get install -y libmapnik mapnik-utils nodejs osm2pgsql tilemill && \
    apt-get install -y postgresql postgis unzip && \
    apt-get install -y virtualenvwrapper python-pip && \
    rm -rf /var/lib/apt/lists/*

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
VOLUME ["/var/lib/basemap", "/var/spool/basemap"]

# Get coastlines. These are separate from the osm database that would be
# downloaded by the user, but it is derived from OSM data periodically. See
# http://openstreetmapdata.com/data/land-polygons
USER gis
#RUN wget http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip
#RUN wget http://data.openstreetmapdata.com/land-polygons-split-3857.zip

# Start application. This runs as the gis user, which lets it use peer
# authentication with PostgreSQL (no password required).
# Note that the file provided as input must be readable by the gis user in the
# container.
CMD /bin/bash
#ENTRYPOINT ["make_tiles.sh"]

