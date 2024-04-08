//
//  CropVideoManager.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 29/03/2024.
//

import UIKit
import Photos

class VideoEditorManager: NSObject {
    static var shared = VideoEditorManager()
    private let fileManager = FileManager.default
    let defaultSize1 = CGSize(width: 720, height: 1280) // Default video size
    let defaultSize2 = CGSize(width: 1920, height: 1080)
    var videoDuration = 30.0 // Duration of output video when merging videos & images
    
    func trimVideo(_ asset: AVAsset, startTime: CMTime, endTime: CMTime, completionHandler: @escaping (URL?, Error?) -> Void) {
        let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
        let outputURL = createTemporaryDirectory(subPath: "trimVideo")
        self.exportSession(asset, outputURL: outputURL, outputFileType: .mp4, timeRange: timeRange) { outputURL, error in
            completionHandler(outputURL,error)
        }
    }
    
    func addEffectToVideo(_ asset: AVAsset, effectName: String, completionHander: @escaping (URL?, Error?) -> Void) {
        let filter = CIFilter(name: effectName)
        let videoComposition = AVVideoComposition(asset: asset) { request in
            let sourceImage = request.sourceImage.clampedToExtent()
            filter?.setValue(sourceImage, forKey: kCIInputImageKey)
            guard let outputImage = filter?.outputImage?.cropped(to: request.sourceImage.extent) else { return }
            
            request.finish(with: outputImage, context: nil)
        }
        
        let outputURL = createTemporaryDirectory(subPath: "filerToVideo")
        
        self.exportSession(asset, outputURL: outputURL, outputFileType: .mp4, videoComposition: videoComposition) { outputURL, error in
            completionHander(outputURL, error)
        }
    }
    
    func addTextToVideo(_ avAssets: [AVAsset], textData: [TextData]?, completionHandler: @escaping (URL?, Error?) -> Void) {
        var insertTime = CMTime.zero
        var arrayLayerInstructions:[AVMutableVideoCompositionLayerInstruction] = []
        var arrayLayerImages:[CALayer] = []
        
        // Black background video
        guard let bgVideoURL = Bundle.main.url(forResource: "black", withExtension: "mov") else {
            print("Need black background video !")
            completionHandler(nil,nil)
            return
        }
        
        let bgVideoAsset = AVAsset(url: bgVideoURL)
        guard let bgVideoTrack = bgVideoAsset.tracks(withMediaType: AVMediaType.video).first else {
            print("Need black background video !")
            completionHandler(nil,nil)
            return
        }
        
        // Silence sound (in case video has no sound track)
        guard let silenceURL = Bundle.main.url(forResource: "silence", withExtension: "mp3") else {
            print("Missing resource")
            completionHandler(nil, nil)
            return
        }
        
        let silenceAsset = AVAsset(url:silenceURL)
        let silenceSoundTrack = silenceAsset.tracks(withMediaType: AVMediaType.audio).first
        
        // Init composition
        let mixComposition = AVMutableComposition()

        // Merge
        avAssets.forEach { avAsset in
            let videoAsset = avAsset
            // Get video track
            guard let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first else { return }
            
            // Get audio track
            var audioTrack:AVAssetTrack?
            if videoAsset.tracks(withMediaType: AVMediaType.audio).count > 0 {
                audioTrack = videoAsset.tracks(withMediaType: AVMediaType.audio).first
            }
            else {
                audioTrack = silenceSoundTrack
            }
            
            // Init video & audio composition track
            let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video,
                                                                       preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            
            let audioCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio,
                                                                       preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            
            do {
                let startTime = CMTime.zero
                let duration = videoAsset.duration
                
                // Add video track to video composition at specific time
                try videoCompositionTrack?.insertTimeRange(CMTimeRangeMake(start: startTime, duration: duration),
                                                           of: videoTrack,
                                                           at: insertTime)
                
                // Add audio track to audio composition at specific time
                if let audioTrack = audioTrack {
                    try audioCompositionTrack?.insertTimeRange(CMTimeRangeMake(start: startTime, duration: duration),
                                                               of: audioTrack,
                                                               at: insertTime)
                }
                
                // Add instruction for video track
                if let videoCompositionTrack = videoCompositionTrack {
                    let layerInstruction = videoCompositionInstructionForTrack(track: videoCompositionTrack, asset: videoAsset, targetSize: defaultSize2)
                    
                    // Hide video track before changing to new track
                    let endTime = CMTimeAdd(insertTime, duration)
                    let durationAnimation = 1.0.toCMTime()
                    
                    layerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: CMTimeRange.init(start: endTime, duration: durationAnimation))
                    
                    arrayLayerInstructions.append(layerInstruction)
                }
                
                // Increase the insert time
                insertTime = CMTimeAdd(insertTime, duration)
            }
            catch {
                print("Load track error")
            }
        }
        
