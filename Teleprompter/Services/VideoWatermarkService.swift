import AVFoundation
import CoreImage
import UIKit

enum VideoWatermarkService {
    static func export(sourceURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVURLAsset(url: sourceURL)

        Task {
            do {
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    throw RecordingError.cannotCreateComposition
                }

                let naturalSize = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
                let renderSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))

                let videoComposition = AVMutableVideoComposition(asset: asset) { request in
                    let overlay = watermarkOverlay(renderSize: renderSize)
                    let source = request.sourceImage.clampedToExtent()
                    let composited = overlay.composited(over: source).cropped(to: request.sourceImage.extent)
                    request.finish(with: composited, context: nil)
                }
                videoComposition.renderSize = renderSize

                guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                    throw RecordingError.cannotCreateExporter
                }
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("teleprompter-watermarked-\(UUID().uuidString).mov")
                exporter.outputURL = outputURL
                exporter.outputFileType = .mov
                exporter.videoComposition = videoComposition
                exporter.shouldOptimizeForNetworkUse = true

                await exporter.export()

                DispatchQueue.main.async {
                    switch exporter.status {
                    case .completed:
                        completion(.success(outputURL))
                    case .failed, .cancelled:
                        completion(.failure(exporter.error ?? RecordingError.exportFailed))
                    default:
                        completion(.failure(RecordingError.exportFailed))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private static func watermarkOverlay(renderSize: CGSize) -> CIImage {
        let text = "Teleprompter"
        let fontSize = max(20, renderSize.height * 0.032)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.82)
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        let padding: CGFloat = fontSize * 0.6
        let badgeSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding)
        let margin: CGFloat = renderSize.height * 0.035

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let image = renderer.image { _ in
            let badgeOrigin = CGPoint(
                x: renderSize.width - badgeSize.width - margin,
                y: renderSize.height - badgeSize.height - margin
            )
            let badgeRect = CGRect(origin: badgeOrigin, size: badgeSize)
            let path = UIBezierPath(roundedRect: badgeRect, cornerRadius: badgeSize.height / 2)
            UIColor.black.withAlphaComponent(0.36).setFill()
            path.fill()

            let textOrigin = CGPoint(
                x: badgeRect.minX + padding,
                y: badgeRect.minY + (badgeSize.height - textSize.height) / 2
            )
            attributedString.draw(at: textOrigin)
        }

        guard let cgImage = image.cgImage else { return CIImage.empty() }
        return CIImage(cgImage: cgImage)
    }
}
