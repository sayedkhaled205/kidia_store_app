// Local macOS Vision inspection; no external OCR service is used.
import Foundation
import ImageIO
import Vision

do {
    guard CommandLine.arguments.count == 3 else {
        throw NSError(domain: "SimulatorScreen", code: 1)
    }
    let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
    guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "SimulatorScreen", code: 2)
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["en-US"]
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    let result = try JSONSerialization.data(withJSONObject: ["lines": lines], options: [.prettyPrinted])
    try result.write(to: outputURL, options: .atomic)
} catch {
    FileHandle.standardError.write(Data("Simulator screen recognition failed.\n".utf8))
    exit(1)
}
