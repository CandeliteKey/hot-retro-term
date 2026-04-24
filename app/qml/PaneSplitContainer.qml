/*******************************************************************************
* Copyright (c) 2013-2021 "Filippo Scognamiglio"
* https://github.com/Swordfish90/cool-retro-term
*
* This file is part of cool-retro-term.
*
* cool-retro-term is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*******************************************************************************/

import QtQuick
import QtQuick.Layouts

// Renders a split node from a PaneTreeNode.
// treeNode is the parent PaneTreeNode item.
Item {
    id: container
    anchors.fill: parent  // Fix A: Loader はロードされたアイテムをリサイズしないため明示指定

    // Set by PaneTreeNode's Loader.onLoaded
    property var treeNode: null

    readonly property var data_: treeNode ? treeNode.treeData : null
    readonly property var mgr:   treeNode ? treeNode.splitManager : null
    readonly property bool isHorizontal: data_ ? data_.orientation === Qt.Horizontal : true
    readonly property real ratio: data_ ? data_.ratio : 0.5

    // First child data with divider flag
    readonly property var firstData: {
        if (!data_ || !data_.first) return null
        var d = Object.assign({}, data_.first)
        if (isHorizontal) d._showDividerRight  = true
        else              d._showDividerBottom = true
        return d
    }
    readonly property var secondData: data_ ? data_.second : null

    // Horizontal split (left | right)
    Row {
        visible: isHorizontal
        anchors.fill: parent

        Loader {
            id: hFirst
            active: isHorizontal
            width:  parent.width * ratio
            height: parent.height
            source: container.firstData ? "PaneTreeNode.qml" : ""
            onLoaded: {
                item.anchors.fill = hFirst
                item.treeData = Qt.binding(function() { return container.firstData })
                item.splitManager = Qt.binding(function() { return container.mgr })
            }
        }
        Loader {
            id: hSecond
            active: isHorizontal
            width:  parent.width * (1 - ratio)
            height: parent.height
            source: container.secondData ? "PaneTreeNode.qml" : ""
            onLoaded: {
                item.anchors.fill = hSecond
                item.treeData = Qt.binding(function() { return container.secondData })
                item.splitManager = Qt.binding(function() { return container.mgr })
            }
        }
    }

    // Vertical split (top / bottom)
    Column {
        visible: !isHorizontal
        anchors.fill: parent

        Loader {
            id: vFirst
            active: !isHorizontal
            width:  parent.width
            height: parent.height * ratio
            source: container.firstData ? "PaneTreeNode.qml" : ""
            onLoaded: {
                item.anchors.fill = vFirst
                item.treeData = Qt.binding(function() { return container.firstData })
                item.splitManager = Qt.binding(function() { return container.mgr })
            }
        }
        Loader {
            id: vSecond
            active: !isHorizontal
            width:  parent.width
            height: parent.height * (1 - ratio)
            source: container.secondData ? "PaneTreeNode.qml" : ""
            onLoaded: {
                item.anchors.fill = vSecond
                item.treeData = Qt.binding(function() { return container.secondData })
                item.splitManager = Qt.binding(function() { return container.mgr })
            }
        }
    }

    // Invisible drag handle at the split boundary for resize
    MouseArea {
        id: resizeHandle
        z: 100
        x: isHorizontal ? parent.width * ratio - 4 : 0
        y: isHorizontal ? 0 : parent.height * ratio - 4
        width:  isHorizontal ? 8 : parent.width
        height: isHorizontal ? parent.height : 8
        cursorShape: isHorizontal ? Qt.SplitHCursor : Qt.SplitVCursor

        onPositionChanged: function(mouse) {
            if (!pressed || !mgr || !data_) return
            var mapped = mapToItem(container, mouse.x, mouse.y)
            var newRatio = isHorizontal
                ? mapped.x / container.width
                : mapped.y / container.height
            newRatio = Math.max(0.1, Math.min(0.9, newRatio))
            mgr.updateSplitRatio(mgr.findFirstTerminal(data_.first), newRatio)
        }
    }
}
