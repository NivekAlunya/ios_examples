/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of iOS view controller that demonstrates piecewise gamma correction.
*/

import UIKit
import Accelerate

class ViewController: UIViewController {
    
    let presets = [
        ResponseCurvePreset(label: "L1",
                            boundary: 255,
                            linearCoefficients: [1, 0],
                            gamma: 0),
        ResponseCurvePreset(label: "L2",
                            boundary: 255,
                            linearCoefficients: [0.5, 0.5],
                            gamma: 0),
        ResponseCurvePreset(label: "L3",
                            boundary: 255,
                            linearCoefficients: [3, -1],
                            gamma: 0),
        ResponseCurvePreset(label: "L4",
                            boundary: 255,
                            linearCoefficients: [-1, 1],
                            gamma: 0),
        ResponseCurvePreset(label: "E1",
                            boundary: 0,
                            linearCoefficients: [1, 0],
                            gamma: 1),
        ResponseCurvePreset(label: "E2",
                            boundary: 0,
                            linearCoefficients: [1, 0],
                            gamma: 2.2),
        ResponseCurvePreset(label: "E3",
                            boundary: 0,
                            linearCoefficients: [1, 0],
                            gamma: 1 / 2.2)
    ]
    
    var presetIndex = 0
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var toolbar: UIToolbar!
    
    let cgImage: CGImage = {
        guard let cgImage = #imageLiteral(resourceName: "Food_4.JPG").cgImage else {
            fatalError("Unable to get CGImage")
        }
        
        return cgImage
    }()
    
    /*
     The format of the source asset.
     */
    lazy var sourceFormat: vImage_CGImageFormat = {
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
     The buffer containing the source image.
     */
    lazy var sourceBuffer: vImage_Buffer = {
        var sourceImageBuffer = vImage_Buffer()
        
        vImageBuffer_InitWithCGImage(&sourceImageBuffer,
                                     &sourceFormat,
                                     nil,
                                     cgImage,
                                     vImage_Flags(kvImageNoFlags))
        
        var scaledBuffer = vImage_Buffer()
        
        vImageBuffer_Init(&scaledBuffer,
                          sourceImageBuffer.height / 3,
                          sourceImageBuffer.width / 3,
                          sourceFormat.bitsPerPixel,
                          vImage_Flags(kvImageNoFlags))
        
        vImageScale_ARGB8888(&sourceImageBuffer,
                             &scaledBuffer,
                             nil,
                             vImage_Flags(kvImageNoFlags))
        
        return scaledBuffer
    }()
    
    /*
     The 3-channel RGB format of the destination image.
     */
    lazy var rgbFormat: vImage_CGImageFormat = {
        return vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 8 * 3,
            colorSpace: Unmanaged.passRetained(CGColorSpaceCreateDeviceRGB()),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent)
    }()
    
    /*
     The buffer containing the image after gamma adjustment.
     */
    lazy var destinationBuffer: vImage_Buffer = {
        var destinationBuffer = vImage_Buffer()
        
        vImageBuffer_Init(&destinationBuffer,
                          sourceBuffer.height,
                          sourceBuffer.width,
                          rgbFormat.bitsPerPixel,
                          vImage_Flags(kvImageNoFlags))
        
        return destinationBuffer
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        buildUI()
        
        if let result = getGammaCorrectedImage(preset: presets[presetIndex]) {
            self.imageView.image = result
        }
    }
    
    /*
     Method to build and populate a segmented control with the presets, add that segmented control to the UI, and add a target to handle segmented control changes.
     */
    func buildUI() {
        let segmentedControl = UISegmentedControl(items: presets.map { return $0.label })
        
        segmentedControl.selectedSegmentIndex = presetIndex
        
        segmentedControl.addTarget(self,
                                   action: #selector(segmentedControlChangeHandler),
                                   for: .valueChanged)
        
        toolbar.setItems([UIBarButtonItem(customView: segmentedControl)],
                         animated: false)
    }
    
    /*
     When the user changes the selected segment, display the result in `imageView`.
     */
    @objc
    func segmentedControlChangeHandler(segmentedControl: UISegmentedControl) {
        if let result = getGammaCorrectedImage(preset: presets[segmentedControl.selectedSegmentIndex]) {
            self.imageView.image = result
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func getGammaCorrectedImage(preset: ResponseCurvePreset) -> UIImage? {
        /*
         Declare the adjustment coefficents based on the currently selected preset.
         */
        let boundary: Pixel_8 = preset.boundary
        
        let linearCoefficients: [Float] = preset.linearCoefficients
        
        let exponentialCoefficients: [Float] = [1, 0, 0]
        let gamma: Float = preset.gamma
      
        vImageConvert_RGBA8888toRGB888(&sourceBuffer,
                                       &destinationBuffer,
                                       vImage_Flags(kvImageNoFlags))
        
        /*
         Create a planar representation of the interleaved destination buffer. Becuase `destinationBuffer` is 3-channel, assign the planar destinationBuffer a width of 3x the interleaved width.
         */
        var planarDestination = vImage_Buffer(data: destinationBuffer.data,
                                              height: destinationBuffer.height,
                                              width: destinationBuffer.width * 3,
                                              rowBytes: destinationBuffer.rowBytes)
        
        
        /*
         Perform the adjustment.
         */
        vImagePiecewiseGamma_Planar8(&planarDestination,
                                     &planarDestination,
                                     exponentialCoefficients,
                                     gamma,
                                     linearCoefficients,
                                     boundary,
                                     vImage_Flags(kvImageNoFlags))
        
        /*
         Create a 3-channel `CGImage` instance from the interleaved buffer.
         */
        let result = vImageCreateCGImageFromBuffer(
            &destinationBuffer,
            &rgbFormat,
            nil,
            nil,
            vImage_Flags(kvImageNoFlags),
            nil)
        
        if let result = result {
            return UIImage(cgImage: result.takeRetainedValue())
        } else {
            return nil
        }
    }
    
    /*
     A structure that wraps piecewise gamma parameters.
     */
    struct ResponseCurvePreset {
        let label: String
        let boundary: Pixel_8
        let linearCoefficients: [Float]
        let gamma: Float
    }
}
