//
//  MTKBridge.swift
//  BasicSurfaces
//
//  Created by Colin Ford on 2/9/20.
//  See:
//  https://forums.developer.apple.com/thread/119112
//

import SwiftUI

struct MTKBridge: NSViewRepresentable {
    typealias NSViewType = MTKView
      var mtkView: MTKView
                
      func makeCoordinator() -> Coordinator {
          Coordinator(self, mtkView: mtkView)
      }
        
      func makeUIView(context: UIViewRepresentableContext<MetalMapView>) -> MTKView {
          mtkView.delegate = context.coordinator
          mtkView.preferredFramesPerSecond = 60
          mtkView.backgroundColor = context.environment.colorScheme == .dark ? UIColor.white : UIColor.white
          mtkView.isOpaque = true
          mtkView.enableSetNeedsDisplay = true
          return mtkView
      }
        
      func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<MetalMapView>) {
            
      }
        
      class Coordinator : NSObject, MTKViewDelegate {
          var parent: MetalMapView
          var ciContext: CIContext!
          var metalDevice: MTLDevice!
    
          var metalCommandQueue: MTLCommandQueue!
          var mtlTexture: MTLTexture!
                    
          var startTime: Date!
          init(_ parent: MetalMapView, mtkView: MTKView) {
              self.parent = parent
              if let metalDevice = MTLCreateSystemDefaultDevice() {
                  mtkView.device = metalDevice
                  self.metalDevice = metalDevice
              }
              self.ciContext = CIContext(mtlDevice: metalDevice)
              self.metalCommandQueue = metalDevice.makeCommandQueue()!
                
              super.init()
              mtkView.framebufferOnly = false
              mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
              mtkView.drawableSize = mtkView.frame.size
              mtkView.enableSetNeedsDisplay = true
          }
    
          func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
                
          }
            
          func draw(in view: MTKView) {
              guard let drawable = view.currentDrawable else {
                  return
              }
              let commandBuffer = metalCommandQueue.makeCommandBuffer()
              let inputImage = CIImage(mtlTexture: mtlTexture)!
              var size = view.bounds
              size.size = view.drawableSize
              size = AVMakeRect(aspectRatio: inputImage.extent.size, insideRect: size)
              let filteredImage = inputImage.transformed(by: CGAffineTransform(
                  scaleX: size.size.width/inputImage.extent.size.width,
                  y: size.size.height/inputImage.extent.size.height))
              let x = -size.origin.x
              let y = -size.origin.y
                
                
              self.mtlTexture = drawable.texture
              ciContext.render(filteredImage,
                  to: drawable.texture,
                  commandBuffer: commandBuffer,
                  bounds: CGRect(origin:CGPoint(x:x, y:y), size: view.drawableSize),
                  colorSpace: CGColorSpaceCreateDeviceRGB())
    
              commandBuffer?.present(drawable)
              commandBuffer?.commit()
          }
            
          func getUIImage(texture: MTLTexture, context: CIContext) -> UIImage?{
              let kciOptions = [CIImageOption.colorSpace: CGColorSpaceCreateDeviceRGB(),
                                CIContextOption.outputPremultiplied: true,
                                CIContextOption.useSoftwareRenderer: false] as! [CIImageOption : Any]
                
              if let ciImageFromTexture = CIImage(mtlTexture: texture, options: kciOptions) {
                  if let cgImage = context.createCGImage(ciImageFromTexture, from: ciImageFromTexture.extent) {
                      let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .downMirrored)
                      return uiImage
                  }else{
                      return nil
                  }
              }else{
                  return nil
              }
          }
      }
}

struct MTKBridge_Previews: PreviewProvider {
    static var previews: some View {
        MTKBridge()
    }
}
