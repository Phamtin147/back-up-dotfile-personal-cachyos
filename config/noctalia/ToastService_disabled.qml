pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  signal notify(string title, string description, string icon, string type, int duration, string actionLabel, var actionCallback)
  signal dismiss

  // All toast notifications disabled
  function showNotice(title, description = "", icon = "", duration = 3000, actionLabel = "", actionCallback = null) {}
  function showWarning(title, description = "", duration = 4000, actionLabel = "", actionCallback = null) {}
  function showError(title, description = "", duration = 6000, actionLabel = "", actionCallback = null) {}

  function dismissToast() {
    dismiss();
  }
}
