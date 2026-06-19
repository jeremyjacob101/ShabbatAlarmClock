import Foundation

struct NotificationSoundFileStore {
    static let shared = NotificationSoundFileStore()

    private let fileManager: FileManager
    private let customSoundsDirectory: URL?

    init(fileManager: FileManager = .default, customSoundsDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.customSoundsDirectory = customSoundsDirectory
    }

    func prepareSoundFile(from sourceURL: URL, fileName: String) throws -> String {
        let destinationDirectory = try soundsDirectory()
        try fileManager.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )

        let destinationURL = destinationDirectory.appendingPathComponent(
            fileName,
            isDirectory: false
        )

        if !soundFileMatches(sourceURL: sourceURL, destinationURL: destinationURL) {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }

        return fileName
    }

    private func soundsDirectory() throws -> URL {
        if let customSoundsDirectory {
            return customSoundsDirectory
        }

        let libraryDirectory = try fileManager.url(
            for: .libraryDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return libraryDirectory.appendingPathComponent("Sounds", isDirectory: true)
    }

    private func soundFileMatches(sourceURL: URL, destinationURL: URL) -> Bool {
        guard fileManager.fileExists(atPath: destinationURL.path) else {
            return false
        }

        guard let sourceValues = try? sourceURL.resourceValues(forKeys: [.fileSizeKey]),
              let destinationValues = try? destinationURL.resourceValues(forKeys: [.fileSizeKey]),
              sourceValues.fileSize == destinationValues.fileSize else {
            return false
        }

        guard let sourceData = try? Data(contentsOf: sourceURL),
              let destinationData = try? Data(contentsOf: destinationURL) else {
            return false
        }

        return sourceData == destinationData
    }
}
