import HotKey
import Carbon

/// Manages global hotkey registration for Cmd+Option+V.
/// Uses the Carbon RegisterEventHotKey API via the HotKey package.
final class HotkeyManager {
    private var hotKey: HotKey?
    
    /// Callback invoked when the hotkey is pressed
    var onHotkeyPressed: (() -> Void)?
    
    /// Register the global hotkey (Cmd+Option+V)
    func register() {
        hotKey = HotKey(key: .v, modifiers: [.command, .option])
        hotKey?.keyDownHandler = { [weak self] in
            self?.onHotkeyPressed?()
        }
    }
    
    /// Unregister the global hotkey
    func unregister() {
        hotKey = nil
    }
}
