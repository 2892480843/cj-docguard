import Foundation
import AppKit
import ScreenCaptureKit
import AVFoundation
import CoreMedia

final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
 let lock = NSLock(), encode = DispatchQueue(label:"docguard.video.encode",qos:.userInteractive)
 var latest: CVPixelBuffer?, callbacks = 0, complete = 0, written = 0, reused = 0, failures = 0, sourceSequence = 0, lastSequence = -1
 var writer: AVAssetWriter!, input: AVAssetWriterInput!, adaptor: AVAssetWriterInputPixelBufferAdaptor!, timer: DispatchSourceTimer?, stream: SCStream!
 var duration = 120, started = false
 var done: CheckedContinuation<Void,Never>?
 var begin: UInt64 = 0, maxLateMs: Double = 0
 func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
  guard type == .screen, sampleBuffer.isValid, let buffer=sampleBuffer.imageBuffer else { return }
  let a = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]]
  guard let raw=a?.first?[.status] as? Int, SCFrameStatus(rawValue:raw) == .complete else{return}
  lock.lock(); latest=buffer; callbacks += 1; sourceSequence += 1; lock.unlock()
 }
 func run(path: String, seconds: Int) async throws {
  duration=seconds
  let c=try await SCShareableContent.excludingDesktopWindows(true,onScreenWindowsOnly:false)
  guard let w=c.windows.filter({($0.owningApplication?.applicationName.contains("Chrome") ?? false) && ($0.title?.contains("CJ-DocGuard") ?? false)}).max(by:{$0.frame.width*$0.frame.height < $1.frame.width*$1.frame.height}) else {throw NSError(domain:"No project browser window",code:1)}
  let filter=SCContentFilter(desktopIndependentWindow:w)
  let config=SCStreamConfiguration(); config.width=1920; config.height=1080; config.minimumFrameInterval=CMTime(value:1,timescale:60);config.queueDepth=6;config.pixelFormat=kCVPixelFormatType_32BGRA;config.showsCursor=true;config.capturesAudio=false
  config.ignoreShadowsSingleWindow=true
  config.sourceRect=CGRect(x:0,y:180,width:1512,height:773)
  // Capture only the project window; no display capture and no microphone.
  print("WINDOW \(w.windowID) \(w.frame) CONTENT \(filter.contentRect)")
  fflush(stdout)
  writer=try AVAssetWriter(outputURL:URL(fileURLWithPath:path),fileType:.mp4)
  input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264, AVVideoWidthKey:1920,AVVideoHeightKey:1080,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:8_000_000,AVVideoExpectedSourceFrameRateKey:60,AVVideoMaxKeyFrameIntervalKey:120,AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel]])
  input.expectsMediaDataInRealTime=true;writer.add(input)
  adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:1920,kCVPixelBufferHeightKey as String:1080])
  writer.startWriting();writer.startSession(atSourceTime:.zero)
  stream=SCStream(filter:filter,configuration:config,delegate:self)
  try stream.addStreamOutput(self,type:.screen,sampleHandlerQueue:DispatchQueue(label:"docguard.video.capture",qos:.userInteractive))
  try await stream.startCapture()
  for _ in 0..<300 {if hasBuffer(){break};try await Task.sleep(nanoseconds:10_000_000)}
  guard hasBuffer() else {throw NSError(domain:"No capture frames",code:2)}
  print("RECORDING_STARTED \(Date().timeIntervalSince1970)");fflush(stdout)
  await withCheckedContinuation { continuation in
   done=continuation;begin=DispatchTime.now().uptimeNanoseconds
   let t=DispatchSource.makeTimerSource(queue:encode);timer=t
   t.schedule(deadline:.now(),repeating:.nanoseconds(16_666_667),leeway:.microseconds(300))
   t.setEventHandler {[self] in
    let elapsed=Double(DispatchTime.now().uptimeNanoseconds-begin)/1e9
    maxLateMs=max(maxLateMs,(elapsed-Double(written)/60)*1000)
    lock.lock();let buffer=latest,seq=sourceSequence;lock.unlock()
    guard let buffer else{return}
    if !input.isReadyForMoreMediaData {failures += 1;return}
    if seq==lastSequence {reused += 1};lastSequence=seq
    if adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(written),timescale:60)){written += 1}else{failures += 1}
    if written >= duration*60 {t.cancel();timer=nil;done?.resume();done=nil}
   };t.resume()
  }
  try await stream.stopCapture();input.markAsFinished();await writer.finishWriting()
  let stats:[String:Any]=["duration":duration,"fps":60,"frames":written,"capture_callbacks":callbacks,"static_reuses":reused,"encode_waits":failures,"max_schedule_late_ms":maxLateMs,"writer_status":writer.status.rawValue,"completed_at":Date().timeIntervalSince1970]
  let data=try JSONSerialization.data(withJSONObject:stats,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:path+".json"));print(String(data:data,encoding:.utf8)!);if writer.status != .completed {throw writer.error ?? NSError(domain:"Writer",code:3)}
 }
 func hasBuffer()->Bool{lock.lock();defer{lock.unlock()};return latest != nil}
}
@main struct Main { @MainActor static func main() async throws {_ = NSApplication.shared;let r=Recorder();try await r.run(path:CommandLine.arguments[1],seconds:Int(CommandLine.arguments[2])!)} }
