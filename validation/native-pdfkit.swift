import AppKit
import CryptoKit
import PDFKit

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let images = root.appendingPathComponent("pdfkit-images", isDirectory: true)
try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)

func render(_ url: URL) throws -> [String] {
    guard let document = PDFDocument(url: url), document.pageCount > 0 else {
        fatalError("Cannot read PDF: \(url.path)")
    }
    return try (0..<document.pageCount).map { index in
        try autoreleasepool {
            guard let page = document.page(at: index) else { fatalError("Missing page") }
            let bounds = page.bounds(for: .mediaBox)
            let width = Int(ceil(bounds.width * 2)), height = Int(ceil(bounds.height * 2))
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            return try bytes.withUnsafeMutableBytes { buffer in
                guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                    fatalError("Cannot allocate bitmap")
                }
                context.setFillColor(CGColor(gray: 1, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
                context.scaleBy(x: 2, y: 2)
                context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
                page.draw(with: .mediaBox, to: context)
                guard let image = context.makeImage(),
                    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    fatalError("Cannot encode PNG")
                }
                let filename = url.deletingPathExtension().lastPathComponent + "-\(index + 1).png"
                try png.write(to: images.appendingPathComponent(filename))
                let digest = SHA256.hash(data: Data(buffer)).map { String(format: "%02x", $0) }.joined()
                return "\(width)x\(height):\(digest)"
            }
        }
    }
}

let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.hasSuffix("-uncached.pdf") }.sorted { $0.path < $1.path }
guard files.count == 10 else { fatalError("Expected ten PDF pairs, found \(files.count)") }
var results = [[String: Any]]()
for baseline in files {
    let candidate = root.appendingPathComponent(baseline.lastPathComponent.replacingOccurrences(of: "-uncached.pdf", with: "-cached.pdf"))
    let lhs = try render(baseline), rhs = try render(candidate)
    guard lhs == rhs else { fatalError("PDFKit rendering changed: \(baseline.lastPathComponent)") }
    results.append(["fixture": baseline.lastPathComponent, "pages": lhs.count, "pixelHashes": lhs, "identical": true])
    print("PDFKit identical: \(baseline.lastPathComponent), \(lhs.count) pages")
}
let report: [String: Any] = ["os": ProcessInfo.processInfo.operatingSystemVersionString,
    "renderer": "Apple PDFKit PDFPage.draw", "dpi": 144, "results": results,
    "previewUI": "not tested", "historic7657Source": "unavailable"]
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appendingPathComponent("apple-pdfkit-results.json"))
