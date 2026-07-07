import UIKit
import CoreImage

struct QREndpointInfo: Codable, Sendable, Equatable {
    let name: String
    let host: String
    let port: UInt16
    let service: String
}

struct QRCodeGenerator {
    func generate(from info: QREndpointInfo, size: CGSize = CGSize(width: 256, height: 256)) -> UIImage? {
        guard let jsonData = try? JSONEncoder().encode(info),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(jsonString.utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let scaleX = size.width / outputImage.extent.width
        let scaleY = size.height / outputImage.extent.height
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        return UIImage(ciImage: transformed)
    }
}
