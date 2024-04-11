//
//  DocumentPickerView.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 06/04/2024.
//

import SwiftUI
import UIKit

struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var selectedAudioURL: URL?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> some UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        documentPicker.allowsMultipleSelection = false
        documentPicker.shouldShowFileExtensions = true
        documentPicker.delegate = context.coordinator
        
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            self.parent.selectedAudioURL = url
            self.parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

import ASAudioWaveformView

struct AudioWaveformView: UIViewRepresentable {
    @Binding var url: URL?
    @Binding var isLoading: Bool
    func makeUIView(context: Context) -> some UIView {
        let wave = ASAudioWaveformView()
        wave.createWaveform { config in
            config.audioURL(url).contentType(.singleLine).maxSamplesCount(300).fillColor(.green)
        } completion: { success in
            isLoading.toggle()
        }
        
        return wave
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}
