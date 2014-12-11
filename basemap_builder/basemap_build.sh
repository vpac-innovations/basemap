#!/bin/bash

shopt -s nullglob
echoerr() { cat <<< "$@" 1>&2; }

if [ ${NCPU} -eq 0 ]; then
    export NCPU=$(nproc)
fi

if [ x${DB_ENV_SCHEMA} == x ]; then
    echoerr "No database found. Link to a PostGIS container with the alias 'db'."
    exit 1
fi

function init_database() {
    local dbopts
    dbopts=(-U ${DB_ENV_USER} -d ${DB_ENV_SCHEMA} -h db)
    export PGPASSWORD=${DB_ENV_PASSWORD}
    psql ${dbopts[*]} --command "SELECT PostGIS_full_version();" 2>/dev/null
    if [ $? -eq 0 ]; then
        return 0
    fi

    echo "Setting up PostGIS functions."
    psql ${dbopts[*]} --file=/usr/share/postgresql/9.3/contrib/postgis-2.1/postgis.sql && \
    psql ${dbopts[*]} --file=/usr/share/postgresql/9.3/contrib/postgis-2.1/spatial_ref_sys.sql && \
    psql ${dbopts[*]} --file=/usr/share/postgresql/9.3/contrib/postgis-2.1/postgis_comments.sql && \
    psql ${dbopts[*]} --command="GRANT SELECT ON spatial_ref_sys TO PUBLIC;" && \
    psql ${dbopts[*]} --command="GRANT ALL ON geometry_columns TO ${DB_ENV_USER};"
    if [ $? -ne 0 ]; then
        echoerr "Failed to set up PostGIS."
        exit 1
    fi
}

# Get coastlines. These are separate from the osm database that would be
# downloaded by the user, but it is derived from OSM data periodically. See
# http://openstreetmapdata.com/data/land-polygons
function get_coastlines() {
    mkdir -p ${SPOOL_DIR}/coastlines
    pushd ${SPOOL_DIR}/coastlines
    if [ ! -d "simplified-land-polygons-complete-3857" ]; then
        echo "Getting simplified global coastlines."
        wget http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip
        unzip simplified-land-polygons-complete-3857.zip
        shapeindex simplified-land-polygons-complete-3857/simplified_land_polygons.shp
    else
        echo "Reusing existing simplified global coastlines."
    fi
    if [ ! -d "land-polygons-split-3857" ]; then
        echo "Getting detailed global coastlines."
        wget http://data.openstreetmapdata.com/land-polygons-split-3857.zip
        unzip land-polygons-split-3857.zip
        shapeindex land-polygons-split-3857/land_polygons.shp
    else
        echo "Reusing existing detailed global coastlines."
    fi
    popd
}

function import_osm() {
    local nImports dbopts
    dbopts=(-U ${DB_ENV_USER} -d ${DB_ENV_SCHEMA} -H db)
    nImports=0
    export PGPASSWORD=${DB_ENV_PASSWORD}
    for f in ${SPOOL_DIR}/*.osm.pbf; do
        echo "Importing $f into database."
        osm2pgsql --slim -C 1500 \
            --number-processes ${NCPU} \
            ${dbopts[*]} \
            ${f}
        if [ $? -ne 0 ]; then
            echoerr "Failed to import data."
            exit 1
        fi
        nImports=$(( $nImports + 1 ))
    done
    if [ $nImports -eq 0 ]; then
        echoerr "No datasets to import. Is there a volume mounted at ${SPOOL_DIR}?"
        exit 1
    else
        echo "Imported $nImports planet files."
    fi
}

function generate_style() {
    echo "Generating stylesheet."
}

function generate_tiles() {
    echo "Generating tile set."
}

function serve_tiles() {
    echo "Serving tiles."
}

init_database
import_osm
get_coastlines

