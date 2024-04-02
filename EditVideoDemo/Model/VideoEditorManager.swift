//
//  CropVideoManager.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 29/03/2024.
//

import UIKit
import Photos
import AVFoundation

var defaultSize = CGSize(width: 1920, height: 1080)

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
        let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
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
        videolayer.addSublayer(titleLayer)
        
        let mutableVideoComposition = AVMutableVideoComposition()
        mutableVideoComposition.renderSize = naturalSize
        mutableVideoComposition.frameDuration = CMTime(value: 1, timescale: videoTrack.naturalTimeScale)
        mutableVideoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videolayer, in: parentlayer
        )
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        transformer.setOpacity(1.0, at: CMTime.zero)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        instruction.layerInstructions = [transformer]
        mutableVideoComposition.instructions = [instruction]
        
        let outputURL = createTemporaryDirectory(subPath: "videoText")
        self.exportSession(asset, outputURL: outputURL, outputFileType: .mp4, videoComposition: mutableVideoComposition) { outputURL in
            completionHandler(outputURL)
        }
    }
    
    func addAudioToVideo(_ videoAsset: AVAsset, audioAsset: AVAsset, completionHandler: @escaping (URL) -> Void) {
        let mixComposition = AVMutableComposition()
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
        let timeRange = CMTimeRangeMake(start: .zero, duration: videoAssetTrack.timeRange.duration)
        
        do {
            try mutableCompositionVideoTrack.first?.insertTimeRange(timeRange, of: videoAssetTrack, at: CMTime.zero)
            try mutableCompositionAudioTrack.first?.insertTimeRange(timeRange, of: audioAssetTrack, at: CMTime.zero)
            videoTrack.preferredTransform = videoAssetTrack.preferredTransform
            
        } catch{
            print(error.localizedDescription)
        }
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        instruction.backgroundColor = UIColor.clear.cgColor
        
        let naturalSize = CGSize(
            width: videoAssetTrack.naturalSize.width,
            height: videoAssetTrack.naturalSize.height
        )
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
        let mutableVideoComposition = AVMutableVideoComposition()
        let instructions: [AVMutableVideoCompositionInstruction] = []
        
        let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
//        compositionVideoTrack?.preferredTransform = CGAffineTransform(rotationAngle: .pi / 2)
        
        var timetoAddVideo = CMTime.zero
        assets.forEach { asset in
            do {
                let videoAssetTrack = asset.tracks(withMediaType: .video).first!
                let audioAssetTrack = asset.tracks(withMediaType: .audio).first!
                
                try compositionVideoTrack?.insertTimeRange(asset.fullRange, of: videoAssetTrack, at: timetoAddVideo)
                try compositionAudioTrack?.insertTimeRange(asset.fullRange, of: audioAssetTrack, at: timetoAddVideo)
                
                timetoAddVideo = CMTimeAdd(timetoAddVideo, videoAssetTrack.timeRange.duration)
            } catch {
                print(error.localizedDescription)
            }
        }
        
        mutableVideoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mutableVideoComposition.renderSize = defaultSize
        mutableVideoComposition.instructions = instructions
        
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
            exporter.shouldOptimizeForNetworkUse = true
            exporter.outputFileType = outputFileType
            if timeRange != nil {
                exporter.timeRange = timeRange!
            }
            
            exporter.exportAsynchronously { [weak exporter] in
                switch exporter!.status {
                case .completed :
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