        // Init Video layer
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(x: 0, y: 0, width: defaultSize2.width, height: defaultSize2.height)
        
        let parentlayer = CALayer()
        parentlayer.frame = CGRect(x: 0, y: 0, width: defaultSize2.width, height: defaultSize2.height)
        parentlayer.addSublayer(videoLayer)
        
        // Add Image layers
        for layer in arrayLayerImages {
            parentlayer.addSublayer(layer)
        }
        
        // Add Text layer
        if let textData = textData {
            for aTextData in textData {
                let textLayer = makeTextLayer(string: aTextData.text,
                                              fontSize: aTextData.fontSize,
                                              textColor: UIColor.green,
                                              frame: aTextData.textFrame,
                                              showTime: aTextData.showTime,
                                              hideTime: aTextData.endTime)
                parentlayer.addSublayer(textLayer)
            }
        }
        
        // Main video composition instruction
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: insertTime)
        mainInstruction.layerInstructions = arrayLayerInstructions
        
        // Main video composition
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = defaultSize2
        mainComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentlayer)
        
        // Export Session
        let outputURL = createTemporaryDirectory(subPath: "addTextToVideo")
        self.exportSession(mixComposition, outputURL: outputURL, outputFileType: .mp4, videoComposition: mainComposition) { outputURL ,error in
            completionHandler(outputURL, error)
        }
    }
    
    func mergeAudioToVideo(_ videoAsset: AVAsset, audioAsset: AVAsset, completionHandler: @escaping (URL?, Error?) -> Void) {
        let mixComposition = AVMutableComposition()
        var arrayLayerInstructions:[AVMutableVideoCompositionLayerInstruction] = []
        
        guard let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first else {
            completionHandler(nil, nil)
            return
        }
        
        let naturalSize = videoTrack.naturalSize
        var audioTrack:AVAssetTrack?
        if audioAsset.tracks(withMediaType: AVMediaType.audio).count > 0 {
            audioTrack = audioAsset.tracks(withMediaType: AVMediaType.audio).first
        }
        
        let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video,
                                                                   preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        
        let audioCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio,
                                                                   preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        
        let startTime = CMTime.zero
        let duration = videoAsset.duration
        var insertTime = CMTime.zero
        
        do {
            try videoCompositionTrack?.insertTimeRange(CMTimeRangeMake(start: startTime, duration: duration),
                                                       of: videoTrack,
                                                       at: insertTime)
            if let audioTrack = audioTrack {
                let audioDuration = audioAsset.duration > videoAsset.duration ? videoAsset.duration : audioAsset.duration
                try audioCompositionTrack?.insertTimeRange(CMTimeRangeMake(start: startTime, duration: audioDuration),
                                                           of: audioTrack,
                                                           at: insertTime)
            }
            
            if let videoCompositionTrack = videoCompositionTrack {
                let layerInstruction = videoCompositionInstructionForTrack(track: videoCompositionTrack, asset: videoAsset, targetSize: naturalSize)
                arrayLayerInstructions.append(layerInstruction)
            }
            
            insertTime = CMTimeAdd(insertTime, duration)
        } catch {
            print("Load track error")
            completionHandler(nil, nil)
        }
        
        // Main video composition instruction
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: insertTime)
        mainInstruction.layerInstructions = arrayLayerInstructions
        
        // Main video composition
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = naturalSize
        
        // Export Session
        let outputURL = createTemporaryDirectory(subPath: "mergeAudioToVideo")
        self.exportSession(mixComposition, outputURL: outputURL, outputFileType: .mp4, videoComposition: mainComposition) { outputURL ,error in
            completionHandler(outputURL, error)
        }
    }
    
    func mergeVideos(arrayVideos:[AVAsset], animation:Bool, completionHandler: @escaping (URL?, Error?) -> Void) {
        var insertTime = CMTime.zero
        var arrayLayerInstructions: [AVMutableVideoCompositionLayerInstruction] = []

        guard let silenceURL = Bundle.main.url(forResource: "silence", withExtension: "mp3") else {
            print("Missing resource")
            completionHandler(nil, nil)
            return
        }
        
        let silenceAsset = AVAsset(url:silenceURL)
        let silenceSoundTrack = silenceAsset.tracks(withMediaType: AVMediaType.audio).first
        let mixComposition = AVMutableComposition()
        
        for videoAsset in arrayVideos {
            guard let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first else { continue }
            var audioTrack: AVAssetTrack?
            
            if videoAsset.tracks(withMediaType: AVMediaType.audio).count > 0 {
                audioTrack = videoAsset.tracks(withMediaType: AVMediaType.audio).first
            } else {
                audioTrack = silenceSoundTrack
            }
            
            let videoCompositionTrack = mixComposition.addMutableTrack(
                withMediaType: AVMediaType.video,
                preferredTrackID: Int32(kCMPersistentTrackID_Invalid)
            )
//            videoCompositionTrack?.preferredTransform = CGAffineTransform(rotationAngle: .pi / 2)
            
            let audioCompositionTrack = mixComposition.addMutableTrack(
                withMediaType: AVMediaType.audio,
                preferredTrackID: Int32(kCMPersistentTrackID_Invalid)
            )
            
            do {
                let startTime = CMTime.zero
                let duration = videoAsset.duration
                
                try videoCompositionTrack?.insertTimeRange(CMTimeRangeMake(start: startTime, duration: duration),
                                                           of: videoTrack,
                                                           at: insertTime)
                if let audioTrack = audioTrack {
                    try audioCompositionTrack?.insertTimeRange(CMTimeRangeMake(start: startTime, duration: duration),
                                                               of: audioTrack,
                                                               at: insertTime)
                }
                
                // Add instruction for video track
                if let videoCompositionTrack = videoCompositionTrack {
                    let targetSize = videoTrack.naturalSize.width > videoTrack.naturalSize.height ? defaultSize2 : defaultSize1
                    let layerInstruction = videoCompositionInstructionForTrack(track: videoCompositionTrack, asset: videoAsset, targetSize: targetSize)
                    
                    // Hide video track before changing to new track
                    let endTime = CMTimeAdd(insertTime, duration)
                    
                    if animation {
                        let durationAnimation = 1.0.toCMTime()
                        
                        layerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: CMTimeRange(start: endTime, duration: durationAnimation))
                    }
                    else {
                        layerInstruction.setOpacity(0, at: endTime)
                    }
                    
                    arrayLayerInstructions.append(layerInstruction)
                }
                
                // Increase the insert time
                insertTime = CMTimeAdd(insertTime, duration)
            }
            catch {
                print("Load track error")
            }
        }
        
        // Main video composition instruction
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: insertTime)
        mainInstruction.layerInstructions = arrayLayerInstructions
        
        // Main video composition
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = defaultSize2
        
        // Export Session
        let outputURL = createTemporaryDirectory(subPath: "mergeVideos")
        self.exportSession(mixComposition, outputURL: outputURL, outputFileType: .mp4, videoComposition: mainComposition) { outputURL ,error in
            completionHandler(outputURL, error)
        }
    }
    
    private func exportSession(
        _ asset: AVAsset, outputURL: URL, outputFileType: AVFileType,
        timeRange: CMTimeRange? = nil, videoComposition: AVVideoComposition? = nil,
        completionHandler: @escaping (URL?, Error?) -> Void) {
            guard let exporter = AVAssetExportSession(
                asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return }
            exporter.outputURL = outputURL
            exporter.videoComposition = videoComposition
            exporter.outputFileType = outputFileType
            exporter.shouldOptimizeForNetworkUse = true
            if timeRange != nil {
                exporter.timeRange = timeRange!
            }
            
            exporter.exportAsynchronously { [weak exporter] in
                switch exporter!.status {
                case .completed :
                    print("success")
                    completionHandler(outputURL, nil)
                default:
                    completionHandler(nil, exporter?.error)
                }
            }
        }
    
    private func createTemporaryDirectory(subPath: String) -> URL {
        if #available(iOS 16.0, *) {
            return URL(filePath: NSTemporaryDirectory() + subPath + UUID().uuidString + ".mp4")
        } else {
            return URL(fileURLWithPath: NSTemporaryDirectory() + subPath + UUID().uuidString + ".mp4")
        }
    }
    
    func deleteTempDirectory() {
        let tempDirectory = NSTemporaryDirectory()
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: URL.getURL(tempDirectory), includingPropertiesForKeys: nil)
            guard !fileURLs.isEmpty else { return }
            for url in fileURLs {
                try FileManager.default.removeItem(at: url)
                if let documentsDirectory {
                    try FileManager.default.removeItem(at: documentsDirectory)
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func readAudioData(from url: URL, completionHandle: @escaping ([Float]?, Error?) -> Void) {
        DispatchQueue.global().async {
            do {
                let audioFile = try AVAudioFile(forReading: url)
                let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: audioFile.fileFormat.sampleRate, channels: audioFile.fileFormat.channelCount, interleaved: false)
                let buffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: UInt32(audioFile.length))
                try audioFile.read(into: buffer!)
                let audioData = Array(UnsafeBufferPointer(start: buffer!.floatChannelData![0], count: Int(buffer!.frameLength)))
                DispatchQueue.main.async {
                    print(audioData.count)
                    completionHandle(audioData, nil)
                }
            } catch {
                completionHandle(nil, error)
            }
        }
    }
}

