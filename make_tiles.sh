#!/bin/bash

planetFile=$1

if [ ! -r ${planetFile} ]; then
  echo "Error: planet file ${planetFile} can not be read."
  exit 1
fi

# Get coastlines. These are separate from the osm database that would be
# downloaded by the user, but it is derived from OSM data periodically. See
# http://openstreetmapdata.com/data/land-polygons
function get_coastlines() {
    mkdir -p coastlines
    pushd coastlines
    if [ ! -d "simplified-land-polygons-complete-3857" ]; then
        wget http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip
        unzip simplified-land-polygons-complete-3857.zip
        shapeindex simplified-land-polygons-complete-3857/simplified_land_polygons.shp
    fi
    if [ ! -d "land-polygons-split-3857" ]; then
        wget http://data.openstreetmapdata.com/land-polygons-split-3857.zip
        unzip land-polygons-split-3857.zip
        shapeindex land-polygons-split-3857/land_polygons.shp
    fi
    popd
}

get_coastlines

# First import the planet file.
echo "Importing planet file."
osm2pgsql -U gis -d gis --slim -C 1500 --number-processes 4 ${planetFile}

