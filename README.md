# [zig-geos](https://github.com/guidorice/libgeos.zig.git)
[Zig](https://ziglang.org) bindings for the [GEOS C library (libgeos)](https://libgeos.org/)

> GEOS (Geometry Engine, Open Source) is a C/C++ library for spatial computational geometry of the sort generally used by “geographic information systems” software. GEOS is a core dependency of PostGIS, QGIS, GDAL, and Shapely.

## GEOS version

`3.13.0`

## Zig version

* `0.13`

## Build

Requires only `zig`. Don't forget to clone/init the submodule!

```shell
git clone --recurse-submodules https://github.com/guidorice/libgeos.zig.git
cd libgeos.zig/
zig build
```

## Tests

```shell
zig build test
```

## Examples

```shell
$ zig build --help
$ zig build run-ex1
Geometry A:         POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))
Geometry B:         POLYGON((5 5, 15 5, 15 15, 5 15, 5 5))
Intersection(A, B): POLYGON ((10 10, 10 5, 5 5, 5 10, 10 10))
```

## Known Issues

* blocker: The libgeos library uses C++ `std::runtime_error`, which is not currently
captured by the Zig wrapper code. As a result, there is no way to recover from
some error conditions, for example, failing to parse some WKT formatted string.
[see issue #9](https://github.com/guidorice/libgeos.zig/issues/9)

## Roadmap

* [x] Minimal build.zig. Builds libgeos entirely using Zig compiler and build system.
* [x] Create example exe using this package as a Zig library.
* [x] Port libgeos C examples to Zig (from src/geos/examples)
  * [x] [Ex 1](src/examples/ex1.zig) Reads two WKT representations and calculates the intersection, prints it out, and cleans up.
  * [x] [Ex 1 (threadsafe)](src/examples/ex1_threadsafe.zig)
  * [x] [Ex 2](src/examples/ex2.zig) Reads one geometry and does high-performance prepared geometry operations to place "random" points inside it.
  * [x] [Ex 3](src/examples/ex3.zig) Build a spatial index and search it for a nearest pair.
  * [x] [Ex 4](src/examples/ex4.zig) Read and write geojson.

## Notes

See also [vendor/geos/README](src/vendor/geos/README.md) for how libgeos is
updated within this repo.
