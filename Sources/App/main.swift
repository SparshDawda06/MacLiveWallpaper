import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Stay a normal app until the one-time audio prompt is done.
// An agent plus a desktop-level key window was re-showing that dialog.
app.setActivationPolicy(.regular)
app.run()
