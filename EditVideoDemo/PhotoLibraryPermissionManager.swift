//
//  PhotoLibraryPermissionManager.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 28/03/2024.
//

import Photos

class PhotoLibraryPermissionManager {
    static func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let handler: (PHAuthorizationStatus) -> Void = { status in
            // print(status.description)
            switch status {
            case .authorized, .limited:
                completion(true)
            default:
                completion(false)
            }
        }
        
        func requestAuthorization() {
            PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: handler)
        }
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print(status.description)
        switch status {
        case .restricted, .notDetermined:
            requestAuthorization()
        default:
            handler(status)
        }
    }
    
    static var isAuthorized: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return false }
        return true
    }
}

extension PHAuthorizationStatus {
    var description: String {
        switch self {
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .limited: return "limited"
        case .notDetermined: return "not Determined"
        case .restricted: return "restricted"
        default: return "unknown"
        }
    }
}

