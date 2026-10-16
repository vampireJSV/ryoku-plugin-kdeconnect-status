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

    // Live device state, defaults until the first poll lands.
    property bool found: false
    property string deviceId: ""
    property string deviceName: ""
    property bool reachable: false
    property int charge: -1
    property bool charging: false
    property int notifCount: 0
    property bool lastPollFailed: false

    Process {
        id: pollProc
        command: [(svc.pluginApi ? svc.pluginApi.pluginDir : "") + "/bin/poll.sh"]
        stdout: StdioCollector {
            id: pollOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(pollOut.text);
                    svc.lastPollFailed = false;
                    svc.found = !!data.found;
                    svc.deviceId = data.id || "";
                    svc.deviceName = data.name || "";
                    svc.reachable = !!data.reachable;
                    svc.charge = (typeof data.charge === "number") ? data.charge : -1;
                    svc.charging = !!data.charging;
                    svc.notifCount = (typeof data.notifCount === "number") ? data.notifCount : 0;
                } catch (e) {
                    svc.lastPollFailed = true;
                    svc.found = false;
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
