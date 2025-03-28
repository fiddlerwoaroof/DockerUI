import SwiftUI

@main
struct DockerUIApp: App {
  @StateObject private var manager = DockerManager()
  @Environment(\.openWindow) private var openWindow

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(manager)
    }

    SettingsWindow(manager: manager)
    LogWindowScene()

    // swiftlint:disable:next unused_parameter
    WindowGroup(for: DockerContainer.self) { $container in
      if let container {
        ContainerLogsView(container: container, manager: manager)
      }
    }

    .commands {
      CommandGroup(replacing: .appInfo) {
        Button("Settings") {
          openWindow(id: "Settings")
        }
        .keyboardShortcut(",")

        Button("Show Logs") {
          openWindow(id: "Log")
        }
        .keyboardShortcut("l", modifiers: [.command, .shift])

        Divider()

        Button("Refresh Containers") {
          manager.fetchContainers()
          manager.fetchImages()
        }
        .keyboardShortcut("r")
      }
      CommandGroup(replacing: .help) { /* remove help */  }
      CommandGroup(replacing: .newItem) { /* remove new */  }
      CommandGroup(replacing: .saveItem) { /* remove save */  }
    }
  }
}
