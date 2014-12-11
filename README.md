
## Building

```bash
sudo docker build -t basemap_builder basemap_builder
sudo docker build -t basemap_server basemap_server
```

## Building a Base Map

Download a planet file.

```bash
mkdir -p data/spool
mkdir -p data/tiles
pushd data/spool && \
    wget http://download.geofabrik.de/australia-oceania/australia-latest.osm.bz2 && \
    popd
```

Run the builder in the context of a PostGIS server, using 

```bash
sudo docker pull jamesbrink/postgresql
sudo docker run -d --name postgis jamesbrink/postgresql
sudo docker run --rm --link postgis:db \
    -v $PWD/data/spool:/var/spool/basemap \
    -v $PWD/data/tiles:/var/lib/basemap \
    -t basemap_builder
```

