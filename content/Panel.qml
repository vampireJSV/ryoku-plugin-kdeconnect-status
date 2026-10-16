import QtQuick
import Ryoku.PluginKit.Singletons

// content/Panel.qml: device detail card plus quick-action buttons (messages,
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
    readonly property bool lastPollFailed: service ? service.lastPollFailed : false

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    Column {
        id: col
        x: 14 * root.s
        y: 12 * root.s
        width: root.width - 28 * root.s
        spacing: 8 * root.s

        Text {
            text: "KDE Connect"
            color: Theme.bright
            font.family: Theme.display
            font.pixelSize: 16 * root.s
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
