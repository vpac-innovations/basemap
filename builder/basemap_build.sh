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

function wait_for_database() {
    export PGPASSWORD=${DB_ENV_PASSWORD}
    until psql  -U ${DB_ENV_USER} -d ${DB_ENV_SCHEMA} -h db -c '\l'; do
      >&2 echo "Waiting for PostGIS to initialize"
      sleep 5
    done

    >&2 echo "PostGIS is up - building basemap"
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

    dropdb -U ${DB_ENV_USER} -h db ${DB_ENV_SCHEMA}
    createdb -O ${DB_ENV_USER} -U ${DB_ENV_USER} -E UTF8 -T "template0" -h db ${DB_ENV_SCHEMA}

    echo "Setting up PostGIS functions."
    psql ${dbopts[*]} \
        --command="CREATE EXTENSION postgis; CREATE EXTENSION postgis_topology;"
    if [ $? -ne 0 ]; then
        echoerr "Failed to set up PostGIS."
        exit 1
    fi


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

    # Download dependencies.
    # Keep Millstone cache in the volume so it can be reused. It's not
    # configurable in Millstone itself yet.
    mkdir -p ${SPOOL_DIR}/cache && \
        ln -fs ${SPOOL_DIR}/cache /tmp/millstone-test && \
        millstone osm-bright/osm-bright.osm2pgsql.mml > osm-bright/osm-bright-resolved.mml

    if [ $? -ne 0 ]; then
        echoerr "Failed to fetch supplementary data."
        exit 1
    fi

    # Insert database connection settings.
    export PGPASSWORD=${DB_ENV_PASSWORD}
    patch_mml.py \
        -d ${DB_ENV_SCHEMA} \
        -H db \
        -p ${DB_PORT_5432_TCP_PORT} \
        -U ${DB_ENV_USER} \
        osm-bright/osm-bright-resolved.mml \
        osm-bright/osm-bright-basemap.mml

    if [ $? -ne 0 ]; then
        echoerr "Failed to patch OSM Bright model file."
        exit 1
    fi

    # Convert to Mapnik XML.
    mkdir -p ${STORAGE_DIR}/style
    carto osm-bright/osm-bright-basemap.mml > ${STORAGE_DIR}/style/basemap.xml

    if [ $? -ne 0 ]; then
        echoerr "Failed to generate Mapnik style."
        exit 1
    fi

    find osm-bright -mindepth 1 -maxdepth 1 -type d -exec \
        cp -r {} ${STORAGE_DIR}/style/ ';'

    echo "Style written to \$STORAGE_DIR/style/basemap.xml"

    popd >/dev/null
}

wait_for_database
init_database
import_osm
generate_style
