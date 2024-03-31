//
//  Asset.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 29/03/2024.
//

import PhotosUI

private var manager = PHCachingImageManager()
private var imageManager = PHImageManager.default()

class Asset: ObservableObject, Identifiable, Hashable {
    var id: String {
        asset.localIdentifier
    }
    
    static func == (lhs: Asset, rhs: Asset) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    @Published var imageSize: Int64?
    @Published var image: UIImage?
    let asset: PHAsset
    
    private var requestId: PHImageRequestID?
 
    func request(_ targetSize: CGSize = .init(width: 120, height: 120),
                 completionHandler: @escaping (UIImage) -> Void) {
        manager.requestImage(for: self.asset,
                             targetSize: targetSize,
                             contentMode: .aspectFill,
                             options: nil) { image, _ in
            self.image = image
            completionHandler((image ?? UIImage(systemName: "photo"))!)
        }
    }
    
    func requestAVAsset(completionHandler: @escaping (AVURLAsset) -> Void) {
        let options = PHVideoRequestOptions()
        imageManager.requestAVAsset(forVideo: asset, options: options) { asset, _, _ in
            if let asset = asset as? AVURLAsset {
                completionHandler(asset)
            }
        }
    }
    
    func cancel() {
        guard let requestId else { return }
        manager.cancelImageRequest(requestId)
    }
    
    init(asset: PHAsset) {
        self.asset = asset
    }
}
