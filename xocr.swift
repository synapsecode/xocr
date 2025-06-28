import Foundation
import Vision
import AppKit

struct OCRWord {
    let text: String
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
}

func getLines(from elements: [OCRWord], lineThreshold: CGFloat = 0.015) -> [[OCRWord]] {
    var lines: [[OCRWord]] = []
    var currentLine: [OCRWord] = []
    var prevY: CGFloat?

    for word in elements {
        if let prev = prevY, abs(word.y - prev) >= lineThreshold {
            lines.append(currentLine)
            currentLine = [word]
        } else {
            currentLine.append(word)
        }
        prevY = word.y
    }

    if !currentLine.isEmpty {
        lines.append(currentLine)
    }

    return lines
}

func correctLines(_ lines: [[OCRWord]], minX: CGFloat) -> [String] {
    let GRANULARITY: CGFloat = 0.05
    let INDENT_LEVEL = 2
    let WORD_SPACING: CGFloat = 0.05
    var finalLines: [String] = []

    for line in lines {
        let sortedLine = line.sorted { $0.x < $1.x }
        guard let first = sortedLine.first else { continue }

        let relativeX = max(0, first.x - minX)
        let indentLevel = Int(relativeX / GRANULARITY)
        var lineStr = String(repeating: " ", count: indentLevel * INDENT_LEVEL)

        var lastEnd = first.x

        for (i, word) in sortedLine.enumerated() {
            if i == 0 {
                lineStr += word.text
            } else {
                let gap = word.x - lastEnd
                let numSpaces = max(1, Int(gap / WORD_SPACING))
                lineStr += String(repeating: " ", count: numSpaces) + word.text
            }
            lastEnd = word.x + word.width
        }

        finalLines.append(lineStr)
    }

    return finalLines
}

func extractCode(from imagePath: String) {
    let url = URL(fileURLWithPath: imagePath)
    guard let image = NSImage(contentsOf: url),
          let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        print("Failed to load image.")
        return
    }

    let request = VNRecognizeTextRequest { request, error in
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            print("No text found.")
            return
        }

        let words: [OCRWord] = observations.compactMap { observation in
            guard let topCandidate = observation.topCandidates(1).first else { return nil }

            let box = observation.boundingBox
            return OCRWord(
                text: topCandidate.string,
                x: box.origin.x,
                y: box.origin.y,
                width: box.size.width
            )
        }

        let sorted = words.sorted { $0.y > $1.y }
        guard let minX = sorted.map(\.x).min() else { return }

        let lines = getLines(from: sorted)
        let corrected = correctLines(lines, minX: minX)
        print(corrected.joined(separator: "\n"))
    }

    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: bitmap.cgImage!, options: [:])
    try? handler.perform([request])
}

// MARK: - Main
let args = CommandLine.arguments

guard args.count > 1 else {
    print("Input Image not found")
    exit(1)
}

extractCode(from: args[1])
