import QtQuick
import Ryoku.PluginKit.Singletons

// content/Panel.qml: device select (2+ devices) and detail card plus quick-action buttons (messages,
// send file, clipboard, ping, find phone, open app). Opens under the glyph.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 280
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool found: service ? service.found : false
    readonly property string deviceName: service ? service.deviceName : ""
    readonly property bool reachable: service ? service.reachable : false
    readonly property int charge: service ? service.charge : -1
    readonly property bool charging: service ? service.charging : false
    readonly property int notifCount: service ? service.notifCount : 0
    readonly property var devices: service ? service.devices : []
    readonly property string deviceId: service ? service.deviceId : ""
    readonly property bool lastPollFailed: service ? service.lastPollFailed : false

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    Column {
        id: col
        x: 14 * root.s
        y: 12 * root.s
        width: root.width - 28 * root.s
        spacing: 8 * root.s

        // Device select: collapsed row shows the current device; clicking it
        // expands the list inline (no floating popup, so it never clips at the
        // panel edge). Only shown when 2+ devices are paired.
        Column {
            id: picker
            visible: root.devices.length > 1
            width: parent.width
            spacing: 4 * root.s
            property bool open: false

            Rectangle {
                width: parent.width
                height: 30 * root.s
                radius: 6 * root.s
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, headHit.containsMouse ? 0.22 : 0.10)
                border.width: 1
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

                Rectangle {
                    id: headDot
                    x: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8 * root.s
                    height: width
                    radius: width / 2
                    color: root.reachable ? Theme.accent : Theme.dim
                }

                Text {
                    anchors.left: headDot.right
                    anchors.leftMargin: 8 * root.s
                    anchors.right: arrow.left
                    anchors.rightMargin: 6 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: root.deviceName || "Select device"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                }

                Text {
                    id: arrow
                    anchors.right: parent.right
                    anchors.rightMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: picker.open ? "\u25B4" : "\u25BE"
                    color: Theme.dim
                    font.pixelSize: 12 * root.s
                }

                MouseArea {
                    id: headHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.open = !picker.open
                }
            }

            Repeater {
                model: picker.open ? root.devices : []

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool picked: modelData.id === root.deviceId
                    width: picker.width
                    height: 28 * root.s
                    radius: 6 * root.s
                    color: picked ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                  : (rowHit.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                                                          : "transparent")

                    Rectangle {
                        id: dot
                        x: 10 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8 * root.s
                        height: width
                        radius: width / 2
                        color: parent.modelData.reachable ? Theme.accent : Theme.dim
                    }

                    Text {
                        anchors.left: dot.right
                        anchors.leftMargin: 8 * root.s
                        anchors.right: batt.left
                        anchors.rightMargin: 6 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: parent.modelData.name || parent.modelData.id
                        opacity: parent.modelData.reachable ? 1 : 0.55
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: 12 * root.s
                    }

                    Text {
                        id: batt
                        anchors.right: parent.right
                        anchors.rightMargin: 10 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.modelData.charge >= 0
                        text: parent.modelData.charge + "%"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                    }

                    MouseArea {
                        id: rowHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.service) root.service.selectDevice(parent.modelData.id);
                            picker.open = false;
                        }
                    }
                }
            }
        }

        Text {
            visible: !root.found
            text: root.lastPollFailed ? "Could not reach kdeconnectd." : "No paired device found."
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13 * root.s
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Column {
            visible: root.found
            width: parent.width
            spacing: 6 * root.s

            Text {
                visible: !picker.visible
                text: root.deviceName || "Unknown device"
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 14 * root.s
            }

            Text {
                text: root.reachable ? "Connected" : "Not reachable"
                color: root.reachable ? Theme.accent : Theme.dim
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }

            Text {
                visible: root.charge >= 0
                text: "Battery: " + root.charge + "%" + (root.charging ? " (charging)" : "")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }

            Text {
                text: "Notifications: " + root.notifCount
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }
        }

        Grid {
            visible: root.found && root.reachable
            width: parent.width
            columns: 3
            spacing: 6 * root.s
            readonly property real cell: (width - 2 * spacing) / 3

            Repeater {
                model: [
                    { label: "Messages", act: "openMessages" },
                    { label: "Send file", act: "sendFile" },
                    { label: "Clipboard", act: "sendClipboard" },
                    { label: "Ping", act: "ping" },
                    { label: "Find phone", act: "ring" },
                    { label: "Open app", act: "openApp" }
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: parent.cell
                    height: 30 * root.s
                    radius: 6 * root.s
                    color: hit.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                             : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 6 * root.s
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: parent.modelData.label
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                    }

                    MouseArea {
                        id: hit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.service) root.service[parent.modelData.act]()
                    }
                }
            }
        }
    }
}
