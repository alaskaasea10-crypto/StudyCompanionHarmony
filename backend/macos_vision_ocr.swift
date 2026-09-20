import AppKit
import Foundation
import Vision

struct Line: Codable {
  let text: String
  let x: Double
  let y: Double
  let width: Double
  let height: Double
}

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write(Data("missing image path\n".utf8))
  exit(2)
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let image = NSImage(contentsOf: url),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
  FileHandle.standardError.write(Data("cannot read image\n".utf8))
  exit(3)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
request.recognitionLanguages = ["zh-Hans", "en-US"]

do {
  try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
  let observations = request.results ?? []
  let lines = observations.compactMap { observation -> Line? in
    guard let candidate = observation.topCandidates(1).first else { return nil }
    let box = observation.boundingBox
    return Line(
      text: candidate.string,
      x: box.origin.x,
      y: 1.0 - box.origin.y - box.height,
      width: box.width,
      height: box.height
    )
  }.sorted {
    abs($0.y - $1.y) < 0.015 ? $0.x < $1.x : $0.y < $1.y
  }
  let data = try JSONEncoder().encode(lines)
  FileHandle.standardOutput.write(data)
} catch {
  FileHandle.standardError.write(Data("vision error: \(error)\n".utf8))
  exit(4)
}
