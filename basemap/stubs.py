"""Пустые береговые полигоны и пустой Natural Earth для сборщика тайлов.

Моря в области нет, а Natural Earth рисует только мелкие масштабы, которые сайт берёт у OpenFreeMap.
Без этих файлов сборщик не стартует, а настоящие из России не скачиваются.
"""
import sqlite3
import struct
import sys
import tempfile
import zipfile
from datetime import date
from pathlib import Path

out = Path(sys.argv[1])

# без проекции сборщик падает ещё на пустом файле: ему нужна система координат полигонов
PRJ = (
    'PROJCS["WGS 84 / Pseudo-Mercator",GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]],'
    'PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]],PROJECTION["Mercator_1SP"],PARAMETER["central_meridian",0],'
    'PARAMETER["scale_factor",1],PARAMETER["false_easting",0],PARAMETER["false_northing",0],UNIT["metre",1],'
    'AXIS["X",EAST],AXIS["Y",NORTH]]'
)


def shp_header() -> bytes:
    # заголовок полигонного shapefile без единой фигуры: длина 50 слов по 16 бит
    return struct.pack('>7i', 9994, 0, 0, 0, 0, 0, 50) + struct.pack('<2i', 1000, 5) + struct.pack('<8d', *[0.0] * 8)


def dbf() -> bytes:
    d = date.today()
    head = struct.pack('<B3BIHH20x', 3, d.year - 1900, d.month, d.day, 0, 65, 11)
    field = struct.pack('<11sc4xBB14x', b'FID'.ljust(11, b'\0'), b'N', 10, 0)
    return head + field + b'\r\x1a'


with zipfile.ZipFile(out / 'water.zip', 'w') as z:
    for ext, body in (('shp', shp_header()), ('shx', shp_header()), ('dbf', dbf()), ('prj', PRJ.encode())):
        z.writestr(f'water_polygons.{ext}', body)

with tempfile.TemporaryDirectory() as tmp:
    db = Path(tmp) / 'natural_earth_vector.sqlite'
    sqlite3.connect(db).close()
    with zipfile.ZipFile(out / 'ne.sqlite.zip', 'w') as z:
        z.write(db, 'natural_earth_vector.sqlite')
