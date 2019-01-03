/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of iOS view controller that demonstrates histogram specification.
*/

import UIKit
import Accelerate.vImage

class ViewController: UIViewController {
    
    @IBOutlet var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sourceImage = #imageLiteral(resourceName: "Flowers_2.png")
        let histogramSourceImage = #imageLiteral(resourceName: "Rainbow_1.png")
        
        imageView.image = histogramSpecification(sourceImage: sourceImage,
                                                 histogramSourceImage: histogramSourceImage)
    }
    
    func histogramSpecification(sourceImage: UIImage, histogramSourceImage: UIImage) -> UIImage? {
        
        guard
            let sourceCGImage = sourceImage.cgImage,
            let histogramSourceCGImage = histogramSourceImage.cgImage else {
                return nil
        }
        
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: nil,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent)
        
        // Source image
        var error = kvImageNoError
        
        var sourceBuffer = vImage_Buffer()
        
        error = vImageBuffer_InitWithCGImage(&sourceBuffer,
                                             &format,
                                             nil,
                                             sourceCGImage,
                                             vImage_Flags(kvImageNoFlags))
        
        guard error == kvImageNoError else {
            print("Error initializing `sourceBuffer`")
            return nil
        }
        defer {
            free(sourceBuffer.data)
        }
        
        // Histogram source / Reference image
        var histogramSourceBuffer = vImage_Buffer()
        
        error = vImageBuffer_InitWithCGImage(&histogramSourceBuffer,
                                             &format,
                                             nil,
                                             histogramSourceCGImage,
                                             vImage_Flags(kvImageNoFlags))
        
        guard error == kvImageNoError else {
            print("Error initializing `histogramSourceBuffer`")
            return nil
        }
        defer {
            free(histogramSourceBuffer.data)
        }
        
        let histogramBins = (0...3).map { _ in
            return [vImagePixelCount](repeating: 0, count: 256)
        }
        
        var mutableHistogram: [UnsafeMutablePointer<vImagePixelCount>?] = histogramBins.map {
            return UnsafeMutablePointer<vImagePixelCount>(mutating: $0)
        }
        
        error = vImageHistogramCalculation_ARGB8888(&histogramSourceBuffer,
                                                    &mutableHistogram,
                                                    vImage_Flags(kvImageNoFlags))
        
        guard error == kvImageNoError else {
            print("Error calculating histogram")
            return nil
        }
        
        var immutableHistogram: [UnsafePointer<vImagePixelCount>?] = histogramBins.map {
            return UnsafePointer<vImagePixelCount>($0)
        }
        
        error = vImageHistogramSpecification_ARGB8888(&sourceBuffer,
                                                      &sourceBuffer,
                                                      &immutableHistogram,
                                                      vImage_Flags(kvImageLeaveAlphaUnchanged))
        
        guard error == kvImageNoError else {
            print("Error specifying histogram")
            return nil
        }
        let cgImage = vImageCreateCGImageFromBuffer(
            &sourceBuffer,
            &format,
            nil,
            nil,
            vImage_Flags(kvImageNoFlags),
            &error)
        
        if let cgImage = cgImage, error == kvImageNoError {
            return UIImage(cgImage: cgImage.takeRetainedValue())
        } else {
            return nil
        }
    }
}

