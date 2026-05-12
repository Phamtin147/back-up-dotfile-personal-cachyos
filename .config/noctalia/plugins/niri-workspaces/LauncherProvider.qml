import QtQuick
import Quickshell
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  property string name: "Niri Workspaces"
  property var launcher: null
  property bool handleSearch: false
  property string supportedLayouts: "list"
  property bool supportsAutoPaste: false

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string prefix: cfg.launcherPrefix ?? defaults.launcherPrefix ?? ">ws"

  // `!` immediately after the prefix enters rename mode. `!!` resets.
  readonly property string renameSigil: "!"

  readonly property var mainInstance: pluginApi?.mainInstance

  // Workspace id set by the pencil/eraser buttons. When >= 0, indicates a
  // button-initiated edit so onActivate skips the post-apply focus jump.
  // The keyboard flow (`>ws !name` / `>ws !!`) leaves this at -1 and targets
  // `highlightedWorkspaceId` instead, then focuses the edited workspace.
  property int editTargetId: -1

  // Workspace id the user last highlighted while in filter mode. Captured
  // by the selectedIndexChanged handler below and frozen the moment rename
  // mode kicks in (since the launcher resets selectedIndex to 0 whenever
  // results change).
  property int highlightedWorkspaceId: -1

  // Parallel to the last filter-mode results array: workspace id at each
  // row index, or -1 for non-workspace rows (e.g. "no matches").
  property var filterResultWorkspaceIds: []

  Connections {
    target: mainInstance
    enabled: mainInstance !== null && launcher !== null
    function onWorkspacesChanged() {
      if (launcher && launcher.searchText && launcher.searchText.startsWith(prefix)) {
        launcher.updateResults();
      }
    }
  }

  // Track which workspace is highlighted in the list — but only while in
  // filter mode. Skip updates in rename mode so the frozen highlight at the
  // moment the user typed `!` survives the selectedIndex reset.
  Connections {
    target: launcher
    enabled: launcher !== null
    function onSelectedIndexChanged() {
      root.captureHighlightFromLauncher();
    }
  }

  function captureHighlightFromLauncher() {
    if (!launcher) return;
    var txt = launcher.searchText || "";
    if (!txt.startsWith(prefix)) return;
    var content = txt.slice(prefix.length).replace(/^\s+/, "");
    if (content.startsWith(renameSigil)) return; // freeze during rename mode
    var idx = launcher.selectedIndex;
    if (idx < 0 || idx >= filterResultWorkspaceIds.length) return;
    var wsId = filterResultWorkspaceIds[idx];
    if (wsId !== null && wsId !== undefined && wsId !== -1) {
      highlightedWorkspaceId = wsId;
    }
  }

  function handleCommand(searchText) {
    return searchText.startsWith(prefix);
  }

  function commands() {
    return [{
      "name": prefix,
      "description": pluginApi?.tr("launcher.command.description"),
      "icon": "layout-grid",
      "isTablerIcon": true,
      "isImage": false,
      "onActivate": function () {
        if (launcher) launcher.setSearchText(prefix + " ");
      }
    }];
  }

  function getResults(searchText) {
    if (!searchText.startsWith(prefix)) return [];

    if (!mainInstance || !mainInstance.isNiri) {
      filterResultWorkspaceIds = [];
      return [{
        "name": pluginApi?.tr("launcher.notNiri.name"),
        "description": pluginApi?.tr("launcher.notNiri.description"),
        "icon": "alert-circle",
        "isTablerIcon": true,
        "isImage": false,
        "onActivate": function () {}
      }];
    }

    var content = searchText.slice(prefix.length).replace(/^\s+/, "");

    if (content.startsWith(renameSigil)) {
      return renameModeResults(content.slice(renameSigil.length).replace(/^\s+/, ""));
    }

    // Exiting rename mode — clear any pending pencil/eraser target.
    if (editTargetId !== -1) editTargetId = -1;
    return filterModeResults(content.trim());
  }

  function filterModeResults(filter) {
    var results = [];
    var ids = [];
    var workspaces = mainInstance.sortedWorkspaces;
    var filterLower = filter.toLowerCase();

    for (var i = 0; i < workspaces.length; i++) {
      var ws = workspaces[i];
      if (filter.length === 0 || matchesFilter(ws, filterLower)) {
        results.push(buildWorkspaceEntry(ws));
        ids.push(ws.id);
      }
    }

    if (results.length === 0 && filter.length > 0) {
      results.push({
        "name": pluginApi?.tr("launcher.noMatches.name", { "filter": filter }),
        "description": pluginApi?.tr("launcher.noMatches.description"),
        "icon": "mood-empty",
        "isTablerIcon": true,
        "isImage": false,
        "onActivate": function () {}
      });
      ids.push(-1);
    }

    filterResultWorkspaceIds = ids;
    // Seed the highlight to the first visible workspace so an immediate
    // transition to rename mode (before the user arrows) still has a target.
    if (ids.length > 0 && ids[0] !== -1) {
      highlightedWorkspaceId = ids[0];
    }

    // When no filter is active, auto-highlight the focused workspace instead
    // of row 0 — matches "which workspace am I editing/jumping from" better
    // than "first row on this output". LauncherCore sets selectedIndex=0 at
    // the end of updateResults, so we have to override via callLater.
    if (filter.length === 0 && launcher && mainInstance.focusedWorkspace) {
      var focusedId = mainInstance.focusedWorkspace.id;
      var focusedIdx = ids.indexOf(focusedId);
      if (focusedIdx > 0) {
        Qt.callLater(function () {
          if (launcher) launcher.selectedIndex = focusedIdx;
        });
        highlightedWorkspaceId = focusedId;
      }
    }
    return results;
  }

  function renameModeResults(newName) {
    var target = resolveRenameTarget();
    if (!target) {
      return [{
        "name": pluginApi?.tr("launcher.noHighlighted.name"),
        "description": pluginApi?.tr("launcher.noHighlighted.description"),
        "icon": "alert-circle",
        "isTablerIcon": true,
        "isImage": false,
        "onActivate": function () {}
      }];
    }

    var targetId = target.id;
    var currentName = (target.name && target.name.length > 0) ? target.name : "";
    var targetLabel = currentName.length > 0 ? "\"" + currentName + "\"" : "Workspace " + target.idx;

    // `!!` — reset target's name.
    if (newName.startsWith(renameSigil)) {
      return [{
        "name": pluginApi?.tr("launcher.resetPrompt.name", { "target": targetLabel }),
        "description": pluginApi?.tr("launcher.resetPrompt.description"),
        "icon": "eraser",
        "isTablerIcon": true,
        "isImage": false,
        "onActivate": function () {
          applyEdit(targetId, null);
        }
      }];
    }

    if (newName.length === 0) {
      var promptName = currentName.length > 0
        ? pluginApi?.tr("launcher.renamePrompt.nameWithCurrent", { "current": currentName })
        : pluginApi?.tr("launcher.renamePrompt.name", { "idx": target.idx });
      return [{
        "name": promptName,
        "description": pluginApi?.tr("launcher.renamePrompt.description", { "sigil": renameSigil }),
        "icon": "pencil",
        "isTablerIcon": true,
        "isImage": false,
        "onActivate": function () {}
      }];
    }

    // No-op: user pressed Enter without changing the pre-filled name.
    if (newName === currentName) {
      return [{
        "name": pluginApi?.tr("launcher.applyRename.unchangedName", { "name": newName }),
        "description": pluginApi?.tr("launcher.applyRename.unchangedDescription"),
        "icon": "pencil",
        "isTablerIcon": true,
        "isImage": false,
        "onActivate": function () {
          root.editTargetId = -1;
          if (launcher) launcher.setSearchText(prefix + " ");
        }
      }];
    }

    return [{
      "name": pluginApi?.tr("launcher.applyRename.name", { "name": newName }),
      "description": pluginApi?.tr("launcher.applyRename.description", { "target": targetLabel }),
      "icon": "pencil",
      "isTablerIcon": true,
      "isImage": false,
      "onActivate": function () {
        applyEdit(targetId, newName);
      }
    }];
  }

  // Apply a rename (newName truthy) or reset (newName === null) and return
  // the launcher to the filtered-list view. We never auto-focus the edited
  // workspace or close the launcher — the user stays in the list so they
  // can keep editing or jump somewhere else on their own terms.
  function applyEdit(targetId, newName) {
    var ws = mainInstance.findWorkspaceById(targetId) || mainInstance.focusedWorkspace;
    if (newName === null) {
      mainInstance.unsetWorkspaceName(ws);
    } else {
      mainInstance.renameWorkspace(ws, newName);
    }
    root.editTargetId = -1;
    if (launcher) launcher.setSearchText(prefix + " ");
  }

  function resolveRenameTarget() {
    // Pencil/eraser wins — they pinpoint a specific row.
    if (editTargetId !== -1) {
      var targeted = mainInstance.findWorkspaceById(editTargetId);
      if (targeted) return targeted;
    }
    // Keyboard flow: whichever workspace was highlighted in the list.
    if (highlightedWorkspaceId !== -1) {
      var highlighted = mainInstance.findWorkspaceById(highlightedWorkspaceId);
      if (highlighted) return highlighted;
    }
    // Last resort when the launcher has no usable highlight.
    return mainInstance.focusedWorkspace;
  }

  function matchesFilter(ws, filterLower) {
    if (String(ws.idx).indexOf(filterLower) !== -1) return true;
    if (ws.name && ws.name.toLowerCase().indexOf(filterLower) !== -1) return true;
    if (ws.output && ws.output.toLowerCase().indexOf(filterLower) !== -1) return true;
    return false;
  }

  function workspaceLabel(ws) {
    if (ws.name && ws.name.length > 0) return ws.idx + " · " + ws.name;
    return pluginApi?.tr("launcher.unnamedLabel", { "idx": ws.idx });
  }

  function buildWorkspaceEntry(ws) {
    var label = workspaceLabel(ws);
    if (ws.isFocused) label += pluginApi?.tr("launcher.currentSuffix");
    var descKey = ws.isFocused ? "launcher.focus.descriptionCurrent" : "launcher.focus.description";
    var desc = pluginApi?.tr(descKey);
    if (ws.output) desc = desc + " — " + ws.output;
    var wsId = ws.id;
    var hasName = !!(ws.name && ws.name.length > 0);
    return {
      "name": label,
      "description": desc,
      "icon": ws.isFocused ? "check" : "chevron-right",
      "isTablerIcon": true,
      "isImage": false,
      "provider": root,
      "workspaceId": wsId,
      "workspaceHasName": hasName,
      "onActivate": function () {
        var target = mainInstance.findWorkspaceById(wsId);
        if (target) mainInstance.focusWorkspace(target);
        if (launcher) launcher.close();
      }
    };
  }

  // Per-row action buttons. Button-initiated edits set editTargetId so the
  // rename mode resolves this specific row and skips the post-apply focus.
  function getItemActions(item) {
    if (!item || item.workspaceId === undefined) return [];

    var wsId = item.workspaceId;
    var actions = [];

    actions.push({
      "icon": "pencil",
      "tooltip": pluginApi?.tr("launcher.actions.rename"),
      "action": function () {
        root.editTargetId = wsId;
        var ws = mainInstance.findWorkspaceById(wsId);
        var existing = (ws && ws.name && !ws.name.startsWith(renameSigil)) ? ws.name : "";
        if (launcher) launcher.setSearchText(prefix + " " + renameSigil + existing);
      }
    });

    if (item.workspaceHasName) {
      actions.push({
        "icon": "eraser",
        "tooltip": pluginApi?.tr("launcher.actions.reset"),
        "action": function () {
          // Mark as button-initiated so any refresh of highlightedWorkspaceId
          // doesn't accidentally bring keyboard-flow focus-jump semantics in.
          root.editTargetId = wsId;
          var ws = mainInstance.findWorkspaceById(wsId);
          if (ws) mainInstance.unsetWorkspaceName(ws);
          root.editTargetId = -1;
        }
      });
    }

    return actions;
  }
}
