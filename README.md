
This is a project for building and serving base maps in arbitrary projections.

## Configuration

Create a config directory:

```bash
cp -r config ../config
```

Edit `../config/basemap.yaml` to configure MapProxy for your needs.

## Building

```bash
sudo docker build -t vpac/basemap_data data
sudo docker build -t vpac/basemap_builder builder
sudo docker build -t vpac/basemap_server server
```

## Storage

The first time you build a base map, you need to initialise the storage volumes.

```bash
sudo docker-compose up data
```

If you want to control the storage, you can specify volumes. See
[data/Dockerfile](data/Dockerfile) for details.

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
sudo docker-compose run --rm builder
```

The data container will be used to store other datasets which will be
downloaded automatically by the script. They should be downloaded around the
same time as the planet file so that the coastlines match the other data. The
files are quite large, so you might like to keep them for a while - but delete
them if you want the script to download a fresh copy.

## Serving a Base Map

Simply start a `basemap_server` container.

```bash
sudo docker-compose up server
```

Then you should be able to view the maps by navigating to [localhost:8081][demo].

[gf]: http://download.geofabrik.de
[demo]: http://localhost:8081/demo
