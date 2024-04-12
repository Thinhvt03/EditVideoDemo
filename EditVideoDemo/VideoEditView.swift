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
    @State private var assetUrl: URL?
    @EnvironmentObject var photoLibraryManager: PhotoLibraryManager
    var videoEditorManager = VideoEditorManager.shared
    @State private var isDocumentPicker = false
    @State private var isImagePicker = false
    @State private var selectedAudioURL: URL?
    @State private var isProgressView = false
    @State private var isWaveformView = false
    @State private var audioData: [Float] = []
    @State private var phAssets: [PHAsset] = []
    @State private var assetUrls: [URL] = []
    var asset: Asset?
    
    enum FeatureType: String, CaseIterable {
        case none, effect, trim, addText, addAudio, mergeVideos
        var title: String { rawValue.capitalized }
    }
     
    @State private var featureType: FeatureType = .none
    @State private var filterName: EffectName = .sharpenLuminance
    @State private var textToVideo = ""
    @State private var textLocation = CGPoint.zero
    @State private var textSize = CGSize(width: 130, height: 50)
    @State private var playerViewHeight: CGFloat = 0
    @State private var isChangedPlayer = false
    
    var body: some View {
        VStack {
            if player != nil {
                ZStack {
                    AVPlayerView(player: $player, isChangedPlayer: $isChangedPlayer)
                        .frame(height: playerViewHeight)
                        .overlay {
                            if featureType == .addText {
                                TextView(text: $textToVideo, textSize: $textSize, textLocation: $textLocation)
                            }
                            
                            if isProgressView {
                                ProgressView {
                                    Text("Progressing Video...")
                                        .font(.footnote)
                                        .foregroundStyle(Color.white)
                                }
                                .padding()
                                .background(Color.black.opacity(0.8))
                            }
                        }
                } .padding(.vertical)
            }
            
            switch featureType {
            case .none: EmptyView()
            case .effect:
                Picker("Picker Add Filter", selection: $filterName) {
                    ForEach(EffectName.allCases, id: \.self) { item in
                        Text(item.name).tag(item)
                    }
                }
                .pickerStyle(.wheel)
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
                EmptyView()
            case .addAudio:
                VStack {
                    Button("Select Audio") {
                        isDocumentPicker.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if selectedAudioURL != nil {
                        VStack(alignment: .leading) {
                            AudioWaveformView(url: $selectedAudioURL, isLoading: $isWaveformView)
                                .frame(height: 50)
                                .border(Color.gray, width: 1.0)
                                .overlay {
                                    if !isWaveformView {
                                        ProgressView()
                                    }
                                }
                            Text(selectedAudioURL!.lastPathComponent)
                                .lineLimit(0)
                        }
                        .padding(.horizontal)
                    }
                }
            case .mergeVideos:
                HStack(spacing: 1) {
                    Color.gray
                        .frame(width: 60, height: 60)
                        .overlay {
                            Button {
                                isImagePicker.toggle()
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                   
                    LazyHGrid(rows: [GridItem(.fixed(20))], spacing: 1) {
                        ForEach(phAssets, id: \.self) { asset in
                            VideoGridItem(asset: Asset(asset: asset))
                                .frame(width: 60, height: 60)
                                .clipped()
                        }
                    }
                }
                .frame(width: 60, height: 60)
            }
            
            Picker("Picker", selection: $featureType) {
                ForEach(FeatureType.allCases.dropFirst(), id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            HStack {
                Button("Done") {
                    guard let avAsset else { return }
                    isProgressView.toggle()
                    switch featureType {
                    case .none: break
                    case .effect:
                        videoEditorManager.addEffectToVideo(avAsset, effectName: filterName.name) { url, error in
                            updatePlayer(url, error: error)
                        }
                    case .trim:
                        videoEditorManager.trimVideo(avAsset, startTime: startTime, endTime: endTime) { url, error in
                            updatePlayer(url, error: error)
                        }
                    case .addText:
                        guard !textToVideo.isEmpty && asset != nil else {
                            isProgressView.toggle()
                            return
                        }
                        let textData = TextData(text: textToVideo,
                                                fontSize: 30,
                                                textColor: UIColor.green,
                                                showTime: 3,
                                                endTime: 14,
                                                textFrame: CGRect(origin: textLocation, size: textSize)
                        )
                        
                        videoEditorManager.addTextToVideo(avAsset, textData: [textData]) { url, error in
                            updatePlayer(url, error: error)
                        }
                    case .addAudio:
                        guard let selectedAudioURL else { return }
                        let avAudioAsset = AVAsset(url: selectedAudioURL)
                        videoEditorManager.mergeAudioToVideo(avAsset, audioAsset: avAudioAsset) { url, error in
                            updatePlayer(url, error: error)
                        }
                    case .mergeVideos:
                        self.insertAsset(.contemporary) { mergeType, avAssets in
                            print("Asset Count: \(avAssets.count)")
                            videoEditorManager.mergeVideos(arrayVideos: avAssets, animation: true, mergeType: mergeType) { url, error in
                                updatePlayer(url, error: error)
                            }
                        }
                    }
                }
                
                Button("Save") {
                    if let assetUrl {
                        photoLibraryManager.saveVideoToLibrary(assetUrl)
                        self.assetUrl = nil
                    }
                }
                .disabled(assetUrl == nil ? true : false)
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .navigationTitle("Edit Video")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isDocumentPicker) {
            DocumentPickerView(selectedAudioURL: $selectedAudioURL, isPresented: $isDocumentPicker)
        }
        .sheet(isPresented: $isImagePicker) {
            VideoPicker(assets: $phAssets, assetUrls: $assetUrls)
        }
        .onAppear {
            if let asset {
                requestPlayerItem(asset.asset)
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
                if let avAsset = playerItem?.asset {
                    self.avAsset = avAsset
                    if let videoTrack = avAsset.tracks.first {
                        let videoHeight = videoTrack.naturalSize.height
                        let videoWidth = videoTrack.naturalSize.width
                        let scale = videoHeight < videoWidth ? videoHeight / videoWidth : videoWidth / videoHeight
                        playerViewHeight = UIScreen.main.bounds.width * scale
                    }
                }
            }
        })
    }
    
    private func updatePlayer(_ url: URL?, error: Error?) {
        isProgressView.toggle()
        guard url != nil && error == nil else {
            if let error {
                print("Error: \(error.localizedDescription)")
            }
            return
        }
        
        featureType = .none
        player?.pause()
        player = AVPlayer(url: url!)
        isChangedPlayer = true
        self.assetUrl = url
        self.avAsset = AVAsset(url: url!)
    }
    
    private func insertAsset(_ mergeType: MergeType, completionHandle: @escaping (MergeType, [AVAsset]) -> Void) {
        guard let avAsset else { return }
        var avAssets: [AVAsset] = [avAsset]
        var count = 0
        assetUrls.forEach {
            if mergeType == .serial {
                avAssets.append(AVAsset(url: $0))
            } else {
                avAssets.insert(AVAsset(url: $0), at: avAssets.count - 1)
            }
            count += 1
        }
        
        if count == assetUrls.count {
            completionHandle(mergeType, avAssets)
        }
    }
}
