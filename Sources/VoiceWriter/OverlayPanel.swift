import AppKit
import SwiftUI

/// A floating NSPanel for displaying streaming transcription results.
/// This panel sits above all other windows and does not steal focus.
final class OverlayPanel: NSPanel {
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 120),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        
        // Configure panel behavior
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        
        // Remove standard window buttons
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Position at top center of screen
        positionAtTopCenter()
    }
    
    /// Position the panel at the top center of the main screen
    func positionAtTopCenter() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - self.frame.width / 2
        let y = screenFrame.maxY - self.frame.height - 40
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    /// Show the panel with animation
    func showPanel() {
        self.alphaValue = 0
        self.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1
        }
    }
    
    /// Hide the panel with animation
    func hidePanel() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
    
    /// Set the SwiftUI content view for this panel
    func setOverlayContent(_ view: some View) {
        let hostingView = NSHostingView(rootView: view)
        self.contentView = hostingView
    }
}
