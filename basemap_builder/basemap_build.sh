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

function put_meta() {
    local dbopts name value
    dbopts=(-U ${DB_ENV_USER} -d ${DB_ENV_SCHEMA} -h db)
    name=${1}
    value=${2}
    export PGPASSWORD=${DB_ENV_PASSWORD}

    # Create table, but ignore error if it already exists.
    psql ${dbopts[*]} --command="
        CREATE TABLE basemap_meta (name text PRIMARY KEY, value text);" 2>&1 | \
            grep -v "relation .* already exists"

    # This is a dodgy upsert, but we don't care about security nor
    # concurrency in this script.
    # http://stackoverflow.com/a/6527838/320036
    psql ${dbopts[*]} --command="
        UPDATE basemap_meta SET value='${value}' WHERE name='${name}';
        INSERT INTO basemap_meta (name, value)
            SELECT '${name}', '${value}'
            WHERE NOT EXISTS (
                SELECT 1 FROM basemap_meta WHERE name='${name}');" 1>&2
    return $?
}

function get_meta() {
    local dbopts name value
    dbopts=(-U ${DB_ENV_USER} -d ${DB_ENV_SCHEMA} -h db)
    name=${1}
    export PGPASSWORD=${DB_ENV_PASSWORD}
    psql ${dbopts[*]} -t \
        --command="SELECT value FROM basemap_meta WHERE name='${name}';" \
        2>/dev/null | head -n 1 | sed 's, ,,'
    return $?
}

function init_database() {
    local dbopts
    dbopts=(-U ${DB_ENV_USER} -d ${DB_ENV_SCHEMA} -h db)
    export PGPASSWORD=${DB_ENV_PASSWORD}
    psql ${dbopts[*]} --command="SELECT PostGIS_full_version();" 2>&1 > /dev/null
    if [ $? -eq 0 ]; then
       echo "PostGIS already imported."
       return 0
    fi

    echo "Setting up PostGIS functions."
    psql ${dbopts[*]} \
        --command="CREATE EXTENSION postgis; CREATE EXTENSION postgis_topology;"
    if [ $? -ne 0 ]; then
        echoerr "Failed to set up PostGIS."
        exit 1
    fi
}

function get_extra() {
    local base url
    mkdir -p ${SPOOL_DIR}/extras
    pushd ${SPOOL_DIR}/extras >/dev/null

    base=${1}
    url=${2}
    is_zip_bomb=${3}

    if [ ! -d ${base} ]; then
        if [ ! -f ${base}.zip ]; then
            wget ${url}
            if [ $? -ne 0 ]; then
                echoerr "Failed to fetch extra data file."
                exit 1
            fi
        fi
        if [ x${is_zip_bomb} = x'true' ]; then
            mkdir -p ${base}
            pushd ${base} >/dev/null
            unzip -o ../${base}.zip
            popd >/dev/null
        else
            unzip -o ${base}.zip
        fi
    fi
    if [ ! -f ${base}/*.index ]; then
        shapeindex ${base}/*.shp
    fi

    popd >/dev/null
}

# Get coastlines etc. These are separate from the osm database that would be
# downloaded by the user, but it is derived from OSM data periodically. See
# http://openstreetmapdata.com/data/land-polygons
function get_extras() {
    get_extra "simplified-land-polygons-complete-3857" \
        http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip
    get_extra "land-polygons-split-3857" \
        http://data.openstreetmapdata.com/land-polygons-split-3857.zip
    get_extra "10m-populated-places-simple" \
        http://mapbox-geodata.s3.amazonaws.com/natural-earth-1.4.0/cultural/10m-populated-places-simple.zip \
        true
}

function import_osm() {
    local nImports dbopts opts checksum oldChecksum
    dbopts=(-U ${DB_ENV_USER} -d ${DB_ENV_SCHEMA} -H db)

    # Generate a checksum to detect whether the files have changed since the
    # last import.
    checksum=$(find ${SPOOL_DIR} -maxdepth 1 -type f -name '*.osm.pbf' -exec sha1sum {} \; | sort -k 42 | sha1sum | sed 's,\s\+-$,,')
    old_checksum=$(get_meta checksum)
    if [ "x${old_checksum}" = "x${checksum}" ]; then
        echo "OSM planet files have already been imported."
        return 0
    fi

    opts=(--create)
    nImports=0
    export PGPASSWORD=${DB_ENV_PASSWORD}
    for f in ${SPOOL_DIR}/*.osm.pbf; do
        echo "Importing $f into database."
        osm2pgsql --slim -C 1500 \
            --number-processes ${NCPU} \
            ${dbopts[*]} ${opts[*]} \
            ${f}
        if [ $? -ne 0 ]; then
            echoerr "Failed to import data."
            exit 1
        fi
        opts=(--append)
        nImports=$(( $nImports + 1 ))
    done
    if [ $nImports -eq 0 ]; then
        echoerr "No datasets to import. Is there a volume mounted at ${SPOOL_DIR}?"
        exit 1
    else
        echo "Imported $nImports planet files."
    fi

    put_meta checksum ${checksum}
}

function generate_style() {
    echo "Generating stylesheet."
    pushd ${SPOOL_DIR} >/dev/null

    if [ ! -d osm-bright ]; then
        git clone https://github.com/mapbox/osm-bright.git
    fi
    cd osm-bright

    export PGPASSWORD=${DB_ENV_PASSWORD}
    patch_mml.py \
        -d ${DB_ENV_SCHEMA} \
        -H db \
        -p ${DB_PORT_5432_TCP_PORT} \
        -U ${DB_ENV_USER} \
        -f simplified-land-polygons-complete-3857.zip \
            ${SPOOL_DIR}/extras/simplified-land-polygons-complete-3857/simplified-land-polygons.shp \
        -f land-polygons-split-3857.zip \
            ${SPOOL_DIR}/extras/land-polygons-split-3857/land-polygons.shp \
        -f 10m-populated-places-simple.zip \
            ${SPOOL_DIR}/extras/10m-populated-places-simple/10m-populated-places-simple.shp \
        osm-bright/osm-bright.osm2pgsql.mml \
        osm-bright/osm-bright-basemap.mml

    if [ $? -ne 0 ]; then
        echoerr "Failed to patch OSM Bright model file."
        exit 1
    fi

    mkdir -p ${SPOOL_DIR}/style
    carto osm-bright/osm-bright-basemap.mml > ${SPOOL_DIR}/style/basemap.xml

    if [ $? -ne 0 ]; then
        echoerr "Failed to generate Mapnik style."
        exit 1
    fi

    find osm-bright -maxdepth 1 -type d -exec cp -r {} ${SPOOL_DIR}/style/ ';'

    echo "Style written to SPOOL_DIR/style/basemap.xml"

    popd >/dev/null
}

function generate_tiles() {
    echo "Generating tile set."
}

function serve_tiles() {
    echo "Serving tiles."
}

init_database
import_osm
get_extras
generate_style

