import AppKit
import Foundation
let output = CommandLine.arguments[1]
func render(_ pixels: Int, _ path: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: pixels*4, bitsPerPixel: 32)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels)/512, y: CGFloat(pixels)/512)
    context.cgContext.setShouldAntialias(true)
    NSColor.black.setFill(); NSBezierPath(rect: NSRect(x:0,y:0,width:512,height:512)).fill()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x:105,y:170,width:302,height:180), xRadius:28,yRadius:28).fill()
    let top=NSBezierPath();top.move(to:NSPoint(x:169,y:345));top.line(to:NSPoint(x:193,y:382));top.line(to:NSPoint(x:267,y:382));top.line(to:NSPoint(x:291,y:345));top.close();top.fill()
    NSColor.black.setFill();NSBezierPath(ovalIn:NSRect(x:197,y:201,width:118,height:118)).fill()
    NSColor.white.setStroke();let lens=NSBezierPath(ovalIn:NSRect(x:210,y:214,width:92,height:92));lens.lineWidth=9;lens.stroke()
    NSColor.black.setFill();NSBezierPath(roundedRect:NSRect(x:346,y:306,width:30,height:15),xRadius:5,yRadius:5).fill()
    NSColor(srgbRed:1,green:59.0/255,blue:48.0/255,alpha:1).setStroke()
    let ring=NSBezierPath(ovalIn:NSRect(x:62,y:62,width:388,height:388));ring.lineWidth=34;ring.stroke()
    let slash=NSBezierPath();slash.move(to:NSPoint(x:119,y:393));slash.line(to:NSPoint(x:393,y:119));slash.lineWidth=34;slash.lineCapStyle = .round;slash.stroke()
    context.flushGraphics();NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
}
try render(512,output+"/artwork/Icon-512.png")
try render(512,output+"/Settings/Resources/HeaderIcon.png")
for scale in 1...3 { try render(29*scale,output+"/Settings/Resources/Icon"+(scale==1 ? "" : "@\(scale)x")+".png") }
