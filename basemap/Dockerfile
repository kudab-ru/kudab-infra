# Подложка карт сайта: тайлы Воронежской области из OpenStreetMap в той же схеме, что у OpenFreeMap,
# со шрифтами и значками. Собирает `make basemap-build`, файлы ложатся в data/basemap, их раздаёт nginx.
ARG BBOX=38.0,49.5,43.0,52.2

FROM python:3.12-slim AS stubs
COPY stubs.py /stubs.py
RUN mkdir /stubs && python3 /stubs.py /stubs

FROM eclipse-temurin:21-jre AS tiles
ARG BBOX
ARG OSM_URL=https://download.geofabrik.de/russia/central-fed-district-latest.osm.pbf
ARG PLANETILER=0.10.2
ARG PLANETILER_SHA256=f310bd0413e2e4512b27f4046d418664e8e1d3bf31603c2a70e23de06c167e4d
WORKDIR /src
COPY --from=stubs /stubs ./
# что лежит в cache/, заново не качается: так собирают там, где у Docker медленная сеть
COPY cache/ ./
RUN set -e; \
    [ -f planetiler.jar ] || curl -fsSL -o planetiler.jar "https://github.com/onthegomap/planetiler/releases/download/v${PLANETILER}/planetiler.jar"; \
    echo "${PLANETILER_SHA256}  planetiler.jar" | sha256sum -c -; \
    [ -f lake_centerline.shp.zip ] || curl -fsSL -o lake_centerline.shp.zip https://github.com/acalcutt/osm-lakelines/releases/download/v12/lake_centerline.shp.zip; \
    [ -f region.osm.pbf ] || curl -fsSL -o region.osm.pbf "$OSM_URL"
# без перевода названий в латиницу, как у OpenFreeMap: иначе улицы подписаны «Kol'covskaâ ulica»
RUN java -Xmx3g -jar planetiler.jar \
      --transliterate=false \
      --osm_path=region.osm.pbf \
      --natural_earth_path=ne.sqlite.zip \
      --water_polygons_path=water.zip \
      --lake_centerlines_path=lake_centerline.shp.zip \
      --bounds="$BBOX" --output=/out/voronezh.pmtiles --tmpdir=/tmp/planetiler --force \
 && rm -rf /tmp/planetiler

FROM busybox:1.36
COPY --from=tiles /out/voronezh.pmtiles /basemap/voronezh.pmtiles
COPY fonts /basemap/fonts
COPY sprites /basemap/sprites