extension VideoEditorManager {
    private func setOrientation(image:UIImage?, onLayer:CALayer, outputSize:CGSize) -> Void {
        guard let image = image else { return }

        if image.imageOrientation == UIImage.Orientation.up {
            // Do nothing
        }
        else if image.imageOrientation == UIImage.Orientation.left {
            let rotate = CGAffineTransform(rotationAngle: .pi/2)
            onLayer.setAffineTransform(rotate)
        }
        else if image.imageOrientation == UIImage.Orientation.down {
            let rotate = CGAffineTransform(rotationAngle: .pi)
            onLayer.setAffineTransform(rotate)
        }
        else if image.imageOrientation == UIImage.Orientation.right {
            let rotate = CGAffineTransform(rotationAngle: -.pi/2)
            onLayer.setAffineTransform(rotate)
        }
    }
    
    private func videoCompositionInstructionForTrack(track: AVCompositionTrack?, asset: AVAsset, targetSize: CGSize) -> AVMutableVideoCompositionLayerInstruction {
        guard let track = track else {
            return AVMutableVideoCompositionLayerInstruction()
        }
        
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let assetTrack = asset.tracks(withMediaType: AVMediaType.video)[0]

        let transform = assetTrack.fixedPreferredTransform
        let assetInfo = orientationFromTransform(transform)
        
        var scaleToFitRatio = targetSize.width / assetTrack.naturalSize.width
        if assetInfo.isPortrait {
            // Scale to fit target size
            scaleToFitRatio = targetSize.width / assetTrack.naturalSize.height
            let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
            
            // Align center Y
            let newY = targetSize.height/2 - (assetTrack.naturalSize.width * scaleToFitRatio)/2
            let moveCenterFactor = CGAffineTransform(translationX: 0, y: newY)
            
            let finalTransform = transform.concatenating(scaleFactor).concatenating(moveCenterFactor)

            instruction.setTransform(finalTransform, at: .zero)
        } else {
            // Scale to fit target size
            let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
            
            // Align center Y
            let newY = targetSize.height/2 - (assetTrack.naturalSize.height * scaleToFitRatio)/2
            let moveCenterFactor = CGAffineTransform(translationX: 0, y: newY)
            
            let finalTransform = transform.concatenating(scaleFactor).concatenating(moveCenterFactor)
            
            instruction.setTransform(finalTransform, at: .zero)
        }

        return instruction
    }
    
