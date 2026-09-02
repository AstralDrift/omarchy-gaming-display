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
  property string copiedProfile: ""

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

  function profileResolution(profile) {
    var data = profileData(profile)
    if (!data) return ""
    return String(data.width) + "×" + String(data.height)
  }

  function desktopAction(profile) {
    if (profile === "native") return "Use full monitor · 32:9"
    return "Center desktop · " + profile
  }

  function desktopSummary(profile) {
    var resolution = profileResolution(profile)
    var data = profileData(profile)
    if (profile === "native") return resolution + " · Native output · restores the full-width desktop"
    if (!data || !data.available)
      return resolution + " · Gamescope only · not advertised by this monitor; use Steam below"
    if (data.verified) return resolution + " · Ready · verified for this monitor"
    return resolution + " · Test once · starts a timed safety test"
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
    root.copiedProfile = profile
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
        ? root.copiedProfile + " Steam option copied. Paste it into the game's Steam Launch Options."
        : "Could not copy the Steam launch option."
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
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

          Text {
            width: parent.width
            text: "Choose whether to change the entire desktop or copy a setting for one Steam game."
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator { foreground: root.foreground }
          PanelSectionHeader { text: "1 · DESKTOP MODE · AFFECTS EVERYTHING"; foreground: root.foreground; fontFamily: root.fontFamily }

          Text {
            width: parent.width
            text: "These buttons immediately change the target display. The selected mode stays active until you choose another or log out."
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Repeater {
              model: [
                { id: "native" },
                { id: "21:9" },
                { id: "16:9" }
              ]

              Column {
                required property var modelData
                readonly property var profileInfo: root.profileData(modelData.id)
                width: contentColumn.width
                spacing: Style.space(3)

                Button {
                  width: parent.width
                  text: root.desktopAction(modelData.id)
                  tooltipText: root.desktopSummary(modelData.id)
                  selected: root.activeProfile === modelData.id
                  enabled: !root.busy && root.pendingToken === ""
                    && (modelData.id === "native" || (profileInfo && profileInfo.available))
                  foreground: root.foreground
                  bordered: true
                  onClicked: root.selectDesktop(modelData.id)
                }

                Text {
                  width: parent.width
                  text: root.desktopSummary(modelData.id)
                  color: modelData.id !== "native" && (!profileInfo || !profileInfo.available)
                    ? Qt.darker(root.foreground, 1.5)
                    : Qt.darker(root.foreground, 1.25)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }
            }
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
          PanelSectionHeader { text: "2 · STEAM OPTION · ONE GAME ONLY"; foreground: root.foreground; fontFamily: root.fontFamily }

          Text {
            width: parent.width
            text: "These buttons do not change the display. They copy a Gamescope command; paste it into Steam → game Properties → Launch Options."
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
              text: "Copy Steam 21:9"
              iconText: "󰆏"
              foreground: root.foreground
              bordered: true
              enabled: !root.busy
              onClicked: root.copySteam("21:9")
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Copy Steam 16:9"
              iconText: "󰆏"
              foreground: root.foreground
              bordered: true
              enabled: !root.busy
              onClicked: root.copySteam("16:9")
            }
          }

          Text {
            width: parent.width
            text: "21:9 = " + root.profileResolution("21:9") + " · 16:9 = " + root.profileResolution("16:9")
            color: Qt.darker(root.foreground, 1.35)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
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
