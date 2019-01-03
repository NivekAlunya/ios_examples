/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of iOS view controller that demonstrates matrix multiplication.
*/

import UIKit
import Accelerate

class ViewController: UIViewController {
    
    @IBOutlet var imageView: UIImageView!
    
    /*
     The Core Graphics image representation of the source asset.
     */
    let cgImage: CGImage = {
        guard let cgImage = #imageLiteral(resourceName: "Food_4.JPG").cgImage else {
            fatalError("Unable to get CGImage")
        }
        
        return cgImage
    }()
    
    /*
     The format of the source asset.
     */
    lazy var format: vImage_CGImageFormat = {
        guard
            let sourceColorSpace = cgImage.colorSpace else {
                fatalError("Unable to get color space")
        }
        
        return vImage_CGImageFormat(
            bitsPerComponent: UInt32(cgImage.bitsPerComponent),
            bitsPerPixel: UInt32(cgImage.bitsPerPixel),
            colorSpace: Unmanaged.passRetained(sourceColorSpace),
            bitmapInfo: cgImage.bitmapInfo,
            version: 0,
            decode: nil,
            renderingIntent: cgImage.renderingIntent)
    }()
    
    /*
     The vImage buffer containing a scaled down copy of the source asset.
     */
    lazy var sourceBuffer: vImage_Buffer = {
        var sourceImageBuffer = vImage_Buffer()
        
        vImageBuffer_InitWithCGImage(&sourceImageBuffer,
                                     &format,
                                     nil,
                                     cgImage,
                                     vImage_Flags(kvImageNoFlags))
        
        var scaledBuffer = vImage_Buffer()
        
        vImageBuffer_Init(&scaledBuffer,
                          sourceImageBuffer.height / 3,
                          sourceImageBuffer.width / 3,
                          format.bitsPerPixel,
                          vImage_Flags(kvImageNoFlags))
        
        vImageScale_ARGB8888(&sourceImageBuffer,
                             &scaledBuffer,
                             nil,
                             vImage_Flags(kvImageNoFlags))
        
        return scaledBuffer
    }()
    
    /*
     The 1-channel, 8-bit vImage buffer used as the operation destination.
     */
    lazy var destinationBuffer: vImage_Buffer = {
        var destinationBuffer = vImage_Buffer()
        
        vImageBuffer_Init(&destinationBuffer,
                          sourceBuffer.height,
                          sourceBuffer.width,
                          8,
                          vImage_Flags(kvImageNoFlags))
        
        return destinationBuffer
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Declare the three coefficients that model the eye's sensitivity
        // to color.
        let redCoefficient: Float = 0.2126
        let greenCoefficient: Float = 0.7152
        let blueCoefficient: Float = 0.0722
        
        // Create a 1D matrix containing the three luma coefficients that
        // specify the color-to-grayscale conversion.
        let divisor: Int32 = 0x1000
        let fDivisor = Float(divisor)
        
        var coefficientsMatrix = [
            Int16(redCoefficient * fDivisor),
            Int16(greenCoefficient * fDivisor),
            Int16(blueCoefficient * fDivisor)
        ]
        
        // Use the matrix of coefficients to compute the scalar luminance by
        // returning the dot product of each RGB pixel and the coefficients
        // matrix.
        var preBias: Int16 = 0
        let postBias: Int32 = 0
        
        vImageMatrixMultiply_ARGB8888ToPlanar8(&sourceBuffer,
                                               &destinationBuffer,
                                               &coefficientsMatrix,
                                               divisor,
                                               &preBias,
                                               postBias,
                                               vImage_Flags(kvImageNoFlags))
        
        // Create a 1-channel, 8-bit grayscale format that's used to
        // generate a displayable image.
        var monoFormat = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            colorSpace: Unmanaged.passRetained(CGColorSpaceCreateDeviceGray()),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent)
        
        // Create a Core Graphics image from the grayscale destination buffer.
        let result = vImageCreateCGImageFromBuffer(
            &destinationBuffer,
            &monoFormat,
            nil,
            nil,
            vImage_Flags(kvImageNoFlags),
            nil)
        
        // Display the grayscale result.
        if let result = result {
            imageView.image = UIImage(cgImage: result.takeRetainedValue())
        }
    }
}
