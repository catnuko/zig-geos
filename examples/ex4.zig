/// Reads two WKT representations and calculates the intersection, prints it out,
/// and cleans up.
///
/// Ported from: src/geos/examples/capi_read.c
const c = @import("zig-geos");

const std = @import("std");
const handlers = @import("default_handlers");

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    // Send notice and error messages to our stdout handler
    c.initGEOS(handlers.shimNotice, handlers.shimError);

    // Clean up the global context
    defer c.finishGEOS();
    errdefer c.finishGEOS();

    const wkt_a = "LINESTRING(0 0 1, 1 1 1, 2 1 2)";
    
    const reader = c.GEOSWKTReader_create();
    defer c.GEOSWKTReader_destroy(reader);

    const geom_a = c.GEOSWKTReader_read(reader, wkt_a);
    defer c.GEOSGeom_destroy(geom_a);

    const geojson_writer = c.GEOSGeoJSONWriter_create();
    defer c.GEOSGeoJSONWriter_destroy(geojson_writer);

    const geojson = c.GEOSGeoJSONWriter_writeGeometry(geojson_writer,geom_a,2);
    defer c.GEOSFree(geojson);
    try stdout.print("{s}\n", .{geojson});
}
