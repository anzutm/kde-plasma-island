// LiveConfigSync.qml — Real-time live preview for Plasma 6 KCM config pages
// Writes live changes to Plasmoid.configuration immediately while tracking unsavedChanges and reverting on Discard/Cancel.
import QtQuick
import org.kde.plasma.plasmoid

QtObject {
    id: sync

    required property var targetPage
    required property var keys

    property bool unsavedChanges: false
    property var  _savedSnapshot: ({})
    property bool _ready:         false

    function _configObj() {
        if (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) return Plasmoid.configuration
        if (typeof plasmoid !== "undefined" && plasmoid && plasmoid.configuration) return plasmoid.configuration
        return null
    }

    function _valuesEqual(a, b) {
        if (typeof a === "number" && typeof b === "number") {
            return Math.abs(a - b) < 0.0005
        }
        return String(a) === String(b)
    }

    function _recomputeDirty() {
        let dirty = false
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i]
            if (!_valuesEqual(targetPage["cfg_" + k], _savedSnapshot[k])) {
                dirty = true
                break
            }
        }
        unsavedChanges = dirty
    }

    function syncKey(k) {
        if (!_ready) return
        const cfg = _configObj()
        const propName = "cfg_" + k
        if (cfg && (propName in targetPage)) {
            const val = targetPage[propName]
            if (!_valuesEqual(cfg[k], val)) {
                cfg[k] = val
            }
        }
        _recomputeDirty()
    }

    function commitSaved() {
        const next = {}
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i]
            next[k] = targetPage["cfg_" + k]
        }
        _savedSnapshot = next
        unsavedChanges = false
    }

    function init() {
        const cfg = _configObj()
        const snap = {}
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i]
            const propName = "cfg_" + k
            snap[k] = (cfg && cfg[k] !== undefined) ? cfg[k] : targetPage[propName]
            const sig = targetPage[propName + "Changed"]
            if (sig && sig.connect) {
                sig.connect(function() { sync.syncKey(k) })
            }
        }
        _savedSnapshot = snap
        _ready = true
        _recomputeDirty()
    }

    Component.onCompleted: Qt.callLater(init)

    Component.onDestruction: {
        if (!unsavedChanges) return
        const cfg = _configObj()
        if (!cfg) return
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i]
            if (k in _savedSnapshot) {
                cfg[k] = _savedSnapshot[k]
            }
        }
    }
}
