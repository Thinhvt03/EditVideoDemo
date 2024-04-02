//
//  EditVideoDemoApp.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 28/03/2024.
//

import SwiftUI

@main
struct EditVideoDemoApp: App {
    @StateObject private var photoLibraryManager = PhotoLibraryManager()
    var body: some Scene {
        WindowGroup {
            NavigationView {
                VideoCollection()
                    .environmentObject(photoLibraryManager)
            }
        }
    }
}
