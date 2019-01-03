/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of iOS view controller that demonstrates applying effects to a video feed with vImage.
*/

import UIKit
import AVFoundation
import Accelerate.vImage

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    enum DemoMode: String {
        case saturation = "Saturation"
        case rotation = "Rotation"
        case blur = "Blurring"
        case dither = "Dither"
        case lookupTable = "Lookup Table"
    }

    var mode: DemoMode = .saturation {
        didSet {
            guard let fxSlider = fxSliderItem.customView as? UISlider else {
                return
            }

            UIView.animate(withDuration: 0.3) {
                self.topToolbar.alpha = 1
            }

            switch mode {
            case .saturation:
                fxSlider.minimumValue = 0
                fxSlider.maximumValue = 5
                fxSlider.value = 1
                fxValue = 1
            case .rotation:
                fxSlider.minimumValue = -.pi
                fxSlider.maximumValue = .pi
                fxSlider.value = 0
                fxValue = 0
            case .blur:
                fxSlider.minimumValue = 0
                fxSlider.maximumValue = 75
                fxSlider.value = 0
                fxValue = 0
            case .dither:
                UIView.animate(withDuration: 0.3) {
                    self.topToolbar.alpha = 0
                }
            case .lookupTable:
                fxSlider.minimumValue = 1
                fxSlider.maximumValue = 150
                fxSlider.value = 1
                fxValue = 1

            }
        }
    }

    let modeSegmentedControlItem: UIBarButtonItem = {
        let segmentedControl = UISegmentedControl(items: [DemoMode.saturation.rawValue,
                                                          DemoMode.rotation.rawValue,
                                                          DemoMode.blur.rawValue,
                                                          DemoMode.dither.rawValue,
                                                          DemoMode.lookupTable.rawValue])

        segmentedControl.selectedSegmentIndex = 0

        segmentedControl.addTarget(self,
                                   action: #selector(modeSegmentedControlChangeHandler),
                                   for: .valueChanged)

        return UIBarButtonItem(customView: segmentedControl)
    }()

    let fxSliderItem: UIBarButtonItem = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 5
        slider.value = 1
        slider.addTarget(self,
                         action: #selector(fxSliderHandler),
                         for: .valueChanged)

        return UIBarButtonItem(customView: slider)
    }()

    let cameraToggleItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.camera,
                                           target: self,
                                           action: #selector(toggleCamera))

    var cgImageFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                             bitsPerPixel: 32,
                                             colorSpace: nil,
                                             bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue),
                                             version: 0,
                                             decode: nil,
                                             renderingIntent: .defaultIntent)

    var destinationBuffer = vImage_Buffer()

    private let dataOutputQueue = DispatchQueue(label: "video data queue",
                                                qos: .userInitiated,
                                                attributes: [],
                                                autoreleaseFrequency: .workItem)

    let captureSession = AVCaptureSession()

    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var bottomToolbar: UIToolbar!
    @IBOutlet weak var topToolbar: UIToolbar!

    var fxValue: Float = 1

    @objc
    func toggleCamera() {
        useFront = !useFront
        configureSession()
    }

    @objc
    func modeSegmentedControlChangeHandler(segmentedControl: UISegmentedControl) {
        guard
            let newModeName = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex),
            let newMode = DemoMode(rawValue: newModeName) else {
                return
        }

        mode = newMode
    }

    @objc
    func fxSliderHandler(slider: UISlider) {
        fxValue = slider.value
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard configureYpCbCrToARGBInfo() == kvImageNoError else {
            return
        }

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                     target: nil,
                                     action: nil)

        bottomToolbar.setItems([modeSegmentedControlItem,
                                flexibleSpace,
                                cameraToggleItem],
                               animated: false)

        topToolbar.setItems([fxSliderItem],
                            animated: false)

        configureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        captureSession.startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        captureSession.stopRunning()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .bottom
    }

    deinit {
        free(destinationBuffer.data)
    }

    var infoYpCbCrToARGB = vImage_YpCbCrToARGB()

    func configureYpCbCrToARGBInfo() -> vImage_Error {
        var pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 16,
                                                 CbCr_bias: 128,
                                                 YpRangeMax: 235,
                                                 CbCrRangeMax: 240,
                                                 YpMax: 235,
                                                 YpMin: 16,
                                                 CbCrMax: 240,
                                                 CbCrMin: 16)

        let error = vImageConvert_YpCbCrToARGB_GenerateConversion(
            kvImage_YpCbCrToARGBMatrix_ITU_R_601_4!,
            &pixelRange,
            &infoYpCbCrToARGB,
            kvImage422CbYpCrYp8,
            kvImageARGB8888,
            vImage_Flags(kvImageNoFlags))

        return error
    }

    var useFront = true

    let backCameras = AVCaptureDevice.DiscoverySession(
        deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
        mediaType: AVMediaType.video,
        position: AVCaptureDevice.Position.back).devices

    let frontCameras = AVCaptureDevice.DiscoverySession(
        deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
        mediaType: AVMediaType.video,
        position: AVCaptureDevice.Position.front).devices

    func configureSession() {
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }

        captureSession.sessionPreset = AVCaptureSession.Preset.photo

        guard let camera = useFront ? frontCameras.first : backCameras.first else {
            print("No camera")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)

            captureSession.addInput(input)
        } catch {
            print("can't access camera")
            return
        }

        if captureSession.outputs.isEmpty {
            let videoOutput = AVCaptureVideoDataOutput()

            videoOutput.setSampleBufferDelegate(self,
                                                queue: dataOutputQueue)

            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)

                captureSession.startRunning()
            }
        }

    }

    // AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        if
            let videoOutput = captureSession.outputs.first,
            let videoOrientation = videoOutput.connection(with: .video)?.videoOrientation {
            if (videoOrientation == .landscapeRight && UIDevice.current.orientation == .landscapeRight) ||
                (videoOrientation == .landscapeLeft && UIDevice.current.orientation == .landscapeLeft),
                (videoOutput.connection(with: .video)?.isVideoOrientationSupported) ?? false {
                videoOutput.connection(with: .video)?.videoOrientation = videoOrientation == .landscapeRight ?
                    .landscapeLeft :
                    .landscapeRight
            }
        }

        CVPixelBufferLockBaseAddress(pixelBuffer,
                                     .readOnly)

        displayYpCbCrToRGB(pixelBuffer: pixelBuffer)

        CVPixelBufferUnlockBaseAddress(pixelBuffer,
                                       .readOnly)
    }

    func displayYpCbCrToRGB(pixelBuffer: CVPixelBuffer) {
        assert(CVPixelBufferGetPlaneCount(pixelBuffer) == 2, "Pixel buffer should have 2 planes")

        let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        let lumaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let lumaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let lumaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

        var sourceLumaBuffer = vImage_Buffer(data: lumaBaseAddress,
                                             height: vImagePixelCount(lumaHeight),
                                             width: vImagePixelCount(lumaWidth),
                                             rowBytes: lumaRowBytes)

        let chromaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
        let chromaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let chromaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        let chromaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

        var sourceChromaBuffer = vImage_Buffer(data: chromaBaseAddress,
                                               height: vImagePixelCount(chromaHeight),
                                               width: vImagePixelCount(chromaWidth * 2),
                                               rowBytes: chromaRowBytes)

        var error = kvImageNoError
        if destinationBuffer.data == nil {
            error = vImageBuffer_Init(&destinationBuffer,
                                      sourceLumaBuffer.height,
                                      sourceLumaBuffer.width,
                                      cgImageFormat.bitsPerPixel,
                                      vImage_Flags(kvImageNoFlags))

            guard error == kvImageNoError else {
                return
            }
        }

        switch mode {
        case .saturation, .dither:
            let chromaBufferPointer = withUnsafePointer(to: &sourceChromaBuffer) {
                return $0
            }

            var sources: UnsafePointer<vImage_Buffer>? = chromaBufferPointer
            var destinations: UnsafePointer<vImage_Buffer>? = chromaBufferPointer

            var preBias: Int16 = -128
            let divisor: Int32 = 0x1000
            var postBias: Int32 = 128 * divisor

            let saturation = mode == .dither ? 0 : fxValue

            var matrix = [ Int16(saturation * Float(divisor)) ]

            vImageMatrixMultiply_Planar8(&sources,
                                         &destinations,
                                         1,
                                         1,
                                         &matrix,
                                         divisor,
                                         &preBias,
                                         &postBias,
                                         vImage_Flags(kvImageNoFlags))

            if mode == .dither {
                var ditheredLuma = vImage_Buffer()
                vImageBuffer_Init(&ditheredLuma,
                                  sourceLumaBuffer.height,
                                  sourceLumaBuffer.width,
                                  1,
                                  vImage_Flags(kvImageNoFlags))

                vImageConvert_Planar8toPlanar1(&sourceLumaBuffer,
                                               &ditheredLuma,
                                               nil,
                                               Int32(kvImageConvert_DitherAtkinson),
                                               vImage_Flags(kvImageNoFlags))


                vImageConvert_Planar1toPlanar8(&ditheredLuma,
                                               &sourceLumaBuffer,
                                               vImage_Flags(kvImageNoFlags))

                free(ditheredLuma.data)
            }
        default:
            break
        }

        guard error == kvImageNoError else {
            print("vImageMatrixMultiply_Planar8 error", error)
            return
        }

        error = vImageConvert_420Yp8_CbCr8ToARGB8888(&sourceLumaBuffer,
                                                     &sourceChromaBuffer,
                                                     &destinationBuffer,
                                                     &infoYpCbCrToARGB,
                                                     nil,
                                                     255,
                                                     vImage_Flags(kvImagePrintDiagnosticsToConsole))

        guard error == kvImageNoError else {
            return
        }

        switch mode {
        case .rotation:
            let backcolor: [UInt8] = [255, 255, 255, 255]
            vImageRotate_ARGB8888(&destinationBuffer,
                                  &destinationBuffer,
                                  nil,
                                  fxValue,
                                  backcolor,
                                  vImage_Flags(kvImageBackgroundColorFill))
        case .blur:
            let kernelSize = UInt32(fxValue) | 1

            var tmpBuffer = vImage_Buffer()
            vImageBuffer_Init(&tmpBuffer,
                              destinationBuffer.height,
                              destinationBuffer.width,
                              cgImageFormat.bitsPerPixel,
                              vImage_Flags(kvImageNoFlags))

            vImageCopyBuffer(&destinationBuffer,
                             &tmpBuffer,
                             4,
                             vImage_Flags(kvImageNoFlags))

            vImageTentConvolve_ARGB8888(&tmpBuffer,
                                        &destinationBuffer,
                                        nil,
                                        0,
                                        0,
                                        kernelSize,
                                        kernelSize,
                                        nil,
                                        vImage_Flags(kvImageEdgeExtend))

            free(tmpBuffer.data)
        case .lookupTable:
            let quantizationLevel = Int(fxValue)
            var lookUpTable = (0...255).map {
                return Pixel_8(($0 / quantizationLevel) * quantizationLevel)
            }
            vImageTableLookUp_ARGB8888(&destinationBuffer,
                                       &destinationBuffer,
                                       nil,
                                       &lookUpTable,
                                       &lookUpTable,
                                       &lookUpTable,
                                       vImage_Flags(kvImageNoFlags))
        default:
            break
        }

        let cgImage = vImageCreateCGImageFromBuffer(&destinationBuffer,
                                                    &cgImageFormat,
                                                    nil,
                                                    nil,
                                                    vImage_Flags(kvImageNoFlags),
                                                    &error)

        if let cgImage = cgImage, error == kvImageNoError {
            DispatchQueue.main.async {
                self.imageView.image = UIImage(cgImage: cgImage.takeRetainedValue())
            }
        }
    }
}
