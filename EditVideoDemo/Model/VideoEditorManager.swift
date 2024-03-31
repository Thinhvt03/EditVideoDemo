//
//  CropVideoManager.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 29/03/2024.
//

import UIKit
import Photos
import AVFoundation

class VideoEditorManager: ObservableObject {
    @Published var startTime = CMTime(value: 1, timescale: 30)
    @Published var currentTime = CMTime(value: 1, timescale: 30)
    @Published var endTime = CMTime(value: 1, timescale: 30)
    
    func trimVideo(_ asset: AVAsset, startTime: CMTime, endTime: CMTime, completionHandler: @escaping (URL) -> Void) {
        let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
        let outputURL = createTemporaryDirectory(subPath: "trimVideo")
        self.exportSession(asset, outputURL: outputURL, outputFileType: .mp4, timeRange: timeRange) { outputURL in
            completionHandler(outputURL)
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
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: videoTrack.naturalTimeScale)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videolayer, in: parentlayer
        )
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        transformer.setOpacity(1.0, at: CMTime.zero)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        
        let outputURL = createTemporaryDirectory(subPath: "videoText")
        self.exportSession(asset, outputURL: outputURL, outputFileType: .mp4, videoComposition: videoComposition) { outputURL in
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
        
        guard let videoAssetTrack: AVAssetTrack = videoAsset.tracks(withMediaType: .video).first,
              let audioAssetTrack: AVAssetTrack = audioAsset.tracks(withMediaType: .audio).first 
        else { return }
        
        do {
            try mutableCompositionVideoTrack.first?.insertTimeRange(
                CMTimeRangeMake(start: CMTime.zero, duration: videoAssetTrack.timeRange.duration),
                of: videoAssetTrack, at: CMTime.zero
            )
            try mutableCompositionAudioTrack.first?.insertTimeRange(
                CMTimeRangeMake(start: CMTime.zero, duration: videoAssetTrack.timeRange.duration),
                of: audioAssetTrack, at: CMTime.zero
            )
            videoTrack.preferredTransform = videoAssetTrack.preferredTransform
            
        } catch{
            print(error.localizedDescription)
        }
        
        let totalVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
        totalVideoCompositionInstruction.timeRange = CMTimeRangeMake(
            start: CMTime.zero, duration: videoAssetTrack.timeRange.duration
        )
        
        let naturalSize = CGSize(
            width: videoAssetTrack.naturalSize.width,
            height: videoAssetTrack.naturalSize.height
        )
        let mutableVideoComposition = AVMutableVideoComposition()
        mutableVideoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mutableVideoComposition.renderSize = naturalSize
        
        let outputURL = createTemporaryDirectory(subPath: "audioToVideo")
        self.exportSession(mixComposition, outputURL: outputURL, outputFileType: .mp4) { outputURL in
            completionHandler(outputURL)
        }
    }
    
    func mergeTwoVideos(_ asset1: AVAsset, asset2: AVAsset, completionHandler: @escaping (URL) -> Void) {
        // To do
    }
    
    private func exportSession(
        _ asset: AVAsset, outputURL: URL, outputFileType: AVFileType,
        timeRange: CMTimeRange? = nil, videoComposition: AVMutableVideoComposition? = nil,
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
}
