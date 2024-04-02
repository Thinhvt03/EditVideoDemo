//
//  VideoTrimmerView.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 28/03/2024.
//

import SwiftUI
import AVKit
import PhotosUI

struct VideoEditView: View {
    @State var startTime = CMTime.zero
    @State var currentTime = CMTime.zero
    @State var endTime = CMTime.zero
    @State private var player: AVPlayer?
    @State private var avAsset: AVAsset?
    @EnvironmentObject var photoLibraryManager: PhotoLibraryManager
    var videoEditorManager = VideoEditorManager.shared
    var asset: Asset?
    
    enum FeatureType: String, CaseIterable {
        case none, effect, trim, addText, addAudio, mergeVideos
        var title: String { rawValue.capitalized }
    }
     
    @State private var featureType: FeatureType = .none
    @State private var filterName: EffectName = .sharpenLuminance
    @State private var textToVideo = ""
    
    var body: some View {
        VStack {
            VideoPlayer(player: player)
                .frame(height: 300)
            
            switch featureType {
            case .none: EmptyView()
            case .effect:
                Picker("Picker Add Filter", selection: $filterName) {
                    ForEach(EffectName.allCases, id: \.self) { item in
                        Text(item.name).tag(item)
                    }
                }
                .pickerStyle(.wheel)
                .padding()
            case .trim:
                if avAsset != nil && player != nil {
                    VideoTrimControlView(avAsset: avAsset!, player: $player,
                                         startTime: $startTime, currentTime: $currentTime, endTime: $endTime)
                    .frame(height: 60)
                    
                    HStack {
                        Group {
                            Text(startTime.convertCMTimeToString)
                            Spacer()
                            Text(currentTime.convertCMTimeToString)
                            Spacer()
                            Text(endTime.convertCMTimeToString)
                        }
                        .font(.subheadline)
                    }.padding(.horizontal)
                }
            case .addText:
                TextField(" Enter text", text: $textToVideo)
                    .frame(height: 40)
                    .border(.gray, width: 1)
                    .padding()
            case .addAudio:
                Text("Touch Save Button to save sample audio in video ")
            case .mergeVideos:
                Text("Touch Save Button to merge videos ")
            }
            
            Picker("Picker", selection: $featureType) {
                ForEach(FeatureType.allCases.dropFirst(), id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Button("Save") {
                guard let avAsset else { return }
                switch featureType {
                case .none: break
                case .effect:
                    videoEditorManager.addEffectToVideo(avAsset, effectName: filterName.name) { url in
                        saveInLibraryAndUpdatePlayer(url)
                    }
                case .trim:
                    videoEditorManager.trimVideo(avAsset, startTime: startTime, endTime: endTime) { url in
                        saveInLibraryAndUpdatePlayer(url)
                    }
                case .addText:
                    guard !textToVideo.isEmpty else { return }
                    videoEditorManager.addTextToVideo(avAsset, title: textToVideo, startTime: startTime, endTime: endTime) { url in
                        saveInLibraryAndUpdatePlayer(url)
                    }
                case .addAudio:
                    let avAudioAsset = AVAsset(url: Bundle.main.url(forResource: "sampleAudio", withExtension: "mp3")!)
                    videoEditorManager.addAudioToVideo(avAsset, audioAsset: avAudioAsset) { url in
                        saveInLibraryAndUpdatePlayer(url)
                    }
                case .mergeVideos:
                    let avAsset2 = AVAsset(url: Bundle.main.url(forResource: "sampleVideo", withExtension: "mp4")!)
                    videoEditorManager.mergeTwoVideos([avAsset, avAsset2]) { url in
                        saveInLibraryAndUpdatePlayer(url)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .navigationTitle("Edit Video")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let asset {
                requestPlayerItem(asset.asset)
                asset.requestAVAsset { avAsset in
                    self.avAsset = avAsset
                }
            }
        }
        .onDisappear {
            player?.pause()
            videoEditorManager.deleteTempDirectory()
        }
    }
    
    private func requestPlayerItem(_ asset: PHAsset) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options,
                                                   resultHandler: { playerItem, _ in
            DispatchQueue.main.async {
                player = AVPlayer(playerItem: playerItem)
                player?.play()
            }
        })
    }
    
    private func saveInLibraryAndUpdatePlayer(_ url: URL) {
        featureType = .none
        player?.pause()
        player = AVPlayer(url: url)
        player?.seek(to: .zero) { success in
            player?.play()
        }
//        photoLibraryManager.saveVideoToLibrary(url)
        print("Saved in photos library")
    }
}
