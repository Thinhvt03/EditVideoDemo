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
    @State var startTime = "00:00:00"
    @State var currentTime = "00:00:00"
    @State var endTime = "00:00:00"
    @State private var player: AVPlayer?
    @State private var avAsset: AVAsset?
    @EnvironmentObject var videoEditor: VideoEditorManager
    @EnvironmentObject var photoLibraryManager: PhotoLibraryManager
    var asset: Asset?
    
    enum FeatureType: String, CaseIterable {
        case none, trim, addText, addAudio, mergeVideos
        var title: String { rawValue.capitalized }
    }
     
    @State private var featureType: FeatureType = .none
    @State private var textToVideo = ""
    
    var body: some View {
        VStack {
            VideoPlayer(player: player)
                .frame(height: 300)
            
            switch featureType {
            case .none: EmptyView()
            case .trim:
                if avAsset != nil && player != nil {
                    VideoTrimControlView(avAsset: avAsset!, player: $player,
                                         startTime: $startTime, currentTime: $currentTime, endTime: $endTime)
                    .environmentObject(videoEditor)
                    .frame(height: 60)
                    
                    HStack {
                        Group {
                            Text(startTime)
                            Spacer()
                            Text(currentTime)
                            Spacer()
                            Text(endTime)
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
                Text("Unfinished feature ")
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
                case .none:
                    break
                case .trim:
                    videoEditor.trimVideo(avAsset, startTime: videoEditor.startTime, endTime: videoEditor.endTime) { url in
                        saveInLibraryAndUpdatePlayer(url)
                    }
                case .addText:
                    guard !textToVideo.isEmpty else { return }
                    videoEditor.addTextToVideo(avAsset, title: textToVideo, startTime: videoEditor.startTime, endTime: videoEditor.endTime) { url in
                        saveInLibraryAndUpdatePlayer(url)
                    }
                case .addAudio:
                    let avAudioAsset = AVAsset(url: Bundle.main.url(forResource: "sampleAudio", withExtension: "mp3")!)
                    videoEditor.addAudioToVideo(avAsset, audioAsset: avAudioAsset) { url in
                        saveInLibraryAndUpdatePlayer(url)
                    }
                case .mergeVideos:
                    break
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
        player = AVPlayer(url: url)
        player?.seek(to: .zero) { success in
            player?.play()
        }
//        photoLibraryManager.saveVideoToLibrary(url)
    }
}
