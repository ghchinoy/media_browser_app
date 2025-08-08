import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    var channel: FlutterMethodChannel?
    var initialPath: String?

    override func application(_ sender: NSApplication, openFiles: [String]) {
        if let firstPath = openFiles.first {
            self.initialPath = firstPath
        }

        if let channel = self.channel, let path = self.initialPath {
            channel.invokeMethod("setInitialDirectory", arguments: path)
            self.initialPath = nil
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }

    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        let controller: FlutterViewController =
            mainFlutterWindow?.contentViewController as! FlutterViewController
        channel = FlutterMethodChannel(
            name: "com.example.media_browser/args",
            binaryMessenger: controller.engine.binaryMessenger)

        if let path = self.initialPath {
            channel?.invokeMethod("setInitialDirectory", arguments: path)
            self.initialPath = nil
        }
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
