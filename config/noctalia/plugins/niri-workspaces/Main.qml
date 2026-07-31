import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  readonly property bool isNiri: CompositorService.isNiri

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string launcherPrefix: cfg.launcherPrefix ?? defaults.launcherPrefix ?? ">ws"

  // Snapshot of CompositorService.workspaces as a plain array. Rebuilt on
  // workspaceChanged so JS-array consumers (LauncherProvider) get a stable,
  // iterable view. The backend ListModel is already sorted by output+idx.
  property var sortedWorkspaces: []
  property var focusedWorkspace: null

  signal workspacesChanged

  Connections {
    target: CompositorService
    function onWorkspaceChanged() {
      root.rebuildWorkspaces();
    }
  }

  function rebuildWorkspaces() {
    var arr = [];
    var focused = null;
    var model = CompositorService.workspaces;
    for (var i = 0; i < model.count; i++) {
      var w = model.get(i);
      arr.push(w);
      if (w.isFocused) focused = w;
    }
    sortedWorkspaces = arr;
    focusedWorkspace = focused;
    workspacesChanged();
  }

  // Resolve a workspace into a `--workspace` reference acceptable to the
  // niri CLI. The CLI parses numeric refs as *idx* (not id) via
  // WorkspaceReferenceArg::Index, so `ws.idx` is the only correct numeric
  // reference — `ws.id` would silently target a different workspace.
  // Names are unique across niri and preferred when available.
  function workspaceRef(ws) {
    if (!ws) return null;
    if (ws.name && ws.name.length > 0) return ws.name;
    return String(ws.idx);
  }

  function findWorkspaceById(id) {
    for (var i = 0; i < sortedWorkspaces.length; i++) {
      if (sortedWorkspaces[i].id === id) return sortedWorkspaces[i];
    }
    return null;
  }

  function renameWorkspace(ws, newName) {
    if (!isNiri || !ws) return;
    var trimmed = (newName || "").trim();
    // niri's two subcommands take the target in different forms:
    //   set-workspace-name <NAME> [--workspace <REF>]
    //   unset-workspace-name [<REF>]
    // Passing --workspace to unset-workspace-name makes niri reject the
    // command, so branch here. Omitting the reference entirely makes niri
    // target the focused workspace, which is what we want when ws is
    // already focused (also avoids our idx ref misfiring for unnamed
    // workspaces).
    var args = ["niri", "msg", "action"];
    var ref = ws.isFocused ? null : workspaceRef(ws);

    if (trimmed.length === 0) {
      args.push("unset-workspace-name");
      if (ref !== null) args.push(ref);
    } else {
      args.push("set-workspace-name", trimmed);
      if (ref !== null) args.push("--workspace", ref);
    }

    Logger.i("NiriWorkspaces", "Running:", args.join(" "));
    Quickshell.execDetached(args);
  }

  function unsetWorkspaceName(ws) {
    renameWorkspace(ws, "");
  }

  function renameCurrent(newName) {
    if (!focusedWorkspace) {
      Logger.w("NiriWorkspaces", "No focused workspace to rename");
      return;
    }
    renameWorkspace(focusedWorkspace, newName);
  }

  function unsetCurrentName() {
    if (!focusedWorkspace) {
      Logger.w("NiriWorkspaces", "No focused workspace to unset");
      return;
    }
    unsetWorkspaceName(focusedWorkspace);
  }

  function focusWorkspace(ws) {
    if (!isNiri || !ws) return;
    // niri's `focus-workspace <idx>` toggles back to the previous workspace
    // when the target is already focused. Skip the dispatch so re-selecting
    // the current workspace is a no-op.
    if (ws.isFocused) return;
    var ref = workspaceRef(ws);
    if (ref === null) return;
    Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", ref]);
  }

  IpcHandler {
    target: "plugin:niri-workspaces"

    // Mirrors the shell's `launcher emoji` toggle: open the launcher in
    // workspace mode, close it if already in that mode, or switch modes if
    // it's open on a different prefix.
    function toggle() {
      if (!pluginApi) return;
      pluginApi.withCurrentScreen(screen => {
        var prefix = root.launcherPrefix;
        var searchText = PanelService.getLauncherSearchText(screen);
        var isInWsMode = searchText.startsWith(prefix);
        if (!PanelService.isLauncherOpen(screen)) {
          PanelService.openLauncherWithSearch(screen, prefix + " ");
        } else if (isInWsMode) {
          PanelService.closeLauncher(screen);
        } else {
          PanelService.setLauncherSearchText(screen, prefix + " ");
        }
      }, Settings.data.appLauncher.overviewLayer);
    }

    function renameCurrent(name: string) {
      root.renameCurrent(name);
    }

    function unsetCurrent() {
      root.unsetCurrentName();
    }
  }

  Component.onCompleted: {
    if (isNiri) {
      Logger.i("NiriWorkspaces", "Using CompositorService for workspace state");
    } else {
      Logger.w("NiriWorkspaces", "Not running on Niri — plugin inactive");
    }
    rebuildWorkspaces();
  }
}
