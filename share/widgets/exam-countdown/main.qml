// An example desktop widget: the days to your next exam (from AmazeCC), big
// and quiet on the wallpaper. Click: Halo makes a revision plan.
import QtQuick

Item {
    id: root
    property var lumen: null
    readonly property var t: lumen ? lumen.theme : null
    readonly property var exam: lumen ? lumen.college.nextExam : null
    readonly property int days: exam && lumen ? lumen.college.daysTo(exam.when) : -1
    visible: !!exam
    implicitHeight: exam ? col.implicitHeight : 0

    Column {
        id: col
        anchors.right: parent.right
        spacing: 2
        Text { anchors.right: parent.right; text: root.days === 0 ? "today" : root.days === 1 ? "tomorrow" : root.days + " days"
               color: root.t ? root.t.onMedia : "white"; font.pixelSize: 54; font.weight: Font.Light }
        Text { anchors.right: parent.right; text: root.exam ? root.exam.kind + " · " + root.exam.title : ""
               color: root.t ? root.t.withAlpha(root.t.onMedia, 0.8) : "white"; font.pixelSize: 16; width: Math.min(implicitWidth, 320); elide: Text.ElideRight; horizontalAlignment: Text.AlignRight }
    }
    MouseArea {
        anchors.fill: col
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.lumen && root.exam) root.lumen.askHalo("Make me a revision plan for " + root.exam.title + " (" + root.exam.kind + ") in " + root.days + " days.")
    }
}
