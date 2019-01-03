# Specifying Histograms with vImage

Calculate the histogram of one image and apply it to a second image.

## Overview

_Histogram specification_ is a technique that allows you to calculate the histogram of a reference image and apply it to an input image. This sample walks you through the steps to implement histogram specification in vImage:

1. Creating vImage buffers that represent the reference image and input image.
2. Calculating the histogram of the reference image.
3. Specifying the histogram of the input image as the reference image’s histogram.

The example below shows an input image (top left) and a histogram reference image (bottom left), with the result on the right:

![Photos showing original image, histogram source image, and histogram specified result.](Documentation/HistogramSpecification_2x.png)

## Create the vImage Buffers

To learn about creating a Core Graphics image format that describes your input and reference images, see [Creating a Core Graphics Image Format](https://developer.apple.com/documentation/accelerate/vimage/creating_a_core_graphics_image_format). In this example, `format` describes an 8-bit-per-channel ARGB image.

The following code shows how to create a vImage buffer initialized with the input image (the flower in the above image).

``` swift
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
```

The following code shows how to create a vImage buffer initialized with the histogram reference image (the rainbow in the above image).

``` swift
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
```

## Calculate the Reference Image Histogram

The histogram data is stored in four arrays—one for each channel—where the value of each element is the number of pixels in the reference image with that color value. In an 8-bit-per-channel image, each color channel can hold 256 different values, so each array is defined with a count of 256.

``` swift
let histogramBins = (0...3).map { _ in
    return [vImagePixelCount](repeating: 0, count: 256)
}
```

To populate the histogram arrays with the calculated histogram data, prepare an array of `UnsafeMutablePointer<vImagePixelCount>` from the arrays, and pass it to `vImageHistogramCalculation_ARGB8888`.

``` swift
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
```

After `vImageHistogramCalculation_ARGB8888` returns, the four arrays are now populated with the histogram data from the image that `histogramSourceBuffer` points to.

## Specify the Input Image Histogram

The `vImageHistogramSpecification_ARGB8888` function accepts a different parameter to receive the histogram data: an array of `UnsafePointer<vImagePixelCount>`. The following code prepares the four arrays for use in the specification function.

``` swift
var immutableHistogram: [UnsafePointer<vImagePixelCount>?] = histogramBins.map {
    return UnsafePointer<vImagePixelCount>($0)
}
```

Because `vImageHistogramSpecification_ARGB8888` can work in place, you can pass the source buffer as both the source and destination:

``` swift
error = vImageHistogramSpecification_ARGB8888(&sourceBuffer,
                                              &sourceBuffer,
                                              &immutableHistogram,
                                              vImage_Flags(kvImageLeaveAlphaUnchanged))

guard error == kvImageNoError else {
    print("Error specifying histogram")
    return nil
}
```

After `vImageHistogramSpecification_ARGB8888` returns, `sourceBuffer` contains the original input image with the histogram specified by the reference image.
