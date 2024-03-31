//
//  ContentView.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 28/03/2024.
//

import SwiftUI
import AVFoundation

struct VideoTrimControlView: UIViewRepresentable {
    var avAsset: AVAsset
    @EnvironmentObject var videoEditor: VideoEditorManager
    @Binding var player: AVPlayer?
    @Binding var startTime: String
    @Binding var currentTime: String
    @Binding var endTime: String
    
    func makeUIView(context: Context) -> some VideoTrimmer {
        return context.coordinator.initVideoTrimmer()
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: VideoTrimControlView
        var videoTrimmer = VideoTrimmer()
        private var wasPlaying = false
        private var avAsset: AVAsset {
            parent.avAsset
        }
        
        init(_ parent: VideoTrimControlView) {
            self.parent = parent
        }
        
        func initVideoTrimmer() -> VideoTrimmer {
            videoTrimmer.minimumDuration = CMTime(seconds: 1, preferredTimescale: 600)
            videoTrimmer.asset = avAsset
            videoTrimmer.addTarget(self, action: #selector(didBeginTrimming(_:)), for: VideoTrimmer.didBeginTrimming)
            videoTrimmer.addTarget(self, action: #selector(didEndTrimming(_:)), for: VideoTrimmer.didEndTrimming)
            videoTrimmer.addTarget(self, action: #selector(selectedRangeDidChanged(_:)), for: VideoTrimmer.selectedRangeChanged)
            videoTrimmer.addTarget(self, action: #selector(didBeginScrubbing(_:)), for: VideoTrimmer.didBeginScrubbing)
            videoTrimmer.addTarget(self, action: #selector(didEndScrubbing(_:)), for: VideoTrimmer.didEndScrubbing)
            videoTrimmer.addTarget(self, action: #selector(progressDidChanged(_:)), for: VideoTrimmer.progressChanged)

            updateTimeLineText()
            
            parent.player?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
                guard let self else { return }
                let finalTime = videoTrimmer.trimmingState == .none ? CMTimeAdd(time, videoTrimmer.selectedRange.start) : time
                videoTrimmer.progress = finalTime
            }
            
            return videoTrimmer
        }
        
        func updateTimeLineText() {
            DispatchQueue.main.async { [self] in
                let startTime = videoTrimmer.selectedRange.start
                let currentTime = videoTrimmer.progress
                let endTime = videoTrimmer.selectedRange.end
                
                parent.startTime = startTime.displayString
                parent.currentTime = currentTime.displayString
                parent.endTime = endTime.displayString
                
                parent.videoEditor.startTime = startTime
                parent.videoEditor.currentTime = currentTime
                parent.videoEditor.endTime = endTime
            }
        }
        
        private func updatePlayerAsset() {
            let outputRange = videoTrimmer.trimmingState == .none ? videoTrimmer.selectedRange : avAsset.fullRange
            let trimmedAsset = avAsset.trimmedComposition(outputRange)
            
            if let player = parent.player {
                let newAsset = player.currentItem?.asset
                if trimmedAsset != newAsset {
                    player.replaceCurrentItem(with: AVPlayerItem(asset: trimmedAsset))
                }
            }
        }
        
        // user action
        @objc func didBeginTrimming(_ sender: VideoTrimmer) {
            updateTimeLineText()
            
            wasPlaying = (parent.player?.timeControlStatus != .paused)
            parent.player?.pause()
            
            updatePlayerAsset()
        }
        
        @objc func didEndTrimming(_ sender: VideoTrimmer) {
            updateTimeLineText()
            
            if wasPlaying == true {
                parent.player?.play()
            }
            
            updatePlayerAsset()
        }
        
        @objc func selectedRangeDidChanged(_ sender: VideoTrimmer) {
            updateTimeLineText()
        }
        
        @objc func didBeginScrubbing(_ sender: VideoTrimmer) {
            updateTimeLineText()
            
            wasPlaying = (parent.player?.timeControlStatus != .paused)
            parent.player?.pause()
        }
        
        @objc func didEndScrubbing(_ sender: VideoTrimmer) {
            updateTimeLineText()
            
            if wasPlaying == true {
                parent.player?.play()
            }
        }
        
        @objc func progressDidChanged(_ sender: VideoTrimmer) {
            updateTimeLineText()
            
            let time = CMTimeSubtract(videoTrimmer.progress, videoTrimmer.selectedRange.start)
            parent.player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
}

extension CMTime {
    var displayString: String {
        let offset = TimeInterval(seconds)
        let numberOfNanosecondsFloat = (offset - TimeInterval(Int(offset))) * 100.0
        let nanoseconds = Int(numberOfNanosecondsFloat)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return String(format: "%@.%02d", formatter.string(from: offset) ?? "00:00", nanoseconds)
    }
}

extension AVAsset {
    var fullRange: CMTimeRange {
        return CMTimeRange(start: .zero, duration: duration)
    }
    func trimmedComposition(_ range: CMTimeRange) -> AVAsset {
        guard CMTimeRangeEqual(fullRange, range) == false else {return self}
        
        let composition = AVMutableComposition()
        try? composition.insertTimeRange(range, of: self, at: .zero)
        
        if let videoTrack = tracks(withMediaType: .video).first {
            composition.tracks.forEach {$0.preferredTransform = videoTrack.preferredTransform}
        }
        return composition
    }
}
