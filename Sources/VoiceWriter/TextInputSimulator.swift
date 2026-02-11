import AppKit
import Carbon

/// Simulates text input to the active application using clipboard-based paste.
/// Uses AppleScript via System Events for reliable cross-app Cmd+V simulation.
final class TextInputSimulator {
    
    /// Input the given text into the currently active application.
    /// Uses clipboard paste (Cmd+V) with clipboard content restoration.
    func inputText(_ text: String) {
        guard !text.isEmpty else { return }
        
        let pasteboard = NSPasteboard.general
        
        // Save current clipboard content
        let savedString = pasteboard.string(forType: .string)
        
        // Set transcribed text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Short delay to ensure clipboard is set
        Thread.sleep(forTimeInterval: 0.1)
        
        // Try AppleScript-based paste first (most reliable)
        let success = pasteViaAppleScript()
        
        if !success {
            // Fallback to CGEvent-based paste
            print("[VoiceWriter] AppleScript paste failed, trying CGEvent fallback")
            pasteViaCGEvent()
        }
        
        // Restore previous clipboard content after a generous delay
        if let savedString = savedString {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                pasteboard.clearContents()
                pasteboard.setString(savedString, forType: .string)
            }
        }
    }
    
    /// Simulate Cmd+V using AppleScript's System Events (most reliable method)
    /// Returns true if AppleScript executed successfully
    private func pasteViaAppleScript() -> Bool {
        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("[VoiceWriter] AppleScript error: \(error)")
                return false
            }
            return true
        }
        return false
    }
    
    /// Fallback: Simulate Cmd+V using CGEvent
    private func pasteViaCGEvent() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 9
        
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cgAnnotatedSessionEventTap)
        }
        
        Thread.sleep(forTimeInterval: 0.05)
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
    
    /// Check if the app has accessibility permissions (required for text input simulation)
    static func checkAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Prompt the user to grant accessibility permissions
    static func promptAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
    }
}
