import QtQuick
import "UsageModel.js" as Usage

// Change positions only: native widget objects and open-menu owners survive.
Item {
    id: layout
    property var counts: ({})
    property var cells: []
    readonly property var orderedCells: Usage.rank(cells, counts)
    implicitHeight: orderedCells.reduce(function(total, cell) { return total + cell.height; }, 0)
        + Math.max(0, orderedCells.length - 1) * 4
    height: implicitHeight
    function registerCell(cell) { cells = cells.concat([cell]); }
    function unregisterCell(cell) { cells = cells.filter(function(item) { return item !== cell; }); }
    function cellY(cell) {
        var offset = 0;
        for (var i = 0; i < orderedCells.length; i++) {
            if (orderedCells[i] === cell) return offset;
            offset += orderedCells[i].height + 4;
        }
        return 0;
    }
}
