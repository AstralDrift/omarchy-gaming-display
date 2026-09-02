pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "astraldrift.gaming-display"
  ipcTarget: "astraldrift.gaming-display"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string cliPath: String(Qt.resolvedUrl("bin/omarchy-gaming-display")).replace("file://", "")

  property var displayState: ({})
  property string activeProfile: "native"
  property string targetName: "Detecting display…"
  property string targetMode: ""
  property string message: ""
  property bool busy: false
  property string pendingToken: ""
  property int pendingRemaining: 0

  function open() {
    refresh()
    controller.show()
  }

  function close() {
    controller.hide()
  }

  function refresh() {
    if (statusProc.running) return
    statusProc.command = [root.cliPath, "status", "--json"]
    statusProc.running = true
  }

  function parseStatus(raw) {
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      if (!parsed.ok) {
        root.message = parsed.error || "Unable to read display state"
        return
      }
      root.displayState = parsed
      root.activeProfile = String(parsed.activeProfile || "custom")
      root.targetName = parsed.target ? String(parsed.target.description || parsed.target.connector || "Display") : "Display"
      root.targetMode = parsed.target
        ? String(parsed.target.width) + "×" + String(parsed.target.height) + " @ " + Number(parsed.target.refreshHz || 0).toFixed(0) + " Hz"
        : ""
      root.pendingToken = parsed.pending ? String(parsed.pending.token || "") : ""
      root.pendingRemaining = parsed.pending ? Number(parsed.pending.remainingSeconds || 0) : 0
      if (root.hostWidget && root.hostWidget.updateFromPanel)
        root.hostWidget.updateFromPanel(root.activeProfile)
    } catch (error) {
      root.message = "Invalid response from display helper"
    }
  }

  function profileData(profile) {
    var rows = displayState && displayState.profiles ? displayState.profiles : []
    for (var i = 0; i < rows.length; i++) if (rows[i].id === profile) return rows[i]
    return null
  }

  function selectDesktop(profile) {
    if (busy || pendingToken !== "") return
    var data = profileData(profile)
    root.message = ""
    if (profile !== "native" && (!data || !data.available)) {
      root.message = profile + " is not advertised by this monitor. Use the Steam / Gamescope option below."
      return
    }
    root.busy = true
    if (profile === "native" || (data && data.verified))
      actionProc.command = [root.cliPath, "desktop", "set", profile, "--json"]
    else
      actionProc.command = [root.cliPath, "desktop", "test", profile, "--json"]
    actionProc.running = true
  }

  function confirmTest() {
    if (busy || pendingToken === "") return
    root.busy = true
    actionProc.command = [root.cliPath, "desktop", "confirm", pendingToken, "--json"]
    actionProc.running = true
  }

  function revertTest() {
    if (busy || pendingToken === "") return
    root.busy = true
    actionProc.command = [root.cliPath, "desktop", "revert", pendingToken, "--json"]
    actionProc.running = true
  }

  function copySteam(profile) {
    if (busy) return
    root.busy = true
    copyProc.command = [root.cliPath, "steam-option", profile, "--copy"]
    copyProc.running = true
  }

  onOpenedChanged: if (opened) refresh()

  Timer {
    interval: 1000
    running: root.opened && root.pendingToken !== ""
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 5000
    running: root.opened && root.pendingToken === ""
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      id: actionOutput
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.busy = false
      var raw = String(actionOutput.text || "").trim()
      try {
        var result = JSON.parse(raw || "{}")
        if (exitCode !== 0 || !result.ok) root.message = result.error || "Display operation failed"
        else if (result.testing) root.message = "Mode applied. Keep it before the countdown expires."
        else if (result.confirmed) root.message = "Profile verified and kept."
        else if (result.reverted) root.message = "Previous display mode restored."
        else root.message = "Display profile applied."
      } catch (error) {
        root.message = exitCode === 0 ? "Display operation finished." : "Display operation failed."
      }
      root.refresh()
    }
  }

  Process {
    id: copyProc
    stdout: StdioCollector {
      id: copyOutput
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.busy = false
      root.message = exitCode === 0
        ? "Steam launch option copied to the clipboard."
        : "Could not copy the Steam launch option."
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "1") root.selectDesktop("native")
        else if (text === "2") root.selectDesktop("21:9")
        else if (text === "3") root.selectDesktop("16:9")
        else if (text === "k" || text === "K") root.confirmTest()
        else if (text === "r" || text === "R") root.revertTest()
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: contentColumn
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            foreground: root.foreground
            fontFamily: root.fontFamily
            title: "Gaming Display"
            meta: root.targetName
            detail: root.targetMode
            iconComponent: Component {
              Text {
                text: "󰍹"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          PanelSeparator { foreground: root.foreground }
          PanelSectionHeader { text: "DESKTOP OUTPUT"; foreground: root.foreground; fontFamily: root.fontFamily }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: [
                { id: "native", title: "32:9", hint: "Native" },
                { id: "21:9", title: "21:9", hint: "3440" },
                { id: "16:9", title: "16:9", hint: "2560" }
              ]

              Button {
                required property var modelData
                readonly property var profileInfo: root.profileData(modelData.id)
                width: (contentColumn.width - Style.space(12)) / 3
                text: modelData.title
                tooltipText: modelData.id !== "native" && (!profileInfo || !profileInfo.available)
                  ? modelData.hint + " · Gamescope only"
                  : modelData.hint
                selected: root.activeProfile === modelData.id
                enabled: !root.busy && root.pendingToken === ""
                  && (modelData.id === "native" || (profileInfo && profileInfo.available))
                foreground: root.foreground
                bordered: true
                onClicked: root.selectDesktop(modelData.id)
              }
            }
          }

          Text {
            width: parent.width
            text: "Desktop switching only uses modes advertised by the monitor. Unavailable profiles remain usable through Gamescope."
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            visible: root.pendingToken !== ""
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              text: "Keep this mode? Reverting in " + root.pendingRemaining + " seconds."
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              wrapMode: Text.WordWrap
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Keep"
                iconText: "󰄬"
                foreground: root.foreground
                bordered: true
                enabled: !root.busy
                onClicked: root.confirmTest()
              }

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Revert"
                iconText: "󰑓"
                foreground: root.foreground
                bordered: true
                enabled: !root.busy
                onClicked: root.revertTest()
              }
            }
          }

          PanelSeparator { foreground: root.foreground }
          PanelSectionHeader { text: "STEAM / GAMESCOPE"; foreground: root.foreground; fontFamily: root.fontFamily }

          Text {
            width: parent.width
            text: "Copy a launch option that keeps the desktop native while the game sees a centered virtual display."
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Copy 21:9"
              iconText: "󰆏"
              foreground: root.foreground
              bordered: true
              enabled: !root.busy
              onClicked: root.copySteam("21:9")
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Copy 16:9"
              iconText: "󰆏"
              foreground: root.foreground
              bordered: true
              enabled: !root.busy
              onClicked: root.copySteam("16:9")
            }
          }

          Text {
            visible: root.message !== ""
            width: parent.width
            text: root.message
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: "Keys: 1 native · 2 21:9 · 3 16:9 · K keep · R revert"
            color: Qt.darker(root.foreground, 1.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
