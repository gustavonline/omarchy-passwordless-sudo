import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.gustavonline.passwordless-sudo"
  ipcTarget: "io.github.gustavonline.passwordless-sudo"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string controlPath: decodeURIComponent(
    String(Qt.resolvedUrl("passwordless-sudo-control")).replace(/^file:\/\//, "")
  )
  readonly property int refreshInterval: Math.max(2, Number(
    settings && settings.refreshIntervalSec ? settings.refreshIntervalSec : 5
  )) * 1000
  readonly property var intervals: [
    Number(settings && settings.shortMinutes ? settings.shortMinutes : 15),
    Number(settings && settings.mediumMinutes ? settings.mediumMinutes : 30),
    Number(settings && settings.longMinutes ? settings.longMinutes : 60),
    Number(settings && settings.extendedMinutes ? settings.extendedMinutes : 120)
  ]

  property var status: ({ active: false, timerActive: false, remainingSeconds: 0, expires: "", label: "Password required" })
  property bool busy: false
  property string feedback: ""

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function remainingLabel() {
    var seconds = Math.max(0, Number(status.remainingSeconds || 0))
    if (!status.active) return "Sudo requires your password"
    if (!status.timerActive) return "Active · expiration timer unavailable"
    var minutes = Math.max(1, Math.ceil(seconds / 60))
    return "Active · about " + minutes + " min remaining"
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function runAction(action, value) {
    if (actionProcess.running) return
    busy = true
    feedback = "Opening Omarchy terminal…"
    actionProcess.command = [controlPath, action]
    if (value !== undefined && value !== null && String(value) !== "") actionProcess.command.push(String(value))
    actionProcess.running = true
  }

  onOpenedChanged: if (opened) {
    feedback = ""
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Component.onCompleted: refresh()

  Timer {
    interval: root.refreshInterval
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    running: false
    command: [root.controlPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || ""))
          if (parsed && typeof parsed === "object") root.status = parsed
        } catch (e) {
          root.feedback = "Could not read sudo status"
        }
      }
    }
  }

  Process {
    id: actionProcess
    running: false
    onExited: function(exitCode) {
      root.busy = false
      root.feedback = exitCode === 0 ? "" : "Could not open Omarchy terminal"
      root.refresh()
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function status(): string { return root.status.active ? "active" : "inactive" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.status.active ? root.remainingLabel() : "Passwordless sudo"
    iconComponent: Component {
      Item {
        Text {
          anchors.centerIn: parent
          text: root.status.active ? "󰌾" : "󰌿"
          color: root.foreground
          opacity: 1.0
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        Rectangle {
          visible: root.status.active
          width: root.status.active ? Style.space(5) : Style.space(4)
          height: width
          radius: width / 2
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.rightMargin: Style.space(2)
          anchors.bottomMargin: Style.space(2)
          color: Color.urgent
        }
      }
    }
    onPressed: function(buttonCode) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(500))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.refresh()
      onCloseRequested: root.close()

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Passwordless Sudo"
          meta: root.status.active ? "TEMPORARY ROOT ACCESS" : "OMARCHY SECURITY"
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: root.status.active ? "󰌾" : "󰌿"
              color: root.status.active ? Color.urgent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        Text {
          width: parent.width
          text: root.remainingLabel()
          color: root.status.active ? Color.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          text: "Choose a duration. Omarchy will open its normal terminal, show the security warning, and request confirmation before making any change."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        PanelSectionHeader {
          width: parent.width
          text: "DURATION"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Grid {
          id: durationGrid
          width: parent.width
          columns: 2
          spacing: Style.spacing.md
          readonly property real cellWidth: (width - spacing) / 2

          Repeater {
            model: root.intervals

            Button {
              required property var modelData
              width: durationGrid.cellWidth
              text: String(modelData) + " min"
              enabled: !root.busy
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: root.runAction("launch", modelData)
            }
          }
        }

        Button {
          visible: root.status.active
          width: parent.width
          text: "Disable now"
          enabled: !root.busy
          bordered: true
          foreground: Color.urgent
          fontFamily: root.fontFamily
          fontSize: Style.font.bodySmall
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: root.runAction("disable", "")
        }

        Text {
          visible: root.feedback !== ""
          width: parent.width
          text: root.feedback
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }
}
