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

import QtQuick 2.2

Item {
    id: root

    property int tabCount: 0
    property int activeTabIndex: 0
    property var tabTitles: []
    property color fontColor: "#33ff00"
    property color backgroundColor: "#000000"
    property size charMetrics: Qt.size(8, 16)
    property font termFont

    visible: tabCount > 1
    z: 10

    // Number of chars for the [+] button
    readonly property int addBtnChars: 5
    // Total chars available for all tabs
    readonly property int totalTabChars: Math.max(0, Math.floor(width / charMetrics.width) - addBtnChars)
    // Chars allocated per tab
    readonly property int charsPerTab: tabCount > 0 ? Math.max(5, Math.floor(totalTabChars / tabCount)) : 5
    // Pixel width per tab
    readonly property real tabPixelWidth: charsPerTab * charMetrics.width
    // Pixel width for add button
    readonly property real addBtnPixelWidth: addBtnChars * charMetrics.width

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
    }

    Row {
        id: tabsRow
        height: parent.height

        Repeater {
            model: root.tabCount

            Item {
                id: tabItem
                width: root.tabPixelWidth
                height: root.charMetrics.height

                readonly property bool isActive: index === root.activeTabIndex

                Rectangle {
                    anchors.fill: parent
                    color: root.fontColor
                    visible: tabItem.isActive
                }

                Text {
                    anchors.fill: parent
                    text: root.buildTabLabel(index)
                    font: root.termFont
                    color: tabItem.isActive ? root.backgroundColor : root.fontColor
                    verticalAlignment: Text.AlignVCenter
                    clip: true
                    smooth: false
                }
            }
        }

        Text {
            id: addBtn
            width: root.addBtnPixelWidth
            height: root.charMetrics.height
            text: " [+] "
            font: root.termFont
            color: root.fontColor
            verticalAlignment: Text.AlignVCenter
            smooth: false
        }
    }

    function buildTabLabel(i) {
        var title = (tabTitles && i < tabTitles.length) ? tabTitles[i] : ""
        if (!title || title === "") title = "cool-retro-term"

        var prefix = " " + (i + 1) + ":"
        var maxContent = Math.max(1, charsPerTab - prefix.length - 1)

        if (title.length > maxContent)
            title = title.substring(0, maxContent - 1) + "\u2026"

        var label = prefix + title
        // Pad with spaces to fill the full tab width
        while (label.length < charsPerTab)
            label += " "

        return label.substring(0, charsPerTab)
    }

    // Returns tab index (0-based) for a given x pixel coordinate, or -1
    function hitTest(x) {
        if (tabPixelWidth <= 0 || tabCount <= 0) return -1
        var idx = Math.floor(x / tabPixelWidth)
        if (idx >= 0 && idx < tabCount) return idx
        return -1
    }

    // Returns true if x is within the [+] add button area
    function hitTestAddButton(x) {
        var addBtnStart = tabCount * tabPixelWidth
        return x >= addBtnStart && x < addBtnStart + addBtnPixelWidth
    }
}
