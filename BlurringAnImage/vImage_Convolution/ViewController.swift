/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of iOS view controller that demonstrates convolution.
*/

import UIKit
import Accelerate

let kernelLength = 51

class ViewController: UIViewController {
    
    let machToSeconds: Double = {
        var timebase: mach_timebase_info_data_t = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom) * 1e-9
    }()
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var toolbar: UIToolbar!
    
    var mode = ConvolutionModes.hann1D {
        didSet {
            applyBlur()
        }
    }
    
    enum ConvolutionModes: String, CaseIterable {
        case hann1D
        case hann2D
        case box
        case tent
        case multi
    }
    
    let cgImage: CGImage = {
        guard let cgImage = #imageLiteral(resourceName: "Landscape_4-2.jpg").cgImage else {
            fatalError("Unable to get CGImage")
        }
        
        return cgImage
    }()
    
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
    
    lazy var sourceBuffer: vImage_Buffer = {
        var sourceImageBuffer = vImage_Buffer()
        
        vImageBuffer_InitWithCGImage(&sourceImageBuffer,
                                     &format,
                                     nil,
                                     cgImage,
                                     vImage_Flags(kvImageNoFlags))
        
        var scaledBuffer = vImage_Buffer()
        
        vImageBuffer_Init(&scaledBuffer,
                          sourceImageBuffer.height / 4,
                          sourceImageBuffer.width / 4,
                          format.bitsPerPixel,
                          vImage_Flags(kvImageNoFlags))
        
        vImageScale_ARGB8888(&sourceImageBuffer,
                             &scaledBuffer,
                             nil,
                             vImage_Flags(kvImageNoFlags))
        
        return scaledBuffer
    }()

    let hannWindow: [Float] = {
        var hannFloat = [Float](repeating: 0,
                                count: kernelLength)
        
        vDSP_hann_window(&hannFloat,
                         vDSP_Length(kernelLength - 1),
                         Int32(vDSP_HANN_DENORM))
        
        return hannFloat
    }()
    
    lazy var kernel1D: [Int16] = {
        let stride = vDSP_Stride(1)
        var multiplier = pow(Float(Int16.max), 0.25)
        
        var hannWindow1D = [Float](repeating: 0,
                                   count: kernelLength)
        
        vDSP_vsmul(hannWindow, stride,
                   &multiplier,
                   &hannWindow1D, stride,
                   vDSP_Length(kernelLength))
        
        var hannInt = [Int16](repeating: 0,
                              count: kernelLength)
        
        vDSP_vfixr16(hannWindow1D, stride,
                     &hannInt, stride,
                     vDSP_Length(kernelLength))

        return hannInt
    }()
    
    lazy var kernel2D: [Int16] = {
        let stride = vDSP_Stride(1)

        var hannWindow2D = [Float](repeating: 0,
                                   count: kernelLength * kernelLength)
        
        cblas_sger(CblasRowMajor,
                   Int32(kernelLength), Int32(kernelLength),
                   1, kernel1D.map { return Float($0) },
                   1, kernel1D.map { return Float($0) },
                   1,
                   &hannWindow2D,
                   Int32(kernelLength))

        var hannInt = [Int16](repeating: 0,
                              count: kernelLength * kernelLength)
        
        vDSP_vfixr16(hannWindow2D, stride,
                     &hannInt, stride,
                     vDSP_Length(kernelLength * kernelLength))

        return hannInt
    }()

    var destinationBuffer = vImage_Buffer()
    
    func buildUI() {
        let segmentedControl = UISegmentedControl(items: ConvolutionModes.allCases.map { return $0.rawValue })
        
        segmentedControl.selectedSegmentIndex = ConvolutionModes.allCases.firstIndex(of: mode) ?? -1
        
        segmentedControl.addTarget(self,
                                   action: #selector(segmentedControlChangeHandler),
                                   for: .valueChanged)
        
        toolbar.setItems([UIBarButtonItem(customView: segmentedControl)],
                         animated: false)
    }
    
    @objc
    func segmentedControlChangeHandler(segmentedControl: UISegmentedControl) {
        if let title = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex),
            let newMode = ConvolutionModes(rawValue: title) {
            mode = newMode
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buildUI()
        
        applyBlur()
    }
    
    func applyBlur() {
        vImageBuffer_Init(&destinationBuffer,
                          sourceBuffer.height,
                          sourceBuffer.width,
                          format.bitsPerPixel,
                          vImage_Flags(kvImageNoFlags))
        
        switch mode {
            case .hann1D:
                hann1D()
            case .hann2D:
                hann2D()
            case .tent:
                tent()
            case .box:
                box()
            case.multi:
                multi()
        }
        
        let result = vImageCreateCGImageFromBuffer(
            &destinationBuffer,
            &format,
            nil,
            nil,
            vImage_Flags(kvImageNoFlags),
            nil)
        
        if let result = result {
            imageView.image = UIImage(cgImage: result.takeRetainedValue())
        }
        
        free(destinationBuffer.data)
    }
}
