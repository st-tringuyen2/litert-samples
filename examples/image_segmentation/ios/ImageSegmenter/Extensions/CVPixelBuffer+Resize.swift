import Foundation
import Accelerate
import CoreImage

extension CVPixelBuffer {
    public func convertToSquare(squareSize: Int) -> CVPixelBuffer? {
        guard squareSize > 0 else { return nil }
        let srcWidth = CVPixelBufferGetWidth(self)
        let srcHeight = CVPixelBufferGetHeight(self)
        
        // cropX: 0, cropY: 0 for cropping from the top-left corner
        // Use source size to set cropWidth and cropHeight for no crop; just resize.
        return resizePixelBuffer(
            self,
            cropX: 0,
            cropY: 0,
            cropWidth: srcWidth,
            cropHeight: srcHeight,
            scaleWidth: squareSize,
            scaleHeight: squareSize
        )
    }
    
    private func resizePixelBuffer(_ srcPixelBuffer: CVPixelBuffer,
                                  cropX: Int,
                                  cropY: Int,
                                  cropWidth: Int,
                                  cropHeight: Int,
                                  scaleWidth: Int,
                                  scaleHeight: Int) -> CVPixelBuffer? {

      let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
      let dstPixelBuffer = createPixelBuffer(width: scaleWidth, height: scaleHeight,
                                             pixelFormat: pixelFormat)

      if let dstPixelBuffer = dstPixelBuffer {
        CVBufferPropagateAttachments(srcPixelBuffer, dstPixelBuffer)

        resizePixelBuffer(from: srcPixelBuffer, to: dstPixelBuffer,
                          cropX: cropX, cropY: cropY,
                          cropWidth: cropWidth, cropHeight: cropHeight,
                          scaleWidth: scaleWidth, scaleHeight: scaleHeight)
      }

      return dstPixelBuffer
    }
    
    private func resizePixelBuffer(from srcPixelBuffer: CVPixelBuffer,
                                  to dstPixelBuffer: CVPixelBuffer,
                                  cropX: Int,
                                  cropY: Int,
                                  cropWidth: Int,
                                  cropHeight: Int,
                                  scaleWidth: Int,
                                  scaleHeight: Int) {

      assert(CVPixelBufferGetWidth(dstPixelBuffer) >= scaleWidth)
      assert(CVPixelBufferGetHeight(dstPixelBuffer) >= scaleHeight)

      let srcFlags = CVPixelBufferLockFlags.readOnly
      let dstFlags = CVPixelBufferLockFlags(rawValue: 0)

      guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(srcPixelBuffer, srcFlags) else {
        print("Error: could not lock source pixel buffer")
        return
      }
      defer { CVPixelBufferUnlockBaseAddress(srcPixelBuffer, srcFlags) }

      guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(dstPixelBuffer, dstFlags) else {
        print("Error: could not lock destination pixel buffer")
        return
      }
      defer { CVPixelBufferUnlockBaseAddress(dstPixelBuffer, dstFlags) }

      guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer),
            let dstData = CVPixelBufferGetBaseAddress(dstPixelBuffer) else {
        print("Error: could not get pixel buffer base address")
        return
      }

      let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
      let offset = cropY*srcBytesPerRow + cropX*4
      var srcBuffer = vImage_Buffer(data: srcData.advanced(by: offset),
                                    height: vImagePixelCount(cropHeight),
                                    width: vImagePixelCount(cropWidth),
                                    rowBytes: srcBytesPerRow)

      let dstBytesPerRow = CVPixelBufferGetBytesPerRow(dstPixelBuffer)
      var dstBuffer = vImage_Buffer(data: dstData,
                                    height: vImagePixelCount(scaleHeight),
                                    width: vImagePixelCount(scaleWidth),
                                    rowBytes: dstBytesPerRow)

      let error = vImageScale_ARGB8888(&srcBuffer, &dstBuffer, nil, vImage_Flags(0))
      if error != kvImageNoError {
        print("Error:", error)
      }
    }
    
    private func createPixelBuffer(width: Int, height: Int, pixelFormat: OSType) -> CVPixelBuffer? {
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, width, height, pixelFormat, pixelBufferAttributes as CFDictionary, &pixelBuffer)
        if status != kCVReturnSuccess {
            print("Error: could not create pixel buffer", status)
            return nil
        }
        return pixelBuffer
    }
}

