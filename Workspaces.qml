pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui as Ui
import "../hancore.shibumi.state/lib/presentation" as Presentation

// Per-monitor workspace indicator for the Shibumi bar.
//
// The workspace model remains upstream-compatible: every monitor owns named
// workspaces (<display identity>:<slot>). This presentation deliberately uses
// the same pill, marker geometry, color tokens, hover, and tooltip behavior as
// hancore.shibumi.workspaces.
Ui.BarWidget {
  id: root

  moduleName: "mmsbrggr.per-monitor-workspaces"

  // ---------------------------------------------------------------- settings

  readonly property int slotCount: {
    const value = Number(root.setting("count", 5))
    return value > 0 ? Math.max(1, Math.floor(value)) : 5
  }
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateDir: home ? home + "/.local/state/omarchy" : ""
  readonly property string configPath: stateDir
    ? stateDir + "/" + root.moduleName + ".lua" : ""

  FileView {
    id: configFile
    path: root.configPath
    atomicWrites: true
    printErrors: false
    onSaved: {
      root.publishedCount = root.slotCount
      root.pushCount()
    }
    onSaveFailed: publishDefer.restart()
  }

  property int publishedCount: 0

  function publishCount() {
    if (root.configPath === "" || root.slotCount === root.publishedCount) return
    configFile.setText("-- Written by Per-monitor Workspaces for Shibumi.\n"
      + "-- Derived from the count setting in shell.json; do not edit here.\n"
      + "return { count = " + root.slotCount + " }\n")
  }

  function pushCount() {
    root.runLua("local pmw = _G.per_monitor_workspaces; "
      + "if pmw and pmw.set_count then pmw.set_count(" + root.slotCount + ") end")
  }

  onSlotCountChanged: publishDefer.restart()
  Component.onCompleted: publishDefer.restart()

  Timer {
    id: publishDefer
    interval: 800
    onTriggered: root.publishCount()
  }

  // --------------------------------------------------------------- monitor

  readonly property var barWindow: root.QsWindow ? root.QsWindow.window : null
  readonly property var monitor: barWindow && barWindow.screen
    ? Hyprland.monitorFor(barWindow.screen) : null

  // Match the Lua binding module: use display description to survive connector
  // swaps, and append a connector only when two displays are indistinguishable.
  readonly property string prefix: {
    if (!root.monitor) return ""
    const description = String(root.monitor.description || "")
    if (description === "") return String(root.monitor.name || "")

    const monitors = Hyprland.monitors.values || []
    for (let index = 0; index < monitors.length; index++) {
      if (monitors[index] !== root.monitor
          && String(monitors[index].description || "") === description)
        return description + "@" + String(root.monitor.name || "")
    }
    return description
  }

  function slotName(slot) {
    return root.prefix === "" ? "" : root.prefix + ":" + slot
  }

  function workspaceByName(name) {
    const values = Hyprland.workspaces.values || []
    for (let index = 0; index < values.length; index++) {
      if (String(values[index].name || "") === name) return values[index]
    }
    return null
  }

  // --------------------------------------------------------------- workspace

  function parkedTooltip(name) {
    const separator = name.lastIndexOf(":")
    if (separator <= 0) return name
    return name.substring(0, separator) + " · slot "
      + name.substring(separator + 1)
  }

  function buildEntries() {
    const items = []
    if (root.prefix === "") return items

    const own = ({})
    for (let slot = 1; slot <= root.slotCount; slot++) {
      const name = root.slotName(slot)
      own[name] = true
      items.push({ name: name, label: String(slot), tooltip: "", parked: false })
    }

    const parked = []
    const values = Hyprland.workspaces.values || []
    for (let index = 0; index < values.length; index++) {
      const workspace = values[index]
      const name = String(workspace.name || "")
      if (workspace.monitor !== root.monitor || own[name]
          || name.indexOf("special:") === 0) continue
      parked.push(workspace)
    }
    parked.sort(function(left, right) { return Number(left.id) - Number(right.id) })

    for (let index = 0; index < parked.length; index++) {
      const name = String(parked[index].name || "")
      items.push({
        name: name,
        label: "󰍺",
        tooltip: root.parkedTooltip(name),
        parked: true
      })
    }
    return items
  }

  readonly property var entries: root.buildEntries()

  // --------------------------------------------------------------- actions

  function quoteLua(value) {
    return "\"" + String(value)
      .replace(/\\/g, "\\\\")
      .replace(/\"/g, "\\\"")
      .replace(/\n/g, "\\n")
      .replace(/\r/g, "\\r") + "\""
  }

  function runLua(body) {
    Hyprland.dispatch("function() " + body + " end")
  }

  function focusMonitorLua() {
    return "hl.dispatch(hl.dsp.focus({ monitor = "
      + root.quoteLua(root.monitor.name) + " }));"
  }

  function focusHereLua(name) {
    return root.focusMonitorLua()
      + " hl.dispatch(hl.dsp.focus({ workspace = "
      + root.quoteLua("name:" + name) + " }));"
  }

  function withOriginLua(body) {
    return "local origin = hl.get_active_monitor(); " + body
      + " if origin then hl.dispatch(hl.dsp.focus({ monitor = origin.name })) end"
  }

  function focusWorkspace(name) {
    if (!root.monitor || name === "") return
    root.runLua(root.focusHereLua(name))
  }

  function moveWindowTo(name) {
    if (!root.monitor || name === "") return
    root.runLua("local window = hl.get_active_window(); if not window then return end; "
      + root.withOriginLua(root.focusMonitorLua()
        + " hl.dispatch(hl.dsp.window.move({ workspace = "
        + root.quoteLua("name:" + name)
        + ", window = \"address:\" .. window.address, follow = false }));"))
  }

  property real wheelAccumulator: 0

  function cycleBy(step) {
    const ring = root.entries
    if (ring.length < 2) return
    const active = root.monitor && root.monitor.activeWorkspace
      ? String(root.monitor.activeWorkspace.name || "") : ""
    let index = ring.map(function(entry) { return entry.name }).indexOf(active)
    if (index < 0) index = 0
    root.focusWorkspace(ring[((index + step) % ring.length + ring.length)
      % ring.length].name)
  }

  function onWheel(delta) {
    const wheel = Commons.Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps !== 0) root.cycleBy(wheel.steps > 0 ? -1 : 1)
  }

  // --------------------------------------------------------------- hotplug

  function showsOwnSlot() {
    const active = root.monitor && root.monitor.activeWorkspace
    if (!active) return false
    const name = String(active.name || "")
    for (let slot = 1; slot <= root.slotCount; slot++) {
      if (name === root.slotName(slot)) return true
    }
    return false
  }

  function homeSlot() {
    for (let slot = 1; slot <= root.slotCount; slot++) {
      const name = root.slotName(slot)
      if (root.workspaceByName(name) !== null) return name
    }
    return root.slotName(1)
  }

  function adopt() {
    if (!root.monitor || root.prefix === "" || root.showsOwnSlot()) return
    const name = root.homeSlot()
    const workspace = root.workspaceByName(name)
    const stranded = workspace !== null && workspace.monitor !== null
      && workspace.monitor !== root.monitor

    root.runLua(root.withOriginLua(
      (stranded
        ? "hl.dispatch(hl.dsp.workspace.move({ workspace = "
          + root.quoteLua("name:" + name) + ", monitor = "
          + root.quoteLua(root.monitor.name) + " })); "
        : "") + root.focusHereLua(name)))
  }

  Timer {
    id: adoptSettle
    interval: 700
    onTriggered: root.adopt()
  }

  onPrefixChanged: adoptSettle.restart()
  onMonitorChanged: adoptSettle.restart()

  // --------------------------------------------------------------- Shibumi UI

  readonly property var tokens: root.bar && "visualTokens" in root.bar
    ? root.bar.visualTokens : null
  readonly property bool tokenReady: root.tokens !== null
  readonly property color widgetInk: tokenReady
    && typeof root.tokens.widgetContentColor === "function"
    ? root.tokens.widgetContentColor(root.settings,
      root.bar ? root.bar.urgent : Commons.Color.accent)
    : (root.bar ? root.bar.urgent : Commons.Color.accent)
  readonly property int workspacePadding: tokenReady
    && typeof root.tokens.workspacePillPadding === "function"
    ? root.tokens.workspacePillPadding("default") : Commons.Style.space(4)
  readonly property int workspaceGap: tokenReady && root.tokens.contentGap !== undefined
    ? root.tokens.contentGap : Commons.Style.space(5)
  readonly property int markerHeight: Commons.Style.space(16)
  readonly property int markerWidth: Commons.Style.space(16)
  readonly property int focusedMarkerWidth: Commons.Style.space(32)
  readonly property int renderedWorkspaceCount: workspaceRepeater.count
  readonly property real workspaceContentWidth: {
    void(root.entries)
    let total = 0
    for (let index = 0; index < workspaceRepeater.count; index++) {
      const item = workspaceRepeater.itemAt(index)
      if (item) total += item.implicitWidth
    }
    return total + Math.max(0, workspaceRepeater.count - 1) * root.workspaceGap
  }

  implicitWidth: root.bar && root.bar.vertical
    ? root.bar.barSize : workspaceSurface.implicitWidth
  implicitHeight: root.bar && root.bar.vertical
    ? workspaceSurface.implicitHeight : (root.bar ? root.bar.barSize : 28)

  function entryTooltip(entry, occupied, focused) {
    if (entry.parked) return entry.tooltip
    const slot = "Workspace " + entry.label
    const state = focused ? "active" : (occupied ? "occupied" : "empty")
    return slot + " · " + state + " · Right-click to move the focused window"
  }

  Item {
    id: workspaceSurface
    anchors.centerIn: parent
    implicitWidth: root.workspaceContentWidth + root.workspacePadding * 2
    implicitHeight: root.bar ? root.bar.barSize : Commons.Style.space(28)
    width: implicitWidth
    height: implicitHeight

    Loader {
      anchors.fill: parent
      active: root.tokenReady
      sourceComponent: Component {
        Presentation.PillSurface {
          tokenSource: root.tokens
          bar: root.bar
          settings: root.settings
          v1AppearanceEnabled: true
          anchors.fill: parent
          anchors.topMargin: Math.round((parent.height - root.tokens.pillHeight) / 2)
          anchors.bottomMargin: parent.height - root.tokens.pillHeight
            - anchors.topMargin
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      visible: !root.tokenReady
      radius: height / 2
      color: Qt.rgba(root.widgetInk.r, root.widgetInk.g, root.widgetInk.b, 0.08)
      border.width: 1
      border.color: Qt.rgba(root.widgetInk.r, root.widgetInk.g, root.widgetInk.b, 0.20)
    }

    Row {
      id: workspaceRow
      anchors.centerIn: parent
      spacing: root.workspaceGap
      width: root.workspaceContentWidth

      Repeater {
        id: workspaceRepeater
        model: root.entries

        delegate: Item {
          id: cell
          required property var modelData
          readonly property var workspace: root.workspaceByName(modelData.name)
          readonly property bool occupied: workspace !== null
            && workspace.toplevels && workspace.toplevels.values.length > 0
          readonly property bool focused: root.monitor !== null
            && root.monitor.activeWorkspace !== null
            && String(root.monitor.activeWorkspace.name || "") === modelData.name
          readonly property bool parked: modelData.parked === true

          implicitWidth: parked ? root.markerWidth
            : (focused ? root.focusedMarkerWidth : root.markerWidth)
          implicitHeight: workspaceSurface.height

          Behavior on implicitWidth {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
          }
          Behavior on scale { NumberAnimation { duration: 120 } }

          Rectangle {
            visible: !cell.parked
            anchors.centerIn: parent
            width: cell.focused ? Commons.Style.space(34) : Commons.Style.space(16)
            height: root.markerHeight
            radius: height / 2
            color: Qt.rgba(root.widgetInk.r, root.widgetInk.g, root.widgetInk.b,
              cell.focused ? 0.20 : cell.occupied ? 0.18 : 0.06)
            Behavior on width {
              NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
          }

          Rectangle {
            visible: !cell.parked
            anchors.centerIn: parent
            width: cell.focused ? Commons.Style.space(26) : Commons.Style.space(8)
            height: Commons.Style.space(8)
            radius: height / 2
            color: cell.focused || cell.occupied ? root.widgetInk
              : Qt.rgba(root.widgetInk.r, root.widgetInk.g, root.widgetInk.b, 0.25)
            Behavior on width {
              NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
          }

          Rectangle {
            visible: cell.parked
            anchors.centerIn: parent
            width: Commons.Style.space(16)
            height: width
            radius: width / 2
            color: Qt.rgba(root.widgetInk.r, root.widgetInk.g, root.widgetInk.b, 0.16)
            border.width: 1
            border.color: Qt.rgba(root.widgetInk.r, root.widgetInk.g, root.widgetInk.b, 0.55)

            Text {
              anchors.centerIn: parent
              text: cell.modelData.label
              color: root.widgetInk
              font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: Commons.Style.space(10)
              renderType: Text.NativeRendering
            }
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
              cell.scale = 1.15
              if (root.bar && typeof root.bar.showTooltip === "function")
                root.bar.showTooltip(workspaceSurface,
                  root.entryTooltip(cell.modelData, cell.occupied, cell.focused))
            }
            onExited: {
              cell.scale = 1
              if (root.bar && typeof root.bar.hideTooltip === "function")
                root.bar.hideTooltip(workspaceSurface)
            }
            onClicked: function(mouse) {
              if (root.bar && typeof root.bar.hideTooltip === "function")
                root.bar.hideTooltip(workspaceSurface)
              if (mouse.button === Qt.RightButton)
                root.moveWindowTo(cell.modelData.name)
              else root.focusWorkspace(cell.modelData.name)
            }
            onWheelMoved: function(delta) { root.onWheel(delta) }
          }
        }
      }
    }
  }
}
