// Humanix — Historique des notifications (singleton), alimenté par Notification.qml.
pragma Singleton
import Quickshell
import QtQuick

Singleton {
  property ListModel model: ListModel {}

  function add(summary, body, app) {
    model.insert(0, { summary: summary || "", body: body || "", app: app || "" })
    while (model.count > 50) model.remove(50)
  }

  function clearAll() { model.clear() }
}