    private func orientationFromTransform(_ transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation = UIImage.Orientation.up
        var isPortrait = false
        
        switch [transform.a, transform.b, transform.c, transform.d] {
        case [0.0, 1.0, -1.0, 0.0]:
            assetOrientation = .right
            isPortrait = true
            
        case [0.0, -1.0, 1.0, 0.0]:
            assetOrientation = .left
            isPortrait = true
            
        case [1.0, 0.0, 0.0, 1.0]:
            assetOrientation = .up
            
        case [-1.0, 0.0, 0.0, -1.0]:
            assetOrientation = .down

        default:
            break
        }
    
        return (assetOrientation, isPortrait)
    }
    
    private func makeTextLayer(string:String, fontSize:CGFloat, textColor:UIColor, frame:CGRect, showTime:CGFloat, hideTime:CGFloat) -> CXETextLayer {
        let textLayer = CXETextLayer()
        textLayer.string = string
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = textColor.cgColor
        textLayer.alignmentMode = CATextLayerAlignmentMode.center
        textLayer.opacity = 0
        textLayer.frame = frame
        
        
        let fadeInAnimation = CABasicAnimation.init(keyPath: "opacity")
        fadeInAnimation.duration = 0.5
        fadeInAnimation.fromValue = NSNumber(value: 0)
        fadeInAnimation.toValue = NSNumber(value: 1)
        fadeInAnimation.isRemovedOnCompletion = false
        fadeInAnimation.beginTime = CFTimeInterval(showTime)
        fadeInAnimation.fillMode = CAMediaTimingFillMode.forwards
        
        textLayer.add(fadeInAnimation, forKey: "textOpacityIN")
        
        if hideTime > 0 {
            let fadeOutAnimation = CABasicAnimation.init(keyPath: "opacity")
            fadeOutAnimation.duration = 1
            fadeOutAnimation.fromValue = NSNumber(value: 1)
            fadeOutAnimation.toValue = NSNumber(value: 0)
            fadeOutAnimation.isRemovedOnCompletion = false
            fadeOutAnimation.beginTime = CFTimeInterval(hideTime)
            fadeOutAnimation.fillMode = CAMediaTimingFillMode.forwards
            
            textLayer.add(fadeOutAnimation, forKey: "textOpacityOUT")
        }
        
        return textLayer
    }
}

