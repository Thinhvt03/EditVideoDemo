//
//  ImagePickerView.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 08/04/2024.
//

import SwiftUI
import PhotosUI

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var assets: [PHAsset]
    @Binding var assetUrls: [URL]
    
    func makeUIViewController(context: Context) -> some UIViewController {
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.filter = .videos
        configuration.selectionLimit = 0
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: PHPickerViewControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            handle(results, picker: picker)
        }
        
        // MARK: - Helper Method
        private func handle(_ results: [PHPickerResult], picker: PHPickerViewController) {
        
            guard !results.isEmpty else {
                picker.dismiss(animated: true)
                return
            }
            
            var photoURLs = [URL]()
            let itemProviders = results.map(\.itemProvider)
            let group = DispatchGroup()
            
            for item in itemProviders {
                group.enter()
                
                if item.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    item.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { videoURL, _ in
                        if let videoURL {
                            self.writePhotoToDocument(videoURL) { outputURL in
                                photoURLs.append(outputURL)
                            }
                        }
                        group.leave()
                    }
                } else if item.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    item.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { imageURL, _ in
                        if let imageURL {
                            self.writePhotoToDocument(imageURL) { outputURL in
                                photoURLs.append(outputURL)
                            }
                        }
                        group.leave()
                    }
                }
            }
            
            var assets: [PHAsset] = []
            let identifiers = results.compactMap(\.assetIdentifier)
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            
            group.notify(queue: .main) {
                self.parent.assets.append(contentsOf: assets)
                self.parent.assetUrls.append(contentsOf: photoURLs)
                picker.dismiss(animated: true)
            }
        }
        
        private func writePhotoToDocument(_ itemURL: URL, completeHandler: @escaping (URL) -> Void) {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            else {  return  }
            let pathComponent = itemURL.lastPathComponent
            let fileURL = documentsDirectory.appendingPathComponent(pathComponent)
            
            do {
                try fileManager.copyItem(at: itemURL, to: fileURL)
                completeHandler(fileURL)
            } catch {
                print("Error saving photo to disk: \(error)")
            }
        }
    }
}
