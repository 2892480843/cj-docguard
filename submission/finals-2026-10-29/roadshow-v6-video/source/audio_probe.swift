import Foundation
import AppKit
import ScreenCaptureKit
import AVFoundation
import AudioToolbox
final class Meter:NSObject,SCStreamOutput,@unchecked Sendable {
 let lock=NSLock();var samples=0, peak:Float=0;var sum:Double=0;var buffers=0;var formats=Set<UInt32>()
 func stream(_ stream:SCStream,didOutputSampleBuffer sb:CMSampleBuffer,of type:SCStreamOutputType) {
  guard type == .audio, let fd=sb.formatDescription,let desc=CMAudioFormatDescriptionGetStreamBasicDescription(fd) else{return};lock.lock();buffers += 1;formats.insert(desc.pointee.mFormatFlags);lock.unlock();guard desc.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 else{return}
  guard let block=CMSampleBufferGetDataBuffer(sb) else{return}
  let n=CMBlockBufferGetDataLength(block);guard n>0 else{return}
  var bytes=Data(count:n)
  let status=bytes.withUnsafeMutableBytes { buf in CMBlockBufferCopyDataBytes(block,atOffset:0,dataLength:n,destination:buf.baseAddress!) }
  guard status==noErr else{return}
  lock.lock();defer{lock.unlock()}
  bytes.withUnsafeBytes { raw in let f=raw.bindMemory(to:Float.self);for v in f {peak=max(peak,abs(v));sum+=Double(v)*Double(v);samples+=1}}

 }
 func report()->[String:Any]{lock.lock();defer{lock.unlock()};return ["audio_buffers":buffers,"format_flags":Array(formats),"samples":samples,"peak":peak,"rms":sqrt(sum/Double(max(samples,1))),"microphone_captured":false,"scope":"WPS application system audio only"]}
}
@main struct Main {@MainActor static func main() async throws {_ = NSApplication.shared
 let c=try await SCShareableContent.excludingDesktopWindows(true,onScreenWindowsOnly:false)
 guard let w=c.windows.filter({$0.owningApplication?.bundleIdentifier == "com.kingsoft.wpsoffice.mac"}).max(by:{$0.frame.width*$0.frame.height < $1.frame.width*$1.frame.height}) else{throw NSError(domain:"WPS window not found",code:1)}
 let m=Meter();let cfg=SCStreamConfiguration();cfg.width=2;cfg.height=2;cfg.capturesAudio=true;cfg.sampleRate=48000;cfg.channelCount=2
 guard let app=w.owningApplication,let display=c.displays.first else{throw NSError(domain:"Missing WPS app or display",code:2)}
 let stream=SCStream(filter:SCContentFilter(display:display,including:[app],exceptingWindows:[]),configuration:cfg,delegate:nil)
 try stream.addStreamOutput(m,type:.audio,sampleHandlerQueue:DispatchQueue(label:"meter"));try await stream.startCapture();try await Task.sleep(nanoseconds:5_000_000_000);try await stream.stopCapture()
 let data=try JSONSerialization.data(withJSONObject:m.report(),options:[.prettyPrinted,.sortedKeys]);print(String(data:data,encoding:.utf8)!)
}}
