
## Building

```bash
sudo docker build -t vpac/basemap_data data
sudo docker build -t vpac/basemap_builder builder
sudo docker build -t vpac/basemap_server server
```

## Storage

The first time you build a base map, you need to initialise the storage volumes.

```bash
sudo docker run --name basemap_data vpac/basemap_data
```

The container will stop immediately, but don't remove it, or the data collected
in the following steps will be lost. You can see the data by mounting it in
another container, e.g.

```bash
sudo docker run --rm --volumes-from basemap_data ubuntu ls /var/spool/basemap
```


## Building a Base Map

Download a planet file to the data container's spool directory. All `.osm.pbf`
files in this directory will be imported, and any old data will be deleted (if
the planet files have changed since the last run). In this example, the planet
file for Australia is used - but [other countries are available][gf] too.

```bash
sudo docker run --rm --volumes-from basemap_data ubuntu bash -c "
    apt-get install -y wget &&
    wget -P /var/spool/basemap http://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf"
```

Then run the builder in the context of a PostGIS server.

```bash
sudo docker run -d --name postgis jamesbrink/postgresql
sudo docker run --rm \
    --link postgis:db \
    -e NCPU=8 \
    --volumes-from basemap_data \
    vpac/basemap_builder
```

The data container will be used to store other datasets which will be
downloaded automatically by the script. They should be downloaded around the
same time as the planet file so that the coastlines match the other data. The
files are quite large, so you might like to keep them for a while - but delete
them if you want the script to download a fresh copy.

## Serving a Base Map

Once you have some tiles in `data/tiles`, simply start a `basemap_server`
container.

```bash
sudo docker run -d --name basemap_server \
    --link postgis:db \
    --volumes-from basemap_data \
    --publish 8080:8080 \
    vpac/basemap_server
```

[gf]: http://download.geofabrik.de

