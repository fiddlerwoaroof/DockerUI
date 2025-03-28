import SwiftUI
import Foundation

struct DockerContainer: Identifiable, Codable, Hashable {
    let id: String
    let names: [String]
    let image: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case names = "Names"
        case image = "Image"
        case status = "Status"
    }
}

struct DockerImage: Identifiable, Codable, Hashable {
    var id: String { Id }
    let Id: String
    let RepoTags: [String]?
    let Created: Int
    let Size: Int
}

class DockerEnvironmentDetector {
    static func detectDockerHostPath() -> String? {
        let potentialPaths = [
            "\(NSHomeDirectory())/.rd/docker.sock",
            "\(NSHomeDirectory())/.colima/docker.sock"
        ]
        for path in potentialPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
}

class DockerManager: ObservableObject {
    @Published var containers: [DockerContainer] = []
    @Published var images: [DockerImage] = []
    @Published var socketPath: String = UserDefaults.standard.string(forKey: "dockerHostPath") ?? DockerEnvironmentDetector.detectDockerHostPath() ?? ""
    @Published var refreshInterval: Double = UserDefaults.standard.double(forKey: "refreshInterval") == 0 ? 10 : UserDefaults.standard.double(forKey: "refreshInterval")

    var executor: DockerExecutor? {
        socketPath.isEmpty ? nil : DockerExecutor(socketPath: socketPath)
    }

    private var timer: Timer?

    init() {
        if socketPath.isEmpty, let detected = DockerEnvironmentDetector.detectDockerHostPath() {
            socketPath = detected
            saveDockerHostPath()
        }
        startAutoRefresh()
    }
    private func log(_ message: String, level: String = "INFO") {
        LogManager.shared.addLog(message, level: level, source: "docker-manager")
    }

    func fetchContainers() {
        tryCommand {[weak self] in
            guard let executor = self?.executor else { return }
            let list = try executor.listContainers()
            DispatchQueue.main.async {[weak self] in
                self?.containers = list
            }
        }
    }

    func fetchImages() {
        tryCommand { [weak self] in
            guard let executor = self?.executor else { return }
            let list = try executor.listImages()
            DispatchQueue.main.async {
                self?.images = list
            }
        }
    }

    func startContainer(id: String) {
        tryCommand { [weak self] in
            try self?.executor?.startContainer(id: id)
        }
    }

    func stopContainer(id: String) {
        tryCommand { [weak self]
            in try self?.executor?.stopContainer(id: id)
        }
    }

    private func tryCommand(_ block: @escaping () throws -> Void) {
        DispatchQueue.global().async { [weak self] in
            do {
                try block()
            } catch {
                self?.log("Image fetch error: \(error.localizedDescription)", level: "ERROR")
            }
        }
    }

    func saveDockerHostPath() {
        UserDefaults.standard.set(socketPath, forKey: "dockerHostPath")
    }

    func saveRefreshInterval() {
        UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
        startAutoRefresh()
    }

    private func startAutoRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.fetchContainers()
            self?.fetchImages()
        }
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @StateObject private var manager = DockerManager()

    var backgroundColor: Color {
        colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : Color.white
    }

    var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.05)
    }

    var body: some View {
        TabView {
            containerListView
                .tabItem {
                    Text("Containers")
                }

            imageListView
                .tabItem {
                    Text("Images")
                }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            manager.fetchContainers()
            manager.fetchImages()
        }
        .environmentObject(manager)
    }

    var containerListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(manager.containers) { container in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(container.names.first ?? "Unnamed")
                                .font(.headline)
                            Text(container.image)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text(container.status.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack {
                            if container.status.lowercased().contains("up") {
                                Button("Stop") {
                                    manager.stopContainer(id: container.id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            } else {
                                Button("Start") {
                                    manager.startContainer(id: container.id)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            Button("Logs") {
                                openWindow(value: Optional(container))
                            }
                            .buttonStyle(.link)
                            .controlSize(.small)
                        }
                    }
                    .padding()
                    .background(backgroundColor)
                    .cornerRadius(10)
                    .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    var imageListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(manager.images) { image in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(image.RepoTags?.first ?? "<none>")
                                .font(.headline)
                            Text("Size: \(image.Size / (1024 * 1024)) MB")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("Created: \(Date(timeIntervalSince1970: TimeInterval(image.Created)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(backgroundColor)
                    .cornerRadius(10)
                    .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}



