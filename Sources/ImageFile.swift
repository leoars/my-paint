import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// File formats offered by Save As, in the order Paint lists them.
enum ImageFormat: CaseIterable {
    case bmp, jpeg, gif, tiff, png

    var type: UTType {
        switch self {
        case .bmp: return .bmp
        case .jpeg: return .jpeg
        case .gif: return .gif
        case .tiff: return .tiff
        case .png: return .png
        }
    }

    var fileExtension: String {
        switch self {
        case .bmp: return "bmp"
        case .jpeg: return "jpg"
        case .gif: return "gif"
        case .tiff: return "tif"
        case .png: return "png"
        }
    }

    var nameKey: String {
        switch self {
        case .bmp: return "format.bmp"
        case .jpeg: return "format.jpeg"
        case .gif: return "format.gif"
        case .tiff: return "format.tiff"
        case .png: return "format.png"
        }
    }

    init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "bmp", "dib": self = .bmp
        case "jpg", "jpeg", "jpe", "jfif": self = .jpeg
        case "gif": self = .gif
        case "tif", "tiff": self = .tiff
        case "png": self = .png
        default: return nil
        }
    }
}

struct ImageFileError: LocalizedError {
    let errorDescription: String?
}

enum ImageFile {
    static func read(_ url: URL) throws -> Bitmap {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let bitmap = Bitmap(image: image) else {
            throw ImageFileError(errorDescription: String(format: L("error.read"), url.lastPathComponent))
        }
        return bitmap
    }

    /// Whether the file is a BMP with one bit per pixel (a monochrome BMP). ImageIO reports such
    /// files as 8-bit gray, so the bit count is read from the header (`biBitCount`, offset 28).
    static func isOneBit(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let header = [UInt8](handle.readData(ofLength: 30))
        guard header.count == 30, header[0] == 0x42, header[1] == 0x4D else { return false }
        return Int(header[28]) | Int(header[29]) << 8 == 1
    }

    static func write(_ bitmap: Bitmap, to url: URL, format: ImageFormat) throws {
        guard let image = bitmap.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL, format.type.identifier as CFString, 1, nil) else {
            throw ImageFileError(errorDescription: String(format: L("error.write"), url.lastPathComponent))
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageFileError(errorDescription: String(format: L("error.write"), url.lastPathComponent))
        }
    }
}
