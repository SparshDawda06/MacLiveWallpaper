import Cocoa
import WebKit

final class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusItem: NSStatusItem!
    var wallpaperWindow: NSWindow!
    var webView: WKWebView!
    var timer: Timer?
    private var didShowWallpaper = false
    private var termSource: DispatchSourceSignal?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        signal(SIGTERM, SIG_IGN)
        let term = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        term.setEventHandler {
            AudioAnalyzer.shared.stopCapture()
            NSApp.terminate(nil)
        }
        term.resume()
        termSource = term

        setupMenu()
        NSApp.activate(ignoringOtherApps: true)
        // Wallpaper stays off until the one audio prompt finishes, so the dialog is not covered.
        AudioAnalyzer.shared.onListening = { [weak self] in
            self?.showWallpaper()
        }
        AudioAnalyzer.shared.startCapture()
        // Sphere comes up even if the audio device is still attaching.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showWallpaper()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        AudioAnalyzer.shared.stopCapture()
        timer?.invalidate()
    }

    private func showWallpaper() {
        if didShowWallpaper { return }
        didShowWallpaper = true
        NSApp.setActivationPolicy(.accessory)
        setupWallpaperWindow()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateWebViewAudio()
        }
    }
    
    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Wallpaper"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    private func setupWallpaperWindow() {
        guard let screen = NSScreen.main else { return }
        
        wallpaperWindow = DesktopWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        // Push behind desktop icons
        wallpaperWindow.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
        wallpaperWindow.ignoresMouseEvents = true
        wallpaperWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        wallpaperWindow.backgroundColor = NSColor.black
        
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: wallpaperWindow.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground") // Transparent background
        
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html") {
            let url = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        
        wallpaperWindow.contentView?.addSubview(webView)
        // Behind the icons, in front of the desktop picture, without becoming key.
        wallpaperWindow.orderFrontRegardless()
    }
    
    private func updateWebViewAudio() {
        let audioData = AudioAnalyzer.shared.frequencyData
        // Create JS array string
        let jsArray = audioData.map { String($0) }.joined(separator: ",")
        let jsCode = "if(window.updateAudio) { window.updateAudio([\(jsArray)]); }"
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
}
