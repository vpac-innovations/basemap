
## Building

```bash
sudo docker build -t basemap_builder basemap_builder
sudo docker build -t basemap_server basemap_server
```

## Building a Base Map

Download a planet file to the spool directory. All `.osm.pbf` files in the spool
directory will be imported, and any old data will be deleted (if the planet
files have changed since the last run). In this example, the planet file for
Australia is used - but [other countries are available][gf] too.

```bash
mkdir -p data/spool
mkdir -p data/tiles
pushd data/spool && \
    wget http://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf && \
    popd
```

Then run the builder in the context of a PostGIS server.

```bash
sudo docker pull jamesbrink/postgresql
sudo docker run -d --name postgis jamesbrink/postgresql
sudo docker run --rm --link postgis:db \
    -e NCPU=8 \
    -v $PWD/data/spool:/var/spool/basemap \
    -v $PWD/data/tiles:/var/lib/basemap \
    -t basemap_builder
```

When the process has completed, you should have a set of tiles in the
`data/tiles` directory. These can be served by `basemap_server` (see below).

The `spool/cache` directory will be used to store other data which will be
downloaded automatically by the script. They should be downloaded around the
same time as the planet file so that the coastlines match the other data. The
files are quite large, so you might like to keep them for a while - but delete
them if you want the script to download a fresh copy.

## Serving a Base Map

Once you have some tiles in `data/tiles`, simply start a `basemap_server`
container.

```bash
sudo docker run --rm -d --name basemap_server \
    -p localhost:8080:8080
    -v $PWD/data/spool:/var/spool/basemap \
    -v $PWD/data/tiles:/var/lib/basemap \
    -t basemap_server
```

[gf]: http://download.geofabrik.de

