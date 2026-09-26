import ScreenSaver
import WebKit

@objc(VoxelSaverView)
class VoxelSaverView: ScreenSaverView {
    
    private var webView: WKWebView!
    private var timer: Timer?
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.animationTimeInterval = 1.0 / 60.0
        
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: self.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        
        let bundle = Bundle(for: type(of: self))
        if let htmlPath = bundle.path(forResource: "index", ofType: "html") {
            let url = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        
        self.addSubview(webView)
    }
    
    override func startAnimation() {
        super.startAnimation()
        AudioAnalyzer.shared.startCapture()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateWebViewAudio()
        }
    }
    
    override func stopAnimation() {
        super.stopAnimation()
        AudioAnalyzer.shared.stopCapture()
        timer?.invalidate()
    }
    
    private func updateWebViewAudio() {
        let audioData = AudioAnalyzer.shared.frequencyData
        let jsArray = audioData.map { String($0) }.joined(separator: ",")
        let jsCode = "if(window.updateAudio) { window.updateAudio([\(jsArray)]); }"
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
    
    override var hasConfigureSheet: Bool {
        return false
    }
    
    override var configureSheet: NSWindow? {
        return nil
    }
}
