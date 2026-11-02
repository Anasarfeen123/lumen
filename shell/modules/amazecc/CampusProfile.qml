import QtQuick
import qs.theme
import qs.components
import qs.services

Card {
    id: root
    title: "Your hostel"
    icon: "apartment"
    property string group: Amazecc.cfg.campusGender || Amazecc.campusProfile.gender || ""
    property string block: Amazecc.cfg.campusBlock || Amazecc.campusProfile.block || ""
    property string room: Amazecc.cfg.campusRoom || Amazecc.campusProfile.room || ""
    property string mess: Amazecc.cfg.campusMess || Amazecc.campusProfile.mess || ""
    readonly property var blocks: group === "Female" ? ["B", "C"] : group === "Male" ? ["A", "C", "D1", "D2", "E"] : []
    Column {
        width: parent.width; spacing: Theme.space.s3
        LText { width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textSecondary; text: "Use your VTOP hostel details, or choose them here. Schedules are for VIT Chennai." }
        Flow {
            width: parent.width; spacing: Theme.space.s2
            Repeater { model: ["Male", "Female"]; CollegeButton { required property string modelData; text: modelData + " hostel"; selected: root.group === modelData; onActivated: { root.group = modelData; if (!root.blocks.includes(root.block)) root.block = ""; } } }
        }
        Flow {
            width: parent.width; spacing: Theme.space.s2
            Repeater { model: root.blocks; CollegeButton { required property string modelData; text: "Block " + modelData; selected: root.block === modelData; onActivated: root.block = modelData } }
        }
        LField { width: Math.min(220, parent.width); icon: "meeting_room"; placeholder: "Room number"; text: root.room; clearOnAccept: false; input.onTextEdited: root.room = text; onAccepted: root.room = text }
        Flow {
            width: parent.width; spacing: Theme.space.s2
            Repeater { model: ["Veg", "Non Veg", "Special"]; CollegeButton { required property string modelData; text: modelData; selected: root.mess === modelData; onActivated: root.mess = modelData } }
        }
        Flow {
            width: parent.width; spacing: Theme.space.s2
            CollegeButton {
                text: "Save & refresh"; icon: "check"; selected: true; enabled: root.group !== "" && !Amazecc.campusSyncing
                onActivated: { Amazecc.cfg.campusGender = root.group; Amazecc.cfg.campusBlock = root.block; Amazecc.cfg.campusRoom = root.room.trim(); Amazecc.cfg.campusMess = root.mess; Amazecc.refreshCampus(); }
            }
            CollegeButton {
                text: "Use VTOP details"; icon: "sync"; enabled: !!Amazecc.extra.hostel && !Amazecc.campusSyncing
                onActivated: { Amazecc.cfg.campusGender = ""; Amazecc.cfg.campusBlock = ""; Amazecc.cfg.campusRoom = ""; Amazecc.cfg.campusMess = ""; root.group = Qt.binding(()=>Amazecc.campusProfile.gender || ""); root.block = Qt.binding(()=>Amazecc.campusProfile.block || ""); root.room = Qt.binding(()=>Amazecc.campusProfile.room || ""); root.mess = Qt.binding(()=>Amazecc.campusProfile.mess || ""); Amazecc.refreshCampus(); }
            }
        }
        CollegeButton {
            text: Amazecc.cfg.campusOnlineSchedules ? "Live schedules on" : "Enable live schedules"
            icon: "cloud_sync"; selected: Amazecc.cfg.campusOnlineSchedules; enabled: !Amazecc.campusSyncing
            onActivated: { Amazecc.cfg.campusOnlineSchedules = !Amazecc.cfg.campusOnlineSchedules; Amazecc.refreshCampus(); }
        }
        LText { width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textMuted; text: "Live refresh requests a file for your hostel group/block and mess type from unmessify. Your room and VTOP login stay local. Offline schedules are available without enabling this." }
        LText { visible: Amazecc.campusError !== ""; width: parent.width; wrapMode: Text.Wrap; text: Amazecc.campusError; color: Theme.warning; role: "caption" }
    }
}
