/// Reads two WKT representations and calculates the intersection, prints it out,
/// and cleans up.
///
/// Ported from: src/geos/examples/capi_read.c
const c = @import("zig-geos");

const std = @import("std");

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    // Send notice and error messages to our stdout handler
    c.initGEOS(c.shimNotice, c.shimError);

    // Clean up the global context
    defer c.finishGEOS();
    errdefer c.finishGEOS();

    // Two squares that overlap
    const wkt_a = "POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))";
    const wkt_b = "POLYGON((5 5, 15 5, 15 15, 5 15, 5 5))";

    // Read the WKT into geometry objects
    const reader = c.GEOSWKTReader_create();
    defer c.GEOSWKTReader_destroy(reader);

    const geom_a = c.GEOSWKTReader_read(reader, wkt_a);
    defer c.GEOSGeom_destroy(geom_a);
    const geom_b = c.GEOSWKTReader_read(reader, wkt_b);
    defer c.GEOSGeom_destroy(geom_b);

    // Calculate the intersection
    const inter = c.GEOSIntersection(geom_a, geom_b);
    defer c.GEOSGeom_destroy(inter);

    // Convert result to WKT
    const writer = c.GEOSWKTWriter_create();
    defer c.GEOSWKTWriter_destroy(writer);

    // Trim trailing zeros off output
    c.GEOSWKTWriter_setTrim(writer, 1);
    const wkt_inter = c.GEOSWKTWriter_write(writer, inter);
    defer c.GEOSFree(wkt_inter);

    // Print answer
    try stdout.print("Geometry A:         {s}\n", .{wkt_a});
    try stdout.print("Geometry B:         {s}\n", .{wkt_b});
    try stdout.print("Intersection(A, B): {s}\n", .{wkt_inter});

    // | Clean up everything we allocated
    // | Clean up the global context
    // |-> *see zig defer statements above*
}
