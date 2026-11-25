pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// service/Main.qml is the plugin's logic: no UI. The host loads one instance
// and hands it to every view as pluginApi.mainInstance, so the widget and the
// panel read the same live state.
//
// Polls kdeconnectd over the session D-Bus (via bin/poll.sh, R6/R9-clean: no
// shell string built from input, a fixed argv only) on a timer. The poll is
// read-only. Actions run only on an explicit panel click, each a fixed argv
// (kdeconnect-cli / kdeconnect-sms / kdeconnect-app / zenity), never a shell.
Item {
    id: svc

    // Set by the host after this loads; the plugin's settings live behind it.
    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property int pollSeconds: settings && settings.pollSeconds ? settings.pollSeconds : 10

    // All paired devices from the last poll, plus the user's pick. Saving a
    // plugin setting rewrites plugins.json, which reloads the plugin and closes
    // the panel, so the pick lives in a file under stateDir instead (R8).
    property var devices: []
    property string pickedId: ""
    property bool lastPollFailed: false

    FileView {
        id: pickFile
        path: svc.pluginApi ? svc.pluginApi.stateDir + "/selected-device" : ""
        blockLoading: true
        onLoaded: if (!svc.pickedId) svc.pickedId = pickFile.text().trim()
    }

    // Selected device: the pick if still paired, else first reachable, else first.
    readonly property var current: {
        const want = svc.pickedId;
        const list = svc.devices;
        for (const d of list) if (d.id === want) return d;
        for (const d of list) if (d.reachable) return d;
        return list.length > 0 ? list[0] : null;
    }

    readonly property bool found: current !== null
    readonly property string deviceId: current ? current.id : ""
    readonly property string deviceName: current ? current.name : ""
    readonly property bool reachable: current ? current.reachable : false
    readonly property int charge: current ? current.charge : -1
    readonly property bool charging: current ? current.charging : false
    readonly property int notifCount: current ? current.notifCount : 0

    function selectDevice(id) {
        svc.pickedId = id;
        pickFile.setText(id);
    }

    Process {
        id: pollProc
        command: [(svc.pluginApi ? svc.pluginApi.pluginDir : "") + "/bin/poll.sh"]
        stdout: StdioCollector {
            id: pollOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(pollOut.text);
                    svc.lastPollFailed = false;
                    svc.devices = Array.isArray(data.devices) ? data.devices : [];
                } catch (e) {
                    svc.lastPollFailed = true;
                    svc.devices = [];
                }
            }
        }
    }

    // --- Actions (explicit panel clicks only) -------------------------------

    Process { id: appProc }
    Process { id: smsProc }
    Process { id: cliProc }

    // Pick a file with zenity, then hand the chosen path to kdeconnect-cli as
    // its own argv element (no shell, so odd filenames are safe).
    Process {
        id: pickProc
        command: ["zenity", "--file-selection", "--multiple", "--separator=\n",
                  "--title=Send file to " + svc.deviceName]
        stdout: StdioCollector {
            id: pickOut
            onStreamFinished: {
                const files = pickOut.text.split("\n").filter(f => f.length > 0);
                for (const f of files)
                    svc.runCli(["--share", f]);
            }
        }
    }

    function runCli(extra) {
        if (!svc.deviceId) return;
        // One short-lived Process per call so several shares can run at once.
        const p = cliComp.createObject(svc, {
            command: ["kdeconnect-cli", "--device", svc.deviceId].concat(extra)
        });
        p.running = true;
    }

    Component {
        id: cliComp
        Process {
            onRunningChanged: if (!running) destroy()
        }
    }

    function openApp() {
        appProc.command = ["kdeconnect-app"];
        appProc.running = true;
    }

    function openMessages() {
        if (!svc.deviceId) return;
        smsProc.command = ["kdeconnect-sms", "--device", svc.deviceId];
        smsProc.running = true;
    }

    function sendFile() {
        if (!svc.deviceId) return;
        pickProc.running = false;
        pickProc.running = true;
    }

    function sendClipboard() { svc.runCli(["--send-clipboard"]); }
    function ping() { svc.runCli(["--ping"]); }
    function ring() { svc.runCli(["--ring"]); }

    function poll() {
        pollProc.running = false;
        pollProc.running = true;
    }

    Timer {
        interval: svc.pollSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: svc.poll()
    }
}
