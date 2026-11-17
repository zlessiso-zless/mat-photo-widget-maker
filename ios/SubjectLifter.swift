import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

public enum SubjectLifterError: LocalizedError {
    case invalidSourceImage
    case noForegroundSubjectDetected
    case maskGenerationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidSourceImage:
            return "Unable to create a valid CIImage from the provided input."
        case .noForegroundSubjectDetected:
            return "No prominent foreground object or subject was detected."
        case .maskGenerationFailed:
            return "Failed to extract and render the masked subject."
        }
    }
}

/// Native subject extraction engine matching iOS 17+ Photos / Mat App capabilities
public final class SubjectLifter {
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    public init() {}

    /// Extracts foreground subjects as an RGBA transparent image
    /// - Parameters:
    ///   - image: Source UIImage
    ///   - cropToSubject: If true, crops the output bounds exactly to the subject's bounding box
    /// - Returns: Cutout UIImage with transparent background
    public func liftSubject(from image: UIImage, cropToSubject: Bool = true) throws -> UIImage {
        guard let ciInput = CIImage(image: image) else {
            throw SubjectLifterError.invalidSourceImage
        }

        // 1. Initialize iOS 17+ Vision instance mask request
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciInput, orientation: image.cgImageOrientation, options: [:])

        try handler.perform([request])

        // 2. Retrieve observation
        guard let result = request.results?.first else {
            throw SubjectLifterError.noForegroundSubjectDetected
        }

        // 3. Generate pixel buffer isolating all foreground instances
        // croppedToInstancesExtent handles tight bounding box crop like sticker creation
        let pixelBuffer = try result.generateMaskedImage(
            ofInstances: result.allInstances,
            from: handler,
            croppedToInstancesExtent: cropToSubject
        )

        let ciOutput = CIImage(cvPixelBuffer: pixelBuffer)

        // 4. Render to CGImage
        guard let cgImage = ciContext.createCGImage(ciOutput, from: ciOutput.extent) else {
            throw SubjectLifterError.maskGenerationFailed
        }

        return UIImage(cgImage: cgImage)
    }

    /// Generates high-resolution binary mask if custom shaders/stickers with borders are needed
    public func generateMask(from image: UIImage) throws -> CVPixelBuffer {
        guard let ciInput = CIImage(image: image) else {
            throw SubjectLifterError.invalidSourceImage
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciInput, orientation: image.cgImageOrientation, options: [:])

        try handler.perform([request])

        guard let result = request.results?.first else {
            throw SubjectLifterError.noForegroundSubjectDetected
        }

        return try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
    }
}

extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
