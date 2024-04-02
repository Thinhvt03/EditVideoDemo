//
//  CIFilterName.swift
//  EditVideoDemo
//
//  Created by Nguyễn Thịnh on 01/04/2024.
//

import Foundation

enum EffectName: String, CaseIterable {
    case sharpenLuminance = "CISharpenLuminance"
    case photoEffectChrome = "CIPhotoEffectChrome"
    case photoEffectFade = "CIPhotoEffectFade"
    case photoEffectInstant = "CIPhotoEffectInstant"
    case photoEffectNoir = "CIPhotoEffectNoir"
    case photoEffectProcess = "CIPhotoEffectProcess"
    case photoEffectTonal = "CIPhotoEffectTonal"
    case photoEffectTransfer = "CIPhotoEffectTransfer"
    case sepiaTone = "CISepiaTone"
    case colorClamp = "CIColorClamp"
    case colorInvert = "CIColorInvert"
    case colorMonochrome = "CIColorMonochrome"
    case spotLight = "CISpotLight"
    case colorPosterize = "CIColorPosterize"
    case boxBlur = "CIBoxBlur"
    case discBlur = "CIDiscBlur"
    case gaussianBlur = "CIGaussianBlur"
    case maskedVariableBlur = "CIMaskedVariableBlur"
    case medianFilter = "CIMedianFilter"
    case motionBlur = "CIMotionBlur"
    case noiseReduction = "CINoiseReduction"
    
    var name: String { rawValue }
}
