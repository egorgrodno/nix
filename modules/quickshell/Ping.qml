import QtQuick
import Quickshell.Io

// One ping to `host` per `send`: the round trip in milliseconds, NaN until the
// first reply, and `replied` false while the last went a second unanswered.
Process {
    id: ping

    property string host
    property real rtt: NaN
    property bool replied: true

    function send() {
        if (host !== "")
            running = true;
    }

    command: [Programs.ping, "-n", "-c", "1", "-W", "1", host]
    onHostChanged: {
        rtt = NaN;
        replied = true;
    }

    stdout: StdioCollector {
        onStreamFinished: {
            const time = text.match(/time=([\d.]+) ms/);
            ping.replied = time !== null;
            if (time)
                ping.rtt = Number(time[1]);
        }
    }
}
