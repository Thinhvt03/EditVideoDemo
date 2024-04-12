//
//  AVPlayerView.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 11/04/2024.
//

import SwiftUI
import AVKit

struct AVPlayerView: UIViewControllerRepresentable {
    @Binding var player: AVPlayer?
    @Binding var isChangedPlayer: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerView = AVPlayerViewController()
        playerView.player = player
        player?.play()
        return playerView
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if isChangedPlayer {
            uiViewController.player = player
            player?.play()
            DispatchQueue.main.async {
                isChangedPlayer = false
            }
        }
    }
}
