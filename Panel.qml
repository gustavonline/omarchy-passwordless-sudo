import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.gustavonline.passwordless-sudo"
  ipcTarget: moduleName
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color muted: Qt.alpha(foreground, 0.58)
  readonly property color accent: Commons.Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string controlPath: decodeURIComponent(String(Qt.resolvedUrl("agent-access")).replace(/^file:\/\//, ""))
  readonly property bool animate: !settings || settings.animations !== false
  readonly property int defaultMinutes: settings && Number(settings.defaultMinutes) >= 1 && Number(settings.defaultMinutes) <= 15 ? Number(settings.defaultMinutes) : 5
  readonly property bool accessOpen: status.active === true && remaining > 0
  readonly property bool pending: status.pending === true
  readonly property bool configured: status.ready === true && status.enrolled === true
  property var status: ({ready: false, enrolled: false, active: false, pending: false, nativeActive: false})
  property int selectedMinutes: 5
  property int remaining: 0
  property double deadline: 0
  property bool busy: false
  property bool customDuration: false
  property bool shortening: false
  property string feedback: ""
  property bool feedbackError: false
  property string action: ""
  property real progress: accessOpen ? Math.min(1, remaining / Math.max(1, Number(status.totalSeconds || 300))) : 0
  Behavior on progress { NumberAnimation { duration: root.animate ? 350 : 0; easing.type: Easing.OutCubic } }

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight

  function clock(seconds) {
    return String(Math.floor(seconds / 60)).padStart(2, "0") + ":" + String(seconds % 60).padStart(2, "0")
  }
  function refresh() { if (!statusProcess.running) statusProcess.running = true }
  function run(actionName, value) {
    if (actionProcess.running) return
    action = actionName
    feedback = ""
    busy = true
    actionProcess.command = [controlPath, actionName]
    if (value !== undefined && String(value) !== "") actionProcess.command.push(String(value))
    actionProcess.running = true
  }
  function requestAccess() { run("request", selectedMinutes) }

  Component.onCompleted: {
    selectedMinutes = defaultMinutes
    skillProcess.running = true
    refresh()
  }
  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  Timer {
    interval: 1000
    running: root.status.active === true
    repeat: true
    onTriggered: {
      root.remaining = Math.max(0, Math.ceil((root.deadline - Date.now()) / 1000))
      if (root.remaining === 0) root.refresh()
    }
  }
  Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refresh() }
  Process {
    id: skillProcess
    command: [root.controlPath, "install-skill"]
    stderr: StdioCollector { id: skillError; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) { root.feedback = String(skillError.text).trim(); root.feedbackError = true }
    }
  }
  Process {
    id: statusProcess
    command: [root.controlPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          const value = JSON.parse(text)
          root.status = value
          root.deadline = Date.now() + Number(value.remainingSeconds || 0) * 1000
          root.remaining = Number(value.remainingSeconds || 0)
        } catch (e) { root.feedback = "Could not read access status"; root.feedbackError = true }
      }
    }
    stderr: StdioCollector { id: statusError; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) { root.feedback = String(statusError.text).trim(); root.feedbackError = true }
    }
  }
  Process {
    id: actionProcess
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    stderr: StdioCollector { id: actionError; waitForEnd: true }
    onExited: function(code) {
      root.busy = false
      root.feedbackError = code !== 0
      root.feedback = code !== 0 ? String(actionError.text || actionOutput.text).trim()
        : root.action === "approve" ? "Enter the phone code in the terminal."
        : root.action === "setup" ? "Continue setup in the terminal." : ""
      root.refresh()
    }
  }
  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function status(): string { return root.accessOpen ? "open" : root.pending ? "pending" : "locked" }
  }

  BarIconButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    text: root.accessOpen ? "󰌾 " + root.clock(root.remaining) : "󰌿"
    tooltipText: root.accessOpen ? "Agent access · " + root.clock(root.remaining) + " left" : root.pending ? "Agent access · awaiting approval" : "Omarchy Agent Access"
    active: root.accessOpen || root.pending
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || root.accessOpen) root.toggle()
      else if (!root.configured) root.run("setup", "")
      else root.run("quick", root.defaultMinutes)
    }
    Rectangle {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(2)
      width: Style.space(5); height: width; radius: width / 2
      color: root.foreground
      visible: root.pending
      SequentialAnimation on opacity {
        running: root.pending && root.animate
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 850 }
        NumberAnimation { to: 1; duration: 850 }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: durationInput.field.activeFocus
      onCloseRequested: root.close()
      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        Column {
          id: content
          width: parent.width
          spacing: Style.space(16)

          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroClock.implicitHeight)
            Text {
              id: heroIcon
              text: root.accessOpen ? "󰌿" : "󰌾"
              color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.display
              anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            }
            Column {
              id: heroLabels
              anchors.left: heroIcon.right; anchors.leftMargin: Style.space(14)
              anchors.right: heroClock.left; anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              Text {
                text: "Agent Access"; width: parent.width; elide: Text.ElideRight
                color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true
              }
              Text {
                text: root.accessOpen ? "ACCESS OPEN" : root.pending ? "AWAITING PHONE APPROVAL" : "ACCESS CLOSED"
                width: parent.width; elide: Text.ElideRight
                color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                font.bold: true; font.letterSpacing: 1.2
              }
            }
            Text {
              id: heroClock
              text: root.accessOpen ? root.clock(root.remaining) : root.pending ? root.status.requestedMinutes + "m" : ""
              color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.displayLarge; font.bold: true
              anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            }
          }

          Item {
            visible: root.accessOpen || root.pending
            width: parent.width; implicitHeight: Style.space(6)
            Rectangle { id: progressTrack; anchors.fill: parent; radius: height / 2; color: Qt.alpha(root.foreground, 0.12) }
            Rectangle {
              anchors.left: parent.left; height: parent.height; radius: height / 2
              width: parent.width * (root.pending ? 1 : root.progress)
              color: root.foreground
              Behavior on width { NumberAnimation { duration: root.animate ? 320 : 0; easing.type: Easing.OutCubic } }
              SequentialAnimation on opacity {
                running: root.pending && root.opened && root.animate
                loops: Animation.Infinite
                NumberAnimation { to: 0.45; duration: 950; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 950; easing.type: Easing.InOutSine }
              }
            }
          }

          Text {
            width: parent.width
            text: !root.configured ? "Scan a QR code once to approve access from your phone."
              : root.pending || root.accessOpen ? String(root.status.reason || "Maintenance")
              : "Choose a duration, then approve with your phone."
            color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap; textFormat: Text.PlainText
          }
          PanelSeparator { width: parent.width; foreground: root.foreground }
          PanelSectionHeader {
            visible: root.configured && !root.accessOpen && !root.pending
            width: parent.width; text: "DURATION"; foreground: root.foreground; fontFamily: root.fontFamily
          }

          Row {
            visible: root.configured && !root.accessOpen && !root.pending
            width: parent.width; spacing: Style.space(8)
            Repeater {
              model: [5, 10, 15]
              Button {
                required property int modelData
                width: (content.width - Style.space(16)) / 3
                text: modelData + " min"
                bordered: true
                foreground: root.selectedMinutes === modelData ? root.foreground : root.muted
                fontFamily: root.fontFamily
                onClicked: root.selectedMinutes = modelData
              }
            }
          }

          NumberField {
            id: durationInput
            visible: root.configured && !root.pending && ((!root.accessOpen && root.customDuration) || (root.accessOpen && root.shortening))
            width: parent.width; fieldWidth: width
            label: root.accessOpen ? "Minutes from now" : "Minutes"
            from: 1; to: root.accessOpen ? Math.max(1, Math.floor(root.remaining / 60)) : 15
            value: root.selectedMinutes; stepSize: 1
            foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
            onModified: function(value) { root.selectedMinutes = value }
          }

          Button {
            width: parent.width
            text: !root.configured ? "Set up phone" : root.accessOpen ? "Close access" : root.pending ? "Enter phone code" : "Request " + root.selectedMinutes + " minutes"
            enabled: !root.busy
            bordered: true; foreground: root.foreground; fontFamily: root.fontFamily
            verticalPadding: Style.spacing.controlPaddingY
            onClicked: {
              if (!root.configured) root.run("setup", "")
              else if (root.accessOpen) root.run("close", "")
              else if (root.pending) root.run("approve", "")
              else root.requestAccess()
            }
          }

          Button {
            visible: root.configured && (!root.accessOpen || root.remaining > 60)
            width: parent.width
            text: root.pending ? "Cancel request" : root.accessOpen ? (root.shortening ? "Apply shorter window" : "Shorten window") : (root.customDuration ? "Hide custom duration" : "Custom duration")
            enabled: !root.busy
            foreground: root.muted; fontFamily: root.fontFamily
            onClicked: {
              if (root.pending) root.run("close", "")
              else if (root.accessOpen && root.shortening) root.run("shorten", root.selectedMinutes)
              else if (root.accessOpen) { root.selectedMinutes = 1; root.shortening = true }
              else root.customDuration = !root.customDuration
            }
          }

          Text {
            width: parent.width
            text: root.pending ? "Remote? Send a fresh phone code to your agent." : root.configured ? "Phone connected · Up to 15 minutes" : "Setup needs your normal administrator password once."
            color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
          Button {
            visible: root.status.rootUpgradeNeeded === true && root.status.ready === true
            width: parent.width; text: "Update access service"; foreground: root.muted; fontFamily: root.fontFamily
            onClicked: root.run("setup", "")
          }
          Button {
            visible: root.status.nativeActive === true
            width: parent.width; text: "Close separate legacy sudo access"; foreground: Commons.Color.urgent; fontFamily: root.fontFamily
            onClicked: root.run("native-disable", "")
          }
          Button {
            visible: settings && settings.showNativeFlow === true
            width: parent.width; text: "Legacy Omarchy sudo"; foreground: root.muted; fontFamily: root.fontFamily
            onClicked: root.run("native-launch", root.selectedMinutes)
          }
          Text {
            visible: root.feedback !== ""
            width: parent.width; text: root.feedback; textFormat: Text.PlainText
            color: root.feedbackError ? Commons.Color.urgent : root.muted
            font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
