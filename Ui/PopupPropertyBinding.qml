import QtQuick

Binding {
    required property var resolve
    value: resolve()
    when: PopupAppearance.enabled
    restoreMode: Binding.RestoreBindingOrValue
}
