//
//  CropVideoManager.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 29/03/2024.
//

import UIKit
import Photos
import AVFoundation

class VideoEditorManager: NSObject {
    static var shared = VideoEditorManager()
    private let fileManager = FileManager.default
    
    func trimVideo(_ asset: AVAsset, startTime: CMTime, endTime: CMTime, completionHandler: @escaping (URL) -> Void) {
        let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
        let outputURL = createTemporaryDirectory(subPath: "trimVideo")
        self.exportSession(asset, outputURL: outputURL, outputFileType: .mp4, timeRange: timeRange) { outputURL in
            completionHandler(outputURL)
        }
    }
    
    func addEffectToVideo(_ asset: AVAsset, effectName: String, completionHander: @escaping (URL) -> Void) {
        let filter = CIFilter(name: effectName)
        let videoComposition = AVVideoComposition(asset: asset) { request in
            let sourceImage = request.sourceImage.clampedToExtent()
            filter?.setValue(sourceImage, forKey: kCIInputImageKey)
            guard let outputImage = filter?.outputImage?.cropped(to: request.sourceImage.extent) else { return }
            
            request.finish(with: outputImage, context: nil)
        }
        
        let outputURL = createTemporaryDirectory(subPath: "filerToVideo")
        
        self.exportSession(asset, outputURL: outputURL, outputFileType: .mp4, videoComposition: videoComposition) { outputURL in
            completionHander(outputURL)
        }
    }
    
