// The calendar's cursor: one flat, lopsided triangle. (0, 0) is the centre of the day's
// number: the tip sits just above it, the long corner trails off to the lower left.
// u = the screen's scale unit (height / 720).
import QtQuick
import QtQuick.Shapes

Shape {
    id: tri
    property color c
    property real u: 1
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeWidth: -1
        fillColor: tri.c
        PathPolyline {
            path: [Qt.point(3 * tri.u, -31 * tri.u), Qt.point(45 * tri.u, 17 * tri.u), Qt.point(-60 * tri.u, 40 * tri.u), Qt.point(3 * tri.u, -31 * tri.u)]
        }
    }
}
