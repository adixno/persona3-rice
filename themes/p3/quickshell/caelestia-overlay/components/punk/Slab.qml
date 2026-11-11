// Slanted card drawn as a vector path, so it stays crisp at fractional scaling
// (rotated Rectangles alias badly). Fill, outline and a hard offset shadow.
// The Shape sits inside a plain Item: a bare Shape derives its implicit size from
// its path bounds, and the offset shadow would make it grow on every update.
import QtQuick
import QtQuick.Shapes
import qs.services

Item {
    id: root

    property color fill: Colours.palette.m3primary
    property color outline: Colours.palette.m3onSurface
    property color shadow: Colours.palette.m3background
    property real outlineWidth: 3
    property real skew: 10 // horizontal lean in px
    property real shadowOffset: 5

    function quad(dx: real, dy: real): var {
        const s = skew, w = width - shadowOffset, h = height - shadowOffset;
        return [Qt.point(s + dx, dy), Qt.point(w + dx, dy), Qt.point(w - s + dx, h + dy), Qt.point(dx, h + dy), Qt.point(s + dx, dy)];
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.shadow
            strokeWidth: -1
            PathPolyline { path: root.quad(root.shadowOffset, root.shadowOffset) }
        }
        ShapePath {
            fillColor: root.fill
            strokeColor: root.outline
            strokeWidth: root.outlineWidth
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: root.quad(0, 0) }
        }
    }
}
