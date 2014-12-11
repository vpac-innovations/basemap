#!/bin/bash

shopt -s nullglob
echoerr() { cat <<< "$@" 1>&2; }

if [ ${NCPU} -eq 0 ]; then
    export NCPU=$(nproc)
fi

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
    local nImports
    nImports=0
    for f in ${SPOOL_DIR}/*.osm.pbf; do
        echo "Importing $f into database."
        osm2pgsql --slim -C 1500 --number-processes ${NCPU} ${f}
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

import_osm
get_coastlines