extension Double {
    func toCMTime() -> CMTime {
        return CMTime(seconds: self, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    }
}

extension FileManager {
    func removeItemIfExisted(_ url:URL) -> Void {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(atPath: url.path)
            }
            catch {
                print("Failed to delete file")
            }
        }
    }
}

extension AVAssetTrack {
    var fixedPreferredTransform: CGAffineTransform {
        var newT = preferredTransform
        switch [newT.a, newT.b, newT.c, newT.d] {
        case [1, 0, 0, 1]:
            newT.tx = 0
            newT.ty = 0
        case [1, 0, 0, -1]:
            newT.tx = 0
            newT.ty = naturalSize.height
        case [-1, 0, 0, 1]:
            newT.tx = naturalSize.width
            newT.ty = 0
        case [-1, 0, 0, -1]:
            newT.tx = naturalSize.width
            newT.ty = naturalSize.height
        case [0, -1, 1, 0]:
            newT.tx = 0
            newT.ty = naturalSize.width
        case [0, 1, -1, 0]:
            newT.tx = naturalSize.height
            newT.ty = 0
        case [0, 1, 1, 0]:
            newT.tx = 0
            newT.ty = 0
        case [0, -1, -1, 0]:
            newT.tx = naturalSize.height
            newT.ty = naturalSize.width
        default:
            break
        }
        return newT
    }
}

extension URL {
    static func getURL(_ path: String) -> URL {
        if #available(iOS 16.0, *) {
            URL(filePath: path)
        } else {
            URL(fileURLWithPath: path)
        }
    }
}

struct VideoData {
    var index:Int?
    var image:UIImage?
    var asset:AVAsset?
    var isVideo = false
}

struct TextData {
    var text = ""
    var fontSize:CGFloat = 40
    var textColor = UIColor.red
    var showTime:CGFloat = 0
    var endTime:CGFloat = 0
    var textFrame = CGRect(x: 0, y: 0, width: 500, height: 500)
}

class CXETextLayer : CATextLayer {
    override init() {
        super.init()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(layer: aDecoder)
    }
    
    override func draw(in ctx: CGContext) {
        let height = self.bounds.size.height
        let fontSize = self.fontSize
        let yDiff = (height-fontSize)/2 - fontSize/10
        
        ctx.saveGState()
        ctx.translateBy(x: 0.0, y: yDiff)
        super.draw(in: ctx)
        ctx.restoreGState()
    }
}
