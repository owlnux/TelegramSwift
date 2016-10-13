//
//  DrawingContext.swift
//  TGLibrary
//
//  Created by keepcoder on 18/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

let deviceScale:CGFloat = 2.0
let deviceColorSpace = CGColorSpaceCreateDeviceRGB()

public enum DrawingContextBltMode {
    case Alpha
}

public class DrawingContext {
    public let size: CGSize
    public let scale: CGFloat
    public let scaledSize: CGSize
    public let bytesPerRow: Int
    private let bitmapInfo: CGBitmapInfo
    public let length: Int
    public let bytes: UnsafeMutableRawPointer
    let provider: CGDataProvider?
    
    private var _context: CGContext?
    
    public func withContext(_ f: @noescape(CGContext) -> ()) {
        if self._context == nil {
            if let c = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: self.bitmapInfo.rawValue) {
                c.scaleBy(x: scale, y: scale)
                self._context = c
            }
        }
        
        if let _context = self._context {
//            _context.translateBy(x: self.size.width / 2.0, y: self.size.height / 2.0)
//            _context.scaleBy(x: 1.0, y: -1.0)
//            _context.translateBy(x: -self.size.width / 2.0, y: -self.size.height / 2.0)
            
            f(_context)
            
//            _context.translateBy(x: self.size.width / 2.0, y: self.size.height / 2.0)
//            _context.scaleBy(x: 1.0, y: -1.0)
//            _context.translateBy(x: -self.size.width / 2.0, y: -self.size.height / 2.0)
        }
    }
    
    public func withFlippedContext(_ f: @noescape(CGContext) -> ()) {
        if self._context == nil {
            if let c = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: self.bitmapInfo.rawValue) {
                c.scaleBy(x: scale, y: scale)
                self._context = c
            }
        }
        
        if let _context = self._context {
            f(_context)
        }
    }
    
    public init(size: CGSize, scale: CGFloat = deviceScale, clear: Bool = false) {
        self.size = size
        self.scale = scale
        self.scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        self.bytesPerRow = (4 * Int(scaledSize.width) + 15) & (~15)
        self.length = bytesPerRow * Int(scaledSize.height)
        
        self.bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        self.bytes = malloc(length)!
        if clear {
            memset(self.bytes, 0, self.length)
        }
        self.provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
            free(bytes)
        })
    }
    
    public func generateImage() -> CGImage? {
        if let image = CGImage(width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
            return image
        } else {
            return nil
        }
    }
    
    public func colorAt(_ point: CGPoint) -> NSColor {
        let x = Int(point.x * self.scale)
        let y = Int(point.y * self.scale)
        if x >= 0 && x < Int(self.scaledSize.width) && y >= 0 && y < Int(self.scaledSize.height) {
            let srcLine = self.bytes.advanced(by: y * self.bytesPerRow).assumingMemoryBound(to: UInt32.self)
            let pixel = srcLine + x
            let colorValue = pixel.pointee
            return NSColor.clear  //NSColor(UInt32(colorValue))
        } else {
            return NSColor.clear
        }
    }
    
    public func blt(_ other: DrawingContext, at: CGPoint, mode: DrawingContextBltMode = .Alpha) {
        if abs(other.scale - self.scale) < CGFloat(FLT_EPSILON) {
            let srcX = 0
            var srcY = 0
            let dstX = Int(at.x * self.scale)
            var dstY = Int(at.y * self.scale)
            
            let width = min(Int(self.size.width * self.scale) - dstX, Int(other.size.width * self.scale))
            let height = min(Int(self.size.height * self.scale) - dstY, Int(other.size.height * self.scale))
            
            let maxDstX = dstX + width
            let maxDstY = dstY + height
            
            switch mode {
            case .Alpha:
                while dstY < maxDstY {
                    let srcLine = other.bytes.advanced(by: srcY * other.bytesPerRow).assumingMemoryBound(to: UInt32.self)
                    let dstLine = self.bytes.advanced(by: dstY * self.bytesPerRow).assumingMemoryBound(to: UInt32.self)
                    
                    var dx = dstX
                    var sx = srcX
                    while dx < maxDstX {
                        let srcPixel = srcLine + sx
                        let dstPixel = dstLine + dx
                        
                        let baseColor = dstPixel.pointee
                        let baseR = (baseColor >> 16) & 0xff
                        let baseG = (baseColor >> 8) & 0xff
                        let baseB = baseColor & 0xff
                        
                        let alpha = srcPixel.pointee >> 24
                        
                        let r = (baseR * alpha) / 255
                        let g = (baseG * alpha) / 255
                        let b = (baseB * alpha) / 255
                        
                        dstPixel.pointee = (alpha << 24) | (r << 16) | (g << 8) | b
                        
                        dx += 1
                        sx += 1
                    }
                    
                    dstY += 1
                    srcY += 1
                }
            }
        }
    }
}

public enum ParsingError: Error {
    case Generic
}

public func readCGFloat(_ index: inout UnsafePointer<UInt8>, end: UnsafePointer<UInt8>, separator: UInt8) throws -> CGFloat {
    let begin = index
    var seenPoint = false
    while index <= end {
        let c = index.pointee
        index = index.successor()
        
        if c == 46 { // .
            if seenPoint {
                throw ParsingError.Generic
            } else {
                seenPoint = true
            }
        } else if c == separator {
            break
        } else if c < 48 || c > 57 {
            throw ParsingError.Generic
        }
    }
    
    if index == begin {
        throw ParsingError.Generic
    }
    
    if let value = NSString(bytes: UnsafePointer<Void>(begin), length: index - begin, encoding: String.Encoding.utf8.rawValue)?.floatValue {
        return CGFloat(value)
    } else {
        throw ParsingError.Generic
    }
}

public func drawSvgPath(_ context: CGContext, path: StaticString) throws {
    var index: UnsafePointer<UInt8> = path.utf8Start
    let end = path.utf8Start.advanced(by: path.utf8CodeUnitCount)
    while index < end {
        let c = index.pointee
        index = index.successor()
        
        if c == 77 { // M
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Move to \(x), \(y)")
            context.move(to: CGPoint(x: x, y: y))
        } else if c == 76 { // L
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            
            //print("Line to \(x), \(y)")
            context.addLine(to: CGPoint(x: x, y: y))
        } else if c == 67 { // C
            let x1 = try readCGFloat(&index, end: end, separator: 44)
            let y1 = try readCGFloat(&index, end: end, separator: 32)
            let x2 = try readCGFloat(&index, end: end, separator: 44)
            let y2 = try readCGFloat(&index, end: end, separator: 32)
            let x = try readCGFloat(&index, end: end, separator: 44)
            let y = try readCGFloat(&index, end: end, separator: 32)
            context.addCurve(to: CGPoint(x: x1, y: y1), control1: CGPoint(x: x2, y: y2), control2: CGPoint(x: x, y: y))
            
            //print("Line to \(x), \(y)")
            
        } else if c == 90 { // Z
            if index != end && index.pointee != 32 {
                throw ParsingError.Generic
            }
            
            //CGContextClosePath(context)
            context.fillPath()
            //CGContextBeginPath(context)
            //print("Close")
        }
    }
}