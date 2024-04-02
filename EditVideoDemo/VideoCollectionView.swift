//
//  VideoCollectionView.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 29/03/2024.
//

import SwiftUI

struct VideoCollection: View {
    @EnvironmentObject var photoLibraryManager: PhotoLibraryManager
    private var videoEditorManager = VideoEditorManager.shared
    private let columns: [GridItem] = {
        var columns = [GridItem]()
        for _ in 0..<3 {
            columns.append(GridItem(.flexible(), spacing: 1))
        }
        return columns
    }()
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(photoLibraryManager.videoAssets, id: \.self) { asset in
                    NavigationLink {
                        VideoEditView(asset: asset)
                            .environmentObject(photoLibraryManager)
                    } label: {
                        VideoGridItem(asset: asset)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    }
                }
            }
        }
        .navigationTitle("Videos")
        .onAppear {
            PhotoLibraryPermissionManager.checkPhotoLibraryPermission { grant in
                if grant {
                    photoLibraryManager.fetchVideos()
                }
            }
        }
    }
}

struct VideoGridItem: View {
    @ObservedObject var asset: Asset
    private let backgroundColor = Color.clear
    private let targetSize: CGSize = .init(width: 120, height: 120)
    @State private var image = UIImage(systemName: "photo")!
    
    var body: some View {
        backgroundColor
            .overlay(
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            )
            .onAppear {
                asset.request(targetSize) { image in
                    self.image = image
                }
            }
    }
}
