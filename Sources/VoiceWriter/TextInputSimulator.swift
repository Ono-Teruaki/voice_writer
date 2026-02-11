import AppKit
import Carbon

/// Simulates text input to the active application using clipboard-based paste.
/// This approach reliably handles Japanese (Unicode) text.
final class TextInputSimulator {
    
    /// Input the given text into the currently active application.
    /// Uses clipboard paste (Cmd+V) with clipboard content restoration.
    func inputText(_ text: String) {
        guard !text.isEmpty else { return }
        
        let pasteboard = NSPasteboard.general
        
        // Save current clipboard content
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> (String, Data)? in
            guard let type = item.types.first,
                  let data = item.data(forType: type) else { return nil }
            return (type.rawValue, data)
        } ?? []
        
        // Set transcribed text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Small delay to ensure clipboard is set
        usleep(50_000) // 50ms
        
        // Simulate Cmd+V paste
        simulatePaste()
        
        // Restore previous clipboard content after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            for (typeRaw, data) in savedItems {
                let type = NSPasteboard.PasteboardType(typeRaw)
                pasteboard.setData(data, forType: type)
            }
        }
    }
    
    /// Simulate Cmd+V key combination
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Virtual key code for 'V' is 9
        let vKeyCode: CGKeyCode = 9
        
        // Key down with Command modifier
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        
        // Key up with Command modifier
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    /// Check if the app has accessibility permissions (required for CGEvent posting)
    static func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// Prompt the user to grant accessibility permissions
    static func promptAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
