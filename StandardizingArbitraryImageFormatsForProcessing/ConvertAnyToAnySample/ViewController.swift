/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of iOS view controller that demonstrates applying vImage's convert-any-to-any funciton.
*/

import UIKit
import Accelerate.vImage

class ViewController: UIViewController {
    
    @IBOutlet var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let flowers = #imageLiteral(resourceName: "Flowers_2.jpg")
        
        imageView.image = blurImage(flowers,
                                    blurWidth: 48,
                                    blurHeight: 48)
    }
}

func blurImage(_ sourceImage: UIImage,
               blurWidth: UInt32,
               blurHeight: UInt32) -> UIImage? {
    
    guard
        let cgImage = sourceImage.cgImage,
        let sourceColorSpace = cgImage.colorSpace else {
            print("unable to initialize cgImage or colorSpace.")
            return nil
    }
    
    var sourceImageFormat = vImage_CGImageFormat(
        bitsPerComponent: UInt32(cgImage.bitsPerComponent),
        bitsPerPixel: UInt32(cgImage.bitsPerPixel),
        colorSpace: Unmanaged.passRetained(sourceColorSpace),
        bitmapInfo: cgImage.bitmapInfo,
        version: 0,
        decode: nil,
        renderingIntent: cgImage.renderingIntent)
    
    var rgbDestinationImageFormat = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        colorSpace: nil,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent)
    
    var sourceBuffer = vImage_Buffer()
    var error = kvImageNoError
    
    error = vImageBuffer_InitWithCGImage(&sourceBuffer,
                                         &sourceImageFormat,
                                         nil,
                                         cgImage,
                                         vImage_Flags(kvImageNoFlags))
    
    guard error == kvImageNoError else {
        print("error in vImageBuffer_InitWithCGImage")
        return nil
    }
    
    defer {
        free(sourceBuffer.data)
    }
    
    var rgbDestinationBuffer = vImage_Buffer()
    
    error = vImageBuffer_Init(&rgbDestinationBuffer,
                              sourceBuffer.height,
                              sourceBuffer.width,
                              rgbDestinationImageFormat.bitsPerPixel,
                              vImage_Flags(kvImageNoFlags))
    
    guard error == kvImageNoError else {
        print("error in vImageBuffer_Init")
        return nil
    }
    
    defer {
        free(rgbDestinationBuffer.data)
    }
    
    guard let toRgbConverter = vImageConverter_CreateWithCGImageFormat(
        &sourceImageFormat,
        &rgbDestinationImageFormat,
        nil,
        vImage_Flags(kvImagePrintDiagnosticsToConsole),
        nil)?.takeRetainedValue() else {
            print("error in vImageConverter_CreateWithCGImageFormat")
            return nil
            
    }
    
    error = vImageConvert_AnyToAny(
        toRgbConverter,
        &sourceBuffer,
        &rgbDestinationBuffer,
        nil,
        vImage_Flags(kvImagePrintDiagnosticsToConsole))
    
    guard error == kvImageNoError else {
        print("error in vImageConvert_AnyToAny")
        return nil
    }
    
    
    var blurResultBuffer = vImage_Buffer()
    error = vImageBuffer_Init(&blurResultBuffer,
                              sourceBuffer.height,
                              sourceBuffer.width,
                              rgbDestinationImageFormat.bitsPerPixel,
                              vImage_Flags(kvImageNoFlags))
    
    guard error == kvImageNoError else {
        print("error in blurResultBuffer vImageBuffer_Init")
        return nil
    }
    
    defer {
        free(blurResultBuffer.data)
    }
    
    let oddWidth = blurWidth % 2 == 0 ? blurWidth + 1 : blurWidth
    let oddHeight = blurHeight % 2 == 0 ? blurHeight + 1 : blurHeight
    
    error = vImageTentConvolve_ARGB8888(&rgbDestinationBuffer,
                                        &blurResultBuffer,
                                        nil,
                                        0, 0,
                                        oddHeight, oddWidth,
                                        nil,
                                        vImage_Flags(kvImageEdgeExtend))
    
    guard error == kvImageNoError else {
        print("error in vImageTentConvolve_ARGB8888")
        return nil
    }
    
    if let cgImage = vImageCreateCGImageFromBuffer(&blurResultBuffer,
                                                   &rgbDestinationImageFormat,
                                                   nil,
                                                   nil,
                                                   vImage_Flags(kvImageNoFlags),
                                                   nil) {
        return UIImage(cgImage: cgImage.takeRetainedValue())
    } else {
        return nil
    }
}

