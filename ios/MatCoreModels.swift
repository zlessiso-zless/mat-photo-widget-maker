import Foundation
import SwiftUI
import Combine

// MARK: - Mat Item Models

public enum MatItemType: Codable, Equatable {
    case cutout(imageFileName: String)
    case postIt(text: String, colorHex: String)
    case letter(char: String, style: String)
    case polaroid(imageFileName: String, caption: String)
    case sticker(emoji: String)
}

public struct MatItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var type: MatItemType
    public var x: Double // Normalized coordinate 0.0 ... 1.0
    public var y: Double // Normalized coordinate 0.0 ... 1.0
    public var scale: Double
    public var rotationDegrees: Double
    public var zIndex: Double

    public init(
        id: UUID = UUID(),
        type: MatItemType,
        x: Double = 0.5,
        y: Double = 0.5,
        scale: Double = 1.0,
        rotationDegrees: Double = 0.0,
        zIndex: Double = 0.0
    ) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.zIndex = zIndex
    }
}

public struct MatBoard: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var backgroundColorHex: String
    public var textureName: String?
    public var items: [MatItem]
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String = "My Mat",
        backgroundColorHex: String = "#F3EDE2",
        textureName: String? = "paper_grain",
        items: [MatItem] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.backgroundColorHex = backgroundColorHex
        self.textureName = textureName
        self.items = items
        self.updatedAt = updatedAt
    }
}

// MARK: - App Group Storage & Widget Sync Service

public final class MatStorageService {
    public static let shared = MatStorageService()
    public static let appGroupIdentifier = "group.com.yourcompany.matmaker"
    
    private var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var dataFileURL: URL {
        containerURL.appendingPathComponent("current_mat.json")
    }
    
    public func saveMat(_ mat: MatBoard) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(mat)
        try data.write(to: dataFileURL, options: .atomic)
    }
    
    public func loadMat() -> MatBoard? {
        guard let data = try? Data(contentsOf: dataFileURL) else { return nil }
        return try? JSONDecoder().decode(MatBoard.self, from: data)
    }
    
    public func saveCutoutImage(_ image: UIImage, fileName: String) throws -> String {
        let fileURL = containerURL.appendingPathComponent(fileName)
        guard let pngData = image.pngData() else {
            throw NSError(domain: "MatStorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "PNG compression failed"])
        }
        try pngData.write(to: fileURL, options: .atomic)
        return fileName
    }
    
    public func loadCutoutImage(fileName: String) -> UIImage? {
        let fileURL = containerURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
}
