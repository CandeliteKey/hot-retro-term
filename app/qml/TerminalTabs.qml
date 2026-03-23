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
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import Qt5Compat.GraphicalEffects
import CoolRetroTerm 1.0

Item {
    id: tabsRoot

    readonly property int innerPadding: 6
    readonly property string currentTitle: tabsModel.get(currentIndex).title ?? "cool-retro-term"
    property int currentIndex: 0
    readonly property int count: tabsModel.count
    property size terminalSize: Qt.size(0, 0)

    readonly property int tabWidth: 160
    readonly property int tabBarHeight: 28
    property real scrollTargetX: 0

    property int titleRevision: 0

    // Split pane state
    property var splitTrees: []
    property int nextPaneId: 0
    property int focusedPaneId: -1
    property bool isCurrentTab: true

    // Terminal pool — terminals live here and are reparented into PaneTreeNode slots
    property alias terminalPool: terminalPool
    property var _terminals: ({})
    property var _terminalComponent: null

    Item {
        id: terminalPool
        visible: false
    }

    function createTerminal(paneId) {
        if (!_terminalComponent) {
            _terminalComponent = Qt.createComponent("TerminalContainer.qml")
        }
        if (_terminalComponent.status !== Component.Ready) {
            console.error("TerminalPool: failed to create component:", _terminalComponent.errorString())
            return null
        }
        var obj = _terminalComponent.createObject(terminalPool, { paneId: paneId })
        _terminals[paneId] = obj
        return obj
    }

    function getTerminal(paneId) {
        return _terminals[paneId] || null
    }

    function destroyTerminal(paneId) {
        var t = _terminals[paneId]
        if (t) {
            t.destroy()
            delete _terminals[paneId]
        }
    }

    function collectTitles() {
        titleRevision; // binding dependency — incremented on title changes
        var titles = []
        for (var i = 0; i < tabsModel.count; i++)
            titles.push(tabsModel.get(i).title || "cool-retro-term")
        return titles
    }

    function normalizeTitle(rawTitle) {
        if (rawTitle === undefined || rawTitle === null) {
            return ""
        }
        return String(rawTitle).trim()
    }

    function addTab() {
        var paneId = nextPaneId++
        createTerminal(paneId)
        tabsModel.append({ title: "" })
        var newTrees = splitTrees.slice()
        newTrees.push({ type: "terminal", paneId: paneId })
        splitTrees = newTrees
        tabsRoot.currentIndex = tabsModel.count - 1
        focusedPaneId = paneId
    }

    function closeTab(index) {
        // Destroy all terminals belonging to this tab
        var tree = splitTrees[index]
        if (tree) {
            var paneIds = collectTerminals(tree)
            for (var i = 0; i < paneIds.length; i++)
                destroyTerminal(paneIds[i])
        }

        if (tabsModel.count <= 1) {
            terminalWindow.close()
            return
        }

        var newTrees = splitTrees.slice()
        newTrees.splice(index, 1)
        splitTrees = newTrees
        tabsModel.remove(index)
        tabsRoot.currentIndex = Math.min(tabsRoot.currentIndex, tabsModel.count - 1)
        if (splitTrees[tabsRoot.currentIndex]) {
            focusedPaneId = findFirstTerminal(splitTrees[tabsRoot.currentIndex])
        }
    }

    function splitPane(orientation) {
        var tree = splitTrees[currentIndex]
        if (!tree) return
        if (countTerminals(tree) >= 4) return
        var newPaneId = nextPaneId++
        createTerminal(newPaneId)
        var newTrees = splitTrees.slice()
        newTrees[currentIndex] = replaceNode(tree, focusedPaneId, {
            type: "split", orientation: orientation, ratio: 0.5,
            first: { type: "terminal", paneId: focusedPaneId },
            second: { type: "terminal", paneId: newPaneId }
        })
        splitTrees = newTrees
        focusedPaneId = newPaneId
    }

    function closePane(paneId) {
        var tree = splitTrees[currentIndex]
        if (!tree) return
        var termCount = countTerminals(tree)
        if (termCount <= 1) {
            closeTab(currentIndex)
            return
        }
        destroyTerminal(paneId)
        var newTrees = splitTrees.slice()
        newTrees[currentIndex] = removeNode(tree, paneId)
        splitTrees = newTrees
        focusedPaneId = findFirstTerminal(splitTrees[currentIndex])
    }

    function moveFocus(direction) {
        // Simple heuristic: find adjacent pane in the tree
        var tree = splitTrees[currentIndex]
        if (!tree) return
        var allPanes = collectTerminals(tree)
        if (allPanes.length <= 1) return
        var currentIdx = allPanes.indexOf(focusedPaneId)
        if (currentIdx < 0) return
        var targetIdx = currentIdx
        if (direction === "right" || direction === "down") {
            targetIdx = (currentIdx + 1) % allPanes.length
        } else {
            targetIdx = (currentIdx - 1 + allPanes.length) % allPanes.length
        }
        focusedPaneId = allPanes[targetIdx]
    }

    // --- Tree helpers ---

    function countTerminals(node) {
        if (!node) return 0
        if (node.type === "terminal") return 1
        return countTerminals(node.first) + countTerminals(node.second)
    }

    function collectTerminals(node) {
        if (!node) return []
        if (node.type === "terminal") return [node.paneId]
        return collectTerminals(node.first).concat(collectTerminals(node.second))
    }

    function findFirstTerminal(node) {
        if (!node) return -1
        if (node.type === "terminal") return node.paneId
        return findFirstTerminal(node.first)
    }

    function replaceNode(node, paneId, newNode) {
        if (!node) return node
        if (node.type === "terminal") return node.paneId === paneId ? newNode : node
        return {
            type: "split", orientation: node.orientation, ratio: node.ratio,
            first: replaceNode(node.first, paneId, newNode),
            second: replaceNode(node.second, paneId, newNode)
        }
    }

    function removeNode(node, paneId) {
        if (!node) return node
        if (node.type === "terminal") return node
        if (node.first && node.first.type === "terminal" && node.first.paneId === paneId)
            return node.second
        if (node.second && node.second.type === "terminal" && node.second.paneId === paneId)
            return node.first
        return {
            type: "split", orientation: node.orientation, ratio: node.ratio,
            first: removeNode(node.first, paneId),
            second: removeNode(node.second, paneId)
        }
    }

    function ensureTabVisible(idx) {
        var x = idx * tabWidth
        if (x < scrollTargetX) {
            scrollTargetX = x
        } else if (x + tabWidth > scrollTargetX + tabsFlickable.width) {
            scrollTargetX = x + tabWidth - tabsFlickable.width
        }
        tabsFlickable.contentX = scrollTargetX
    }

    onCurrentIndexChanged: {
        ensureTabVisible(currentIndex)
        isCurrentTab = true
        if (splitTrees[currentIndex]) {
            focusedPaneId = findFirstTerminal(splitTrees[currentIndex])
        }
    }

    // Expose tabsModel so PaneTreeNode can reference it via splitManager
    property alias tabsModel: tabsModel

    ListModel {
        id: tabsModel
    }

    Component.onCompleted: addTab()

    CurvatureInputFilter {
        targetItem: contentColumn
        curvature: appSettings.windowCurvature > 0
            ? appSettings.windowCurvature * appSettings.screenCurvatureSize * (1024 / (0.5 * contentColumn.width + 0.5 * contentColumn.height))
            : 0
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 0

        layer.enabled: appSettings.windowCurvature > 0
        layer.effect: ShaderEffect {
            property real screenCurvature: appSettings.windowCurvature * appSettings.screenCurvatureSize * (1024 / (0.5 * width + 0.5 * height))
            vertexShader: "qrc:/shaders/window_curvature.vert.qsb"
            fragmentShader: "qrc:/shaders/window_curvature.frag.qsb"
        }

        Rectangle {
            id: tabRow
            Layout.fillWidth: true
            Layout.preferredHeight: 0
            height: 0
            color: appSettings.backgroundColor
            visible: false

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Flickable {
                    id: tabsFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    contentWidth: tabsContainer.width
                    contentHeight: height
                    interactive: false

                    Behavior on contentX {
                        SmoothedAnimation { velocity: 1600; duration: -1 }
                    }

                    Item {
                        id: tabsContainer
                        width: Math.max(tabsFlickable.width, tabsModel.count * tabWidth)
                        height: tabBarHeight

                        property int draggingIndex: -1
                        property real draggingX: 0

                        Repeater {
                            model: tabsModel

                            Item {
                                id: tabDelegate
                                width: tabWidth
                                height: tabBarHeight

                                property bool isCurrentTab: index === tabsRoot.currentIndex
                                property bool isDragging: tabsContainer.draggingIndex === index

                                property real baseX: {
                                    if (tabsContainer.draggingIndex < 0 || index === tabsContainer.draggingIndex)
                                        return index * tabWidth
                                    var di = tabsContainer.draggingIndex
                                    var targetIdx = Math.max(0, Math.min(tabsModel.count - 1,
                                                             Math.round(tabsContainer.draggingX / tabWidth)))
                                    if (di < targetIdx) {
                                        if (index > di && index <= targetIdx)
                                            return (index - 1) * tabWidth
                                    } else if (di > targetIdx) {
                                        if (index >= targetIdx && index < di)
                                            return (index + 1) * tabWidth
                                    }
                                    return index * tabWidth
                                }

                                x: isDragging ? tabsContainer.draggingX : baseX

                                Behavior on x {
                                    enabled: !tabDelegate.isDragging
                                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                                }

                                z: isDragging ? 10 : 1

                                Rectangle {
                                    id: tabBg
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    color: isCurrentTab
                                        ? Qt.rgba(appSettings.fontColor.r, appSettings.fontColor.g, appSettings.fontColor.b, 0.15)
                                        : "transparent"
                                    border.color: Qt.rgba(appSettings.fontColor.r, appSettings.fontColor.g, appSettings.fontColor.b,
                                                          isCurrentTab ? 1.0 : 0.35)
                                    border.width: 1

                                    layer.enabled: isCurrentTab
                                    layer.effect: Glow {
                                        radius: 6
                                        samples: 13
                                        color: appSettings.fontColor
                                        spread: 0.1
                                    }
                                }

                                Label {
                                    anchors.left: parent.left
                                    anchors.right: closeBtn.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: innerPadding
                                    anchors.rightMargin: 2
                                    text: model.title || "cool-retro-term"
                                    elide: Text.ElideRight
                                    color: Qt.rgba(appSettings.fontColor.r, appSettings.fontColor.g, appSettings.fontColor.b,
                                                   isCurrentTab ? 1.0 : 0.5)
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                }

                                Text {
                                    id: closeBtn
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.rightMargin: innerPadding
                                    text: "\u00d7"
                                    color: Qt.rgba(appSettings.fontColor.r, appSettings.fontColor.g, appSettings.fontColor.b,
                                                   closeBtnArea.containsMouse ? 1.0 : (isCurrentTab ? 0.8 : 0.4))
                                    font.pixelSize: 13
                                    font.family: "monospace"

                                    MouseArea {
                                        id: closeBtnArea
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        onClicked: tabsRoot.closeTab(index)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.rightMargin: closeBtn.width + innerPadding * 2
                                    onClicked: tabsRoot.currentIndex = index
                                }

                                DragHandler {
                                    id: dragHandler
                                    yAxis.enabled: false
                                    target: null

                                    property real startX: 0

                                    onActiveChanged: {
                                        if (active) {
                                            startX = index * tabWidth
                                            tabsRoot.currentIndex = index
                                            tabsContainer.draggingIndex = index
                                            tabsContainer.draggingX = startX
                                        } else if (tabsContainer.draggingIndex === index) {
                                            var targetIdx = Math.max(0, Math.min(tabsModel.count - 1,
                                                                     Math.round(tabsContainer.draggingX / tabWidth)))
                                            if (targetIdx !== index) {
                                                tabsModel.move(index, targetIdx, 1)
                                                tabsRoot.currentIndex = targetIdx
                                            }
                                            tabsContainer.draggingIndex = -1
                                        }
                                    }

                                    onCentroidChanged: {
                                        if (active && tabsContainer.draggingIndex === index) {
                                            var delta = centroid.position.x - centroid.pressPosition.x
                                            tabsContainer.draggingX = Math.max(0,
                                                Math.min((tabsModel.count - 1) * tabWidth, startX + delta))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: addTabBtn
                    width: tabBarHeight - 4
                    height: tabBarHeight - 4
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 4
                    Layout.leftMargin: 4
                    color: "transparent"
                    border.color: Qt.rgba(appSettings.fontColor.r, appSettings.fontColor.g, appSettings.fontColor.b,
                                          addBtnArea.containsMouse ? 1.0 : 0.4)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Qt.rgba(appSettings.fontColor.r, appSettings.fontColor.g, appSettings.fontColor.b,
                                       addBtnArea.containsMouse ? 1.0 : 0.5)
                        font.pixelSize: 14
                        font.family: "monospace"
                    }

                    MouseArea {
                        id: addBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: tabsRoot.addTab()
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) {
                    var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                    var maxX = Math.max(0, tabsFlickable.contentWidth - tabsFlickable.width)
                    tabsRoot.scrollTargetX = Math.max(0, Math.min(maxX, tabsRoot.scrollTargetX - delta))
                    tabsFlickable.contentX = tabsRoot.scrollTargetX
                }
            }
        }

        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabsRoot.currentIndex

            Repeater {
                model: tabsModel
                PaneTreeNode {
                    treeData: tabsRoot.splitTrees[index] || { type: "terminal", paneId: 0 }
                    splitManager: tabsRoot
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