    func addTextToVideo(_ asset: AVAsset, title: String, startTime: CMTime, endTime: CMTime, completionHandler: @escaping (URL) -> Void) {
        let addTextTimeimeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
        let videoTrack = asset.tracks( withMediaType: .video ).first! as AVAssetTrack
        let naturalSize = CGSize(
            width: videoTrack.naturalSize.width,
            height: videoTrack.naturalSize.height
        )
        let renderWidth = naturalSize.width
        let renderHeight = naturalSize.height
        
        let titleLayer = CATextLayer()
        let videolayer = CALayer()
        let parentlayer = CALayer()
        
        titleLayer.string = title
        titleLayer.shadowOpacity = 0.5
        titleLayer.font = UIFont.preferredFont(forTextStyle: .title3)
        titleLayer.alignmentMode = CATextLayerAlignmentMode.center
        
        titleLayer.frame = CGRect(x: 20, y: 50, width: renderWidth, height: renderHeight / 6)
        videolayer.frame = CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight)
        parentlayer.frame = CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight)
        
        parentlayer.addSublayer(videolayer)
        parentlayer.addSublayer(titleLayer)
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        transformer.setOpacity(1.0, at: CMTime.zero)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = addTextTimeimeRange
        instruction.layerInstructions = [transformer]
        
        let mutableVideoComposition = AVMutableVideoComposition()
        mutableVideoComposition.renderSize = naturalSize
        mutableVideoComposition.instructions = [instruction]
        mutableVideoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        mutableVideoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videolayer, in: parentlayer
        )
        
        let outputURL = createTemporaryDirectory(subPath: "videoText")
        self.exportSession(asset, outputURL: outputURL, outputFileType: .mp4, videoComposition: mutableVideoComposition) { outputURL in
            completionHandler(outputURL)
        }
    }
    
    func addAudioToVideo(_ videoAsset: AVAsset, audioAsset: AVAsset, completionHandler: @escaping (URL) -> Void) {
        let mixComposition = AVMutableComposition()
        var instruction = AVMutableVideoCompositionInstruction()
        var mutableCompositionVideoTrack: [AVMutableCompositionTrack] = []
        var mutableCompositionAudioTrack: [AVMutableCompositionTrack] = []
        
        guard let videoTrack = mixComposition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid
        ), let audioTrack = mixComposition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { return }
        mutableCompositionVideoTrack.append(videoTrack)
        mutableCompositionAudioTrack.append(audioTrack)
        
        guard let videoAssetTrack = videoAsset.tracks(withMediaType: .video).first,
              let audioAssetTrack = audioAsset.tracks(withMediaType: .audio).first
        else { return }
        
        let naturalSize = CGSize(
            width: videoAssetTrack.naturalSize.width,
            height: videoAssetTrack.naturalSize.height
        )
        let timeRange = CMTimeRangeMake(start: .zero, duration: videoAssetTrack.timeRange.duration)
        
        instruction = AVMutableComposition.instruction(
            videoAssetTrack, startTime: .zero,
            duration: videoAssetTrack.timeRange.duration,
            maxRenderSize: naturalSize
        ).videoCompositionInstruction
        
        do {
            try mutableCompositionVideoTrack.first?.insertTimeRange(timeRange, of: videoAssetTrack, at: CMTime.zero)
            try mutableCompositionAudioTrack.first?.insertTimeRange(timeRange, of: audioAssetTrack, at: CMTime.zero)
            videoTrack.preferredTransform = videoAssetTrack.preferredTransform
            
        } catch{
            print(error.localizedDescription)
        }
        
        let mutableVideoComposition = AVMutableVideoComposition()
        mutableVideoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mutableVideoComposition.renderSize = naturalSize
        mutableVideoComposition.instructions = [instruction]
        
        let outputURL = createTemporaryDirectory(subPath: "audioToVideo")
        self.exportSession(mixComposition, outputURL: outputURL, outputFileType: .mp4, videoComposition: mutableVideoComposition) { outputURL in
            completionHandler(outputURL)
        }
    }
    
    func mergeTwoVideos(_ assets: [AVAsset], completionHandler: @escaping (URL) -> Void) {
        let mixComposition = AVMutableComposition()
        var instructions: [AVMutableVideoCompositionInstruction] = []
        
        let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
//        compositionVideoTrack?.preferredTransform = CGAffineTransform(rotationAngle: .pi / 2)
        
        var timetoAddVideo = CMTime.zero
        var renderSize = CGSize.zero
        
        assets.forEach { asset in
            let videoAssetTrack = asset.tracks(withMediaType: .video).first!
            let audioAssetTrack = asset.tracks(withMediaType: .audio).first
            
            let naturalSize = CGSize(
                width: videoAssetTrack.naturalSize.width,
                height: videoAssetTrack.naturalSize.height
            )
            
            if asset == assets.first {
                let instruction = AVMutableComposition.instruction(videoAssetTrack, startTime: timetoAddVideo, duration: videoAssetTrack.timeRange.duration, maxRenderSize: naturalSize)
                instructions.append(instruction.videoCompositionInstruction)
                
                renderSize = instruction.isPortrait ? CGSize(width: naturalSize.height, height: naturalSize.width) : CGSize(width: naturalSize.width, height: naturalSize.height)
            } else {
                let instruction = AVMutableComposition.instruction(videoAssetTrack, startTime: timetoAddVideo, duration: videoAssetTrack.timeRange.duration, maxRenderSize: naturalSize, scale: 1)
                instructions.append(instruction.videoCompositionInstruction)
            }
            
            do {
                let timeRange = CMTimeRangeMake(start: .zero, duration: videoAssetTrack.timeRange.duration)
                try compositionVideoTrack?.insertTimeRange(timeRange, of: videoAssetTrack, at: timetoAddVideo)
                if let audioAssetTrack {
                    try compositionAudioTrack?.insertTimeRange(timeRange, of: audioAssetTrack, at: timetoAddVideo)
                }
                
                timetoAddVideo = CMTimeAdd(timetoAddVideo, videoAssetTrack.timeRange.duration)
            } catch {
                print(error.localizedDescription)
            }
        }
        
        let mutableVideoComposition = AVMutableVideoComposition()
        mutableVideoComposition.renderSize = renderSize
        mutableVideoComposition.instructions = instructions
        mutableVideoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        let outputURL = createTemporaryDirectory(subPath: "mergeVideos")
        self.exportSession(mixComposition, outputURL: outputURL, outputFileType: .mp4, videoComposition: mutableVideoComposition) { outputURL in
            completionHandler(outputURL)
        }
    }
    
    private func exportSession(
        _ asset: AVAsset, outputURL: URL, outputFileType: AVFileType,
        timeRange: CMTimeRange? = nil, videoComposition: AVVideoComposition? = nil,
        completionHandler: @escaping (URL) -> Void) {
            guard let exporter = AVAssetExportSession(
                asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return }
            exporter.videoComposition = videoComposition
            exporter.outputURL = outputURL
            exporter.outputFileType = outputFileType
            if timeRange != nil {
                exporter.timeRange = timeRange!
            }
            
            exporter.exportAsynchronously { [weak exporter] in
                switch exporter!.status {
                case .completed :
                    print("success")
                    completionHandler(outputURL)
                default:
                    if let error = exporter?.error {
                        print(error.localizedDescription)
                    }
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
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: URL.getURL(tempDirectory), includingPropertiesForKeys: nil)
            guard !fileURLs.isEmpty else { return }
            for url in fileURLs {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            print(error.localizedDescription)
        }
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

extension AVMutableComposition {
    static func instruction(_ assetTrack: AVAssetTrack, startTime: CMTime, duration: CMTime, maxRenderSize: CGSize, scale: CGFloat = 1)
        -> (videoCompositionInstruction: AVMutableVideoCompositionInstruction, isPortrait: Bool) {
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: assetTrack)
            let assetInfo = orientationFromTransform(assetTrack.preferredTransform)
            var scaleRatio = maxRenderSize.width / assetTrack.naturalSize.width
            if assetInfo.isPortrait {
                scaleRatio = maxRenderSize.height / assetTrack.naturalSize.height
            }

            var transform = CGAffineTransform(scaleX: scaleRatio * scale, y: scaleRatio * scale)
            transform = assetTrack.preferredTransform.concatenating(transform)
            layerInstruction.setTransform(transform, at: .zero)
            
            let videoCompositionInstruction = AVMutableVideoCompositionInstruction()
            videoCompositionInstruction.timeRange = CMTimeRangeMake(start: startTime, duration: duration)
            videoCompositionInstruction.layerInstructions = [layerInstruction]
            
            return (videoCompositionInstruction, assetInfo.isPortrait)
    }
    
    static func orientationFromTransform(_ transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
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
}
