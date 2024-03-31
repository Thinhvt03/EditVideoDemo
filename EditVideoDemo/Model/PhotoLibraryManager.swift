//
//  PhotoLibrary.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 31/03/2024.
//

import Foundation
import Photos

class PhotoLibraryManager: ObservableObject {
    @Published var videoAssets = [Asset]()
    private var photoLibrary = PHPhotoLibrary.shared()
    
    func fetchVideos() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        
        DispatchQueue.global().async {
            var assets = [Asset]()
            result.enumerateObjects { asset, _, _ in
                assets.append(Asset(asset: asset))
            }
            DispatchQueue.main.async {
                self.videoAssets = assets
                assets = []
            }
        }
    }
    
    func saveVideoToLibrary(_ videoUrl: URL, completionHandler: ((PHAsset) -> Void)? = nil) {
        var localIdentifier: String = ""
        photoLibrary.performChanges {
            let changeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoUrl)
            localIdentifier = changeRequest?.placeholderForCreatedAsset?.localIdentifier ?? ""
        } completionHandler: { success, error in
            if success {
                print("Save video success")
                let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject!
                DispatchQueue.main.async {
                    if let completionHandler {
                        completionHandler(phAsset)
                    }
                }
            } else {
                print(error?.localizedDescription ?? "Error save video")
            }
        }
    }
}
