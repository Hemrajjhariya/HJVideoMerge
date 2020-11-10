//
//  ViewController.swift
//  HJVideoMerge
//
//  Created by Nikhil Grover on 09/11/20.
//  Copyright © 2020 Hemraj Jhariya. All rights reserved.
//

import UIKit
import Photos
import AVKit

class ViewController: UIViewController {
    
    var config = TatsiConfig.default
    
    private let message = "message"
    private let oK = "OK"
    private let saveVideo = "Save"
    private let videoAlert = "Select only two video"
    private let imageAlert = "Select more then 5 images"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    @IBAction private func imageAndVideoPicker(sender: UIButton!){
        let tagNo: Int = sender.tag
        if tagNo == 0{
            config.supportedMediaTypes = [.image]
            config.typeVideo = "image"
        }else{
            config.supportedMediaTypes = [.video]
            config.typeVideo = "video"
        }
        config.singleViewMode = true
        config.showCameraOption = true
        let pickerViewController = TatsiPickerViewController(config: config)
        pickerViewController.pickerDelegate = self
        self.present(pickerViewController, animated: true, completion: nil)
    }
    
}

// MARK:- Picker image and video 
extension ViewController: TatsiPickerViewControllerDelegate {
    
    func pickerViewController(_ pickerViewController: TatsiPickerViewController, didPickAssets assets: [PHAsset]) {
         
        pickerViewController.dismiss(animated: true, completion: nil)
        LoadingView.lockView()
        
        if config.typeVideo == "video"{
            //this validation for 2 video only
            if assets.count == 2 {
                var videoURLs: [AVURLAsset] = []
                for path in assets {
                    path.requestContentEditingInput(with: PHContentEditingInputRequestOptions(), completionHandler: { (contentEditingInput, dictInfo) in
                        if let strURL = (contentEditingInput!.avAsset as? AVURLAsset) {
                            videoURLs.append(strURL)
                        }
                    })
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    if videoURLs.count > 1{
                        self.merge(firstAsset: videoURLs[0], secondAsset: videoURLs[1])
                    }
                }
            }else{
                pickerViewController.dismiss(animated: true, completion: nil)
                self.createAlertView(message: self.videoAlert)
            }
            
        }else{
            
            guard assets.count > 6 else {
                pickerViewController.dismiss(animated: true, completion: nil)
                self.createAlertView(message: self.imageAlert)
                return
            }
          
            for n in 1...2 {
                if n == 1{
                    var video1 : [PHAsset] = []
                    for n in 0...4 {
                        video1.append(assets[n])
                    }
                    
                    VideoGenerator.fileName = "video1"
                    VideoGenerator.shouldOptimiseImageForVideo = false
                    VideoGenerator.videoDurationInSeconds = 125
                    VideoGenerator.maxVideoLengthInSeconds = 10000
                    
                    DispatchQueue.global(qos: .background).async {
                        VideoGenerator.current.generate(withImages:self.getAssetThumbnail(assets: video1), andType: .singleAudioMultipleImage, { (progress) in
                            print(progress)
                        }) { (result) in
                            
                            switch result {
                            case .success(let url):
                                print(url)
                               // self.createAlertView(message: self.saveVideo1)
                            case .failure(let error):
                                print(error)
                                ///  self.createAlertView(message: error.localizedDescription)
                            }
                            pickerViewController.dismiss(animated: true, completion: nil)
                        }
                    }
                    
                }else if n == 2{
                    
                    var video2 : [PHAsset] = []
                    for n in 5...assets.count-1 {
                        video2.append(assets[n])
                    }
                    
                    VideoGenerator.fileName = "video2"
                    VideoGenerator.shouldOptimiseImageForVideo = false
                    //VideoGenerator.videoDurationInSeconds = 5
                    VideoGenerator.maxVideoLengthInSeconds = 10000
                    VideoGenerator.videoDurationInSeconds = 25
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        
                        VideoGenerator.current.generate(withImages:self.getAssetThumbnail(assets: video2), andType: .singleAudioMultipleImage, { (progress) in
                            print(progress)
                        }) { (result) in
                            LoadingView.unlockView()
                            switch result {
                            case .success(let url):
                                print(url)
                                self.createAlertView(message: self.saveVideo)
                            case .failure(let error):
                                print(error)
                            }
                        }
                    }
                }else{
                    pickerViewController.dismiss(animated: true, completion: nil)
                    self.createAlertView(message: self.imageAlert)
                }
            }
        }
    }
}

// MARK: Merge video
extension ViewController {
    func merge(firstAsset: AVAsset?, secondAsset: AVAsset?) {
        guard
            let firstAsset = firstAsset,
            let secondAsset = secondAsset
            else { return }
        
        // activityMonitor.startAnimating()
        
        // - Create AVMutableComposition object. This object
        // will hold your AVMutableCompositionTrack instances.
        let mixComposition = AVMutableComposition()
        
        //- Create two video tracks
        guard
            let firstTrack = mixComposition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            else { return }
        
        do {
            try firstTrack.insertTimeRange(
                CMTimeRangeMake(start: .zero, duration: firstAsset.duration),
                of: firstAsset.tracks(withMediaType: .video)[0],
                at: .zero)
        } catch {
            print("Failed to load first track")
            return
        }
        
        guard
            let secondTrack = mixComposition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            else { return }
        
        do {
            try secondTrack.insertTimeRange(
                CMTimeRangeMake(start: .zero, duration: secondAsset.duration),
                of: secondAsset.tracks(withMediaType: .video)[0],
                at: firstAsset.duration)
        } catch {
            print("Failed to load second track")
            return
        }
        
        // - Composition Instructions
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(
            start: .zero,
            duration: CMTimeAdd(firstAsset.duration, secondAsset.duration))
        
        // 4 - Set up the instructions — one for each asset
        let firstInstruction = VideoHelper.videoCompositionInstruction(
            firstTrack,
            asset: firstAsset)
        firstInstruction.setOpacity(0.0, at: firstAsset.duration)
        let secondInstruction = VideoHelper.videoCompositionInstruction(
            secondTrack,
            asset: secondAsset)
        
        // - Add all instructions together and create a mutable video composition
        mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = CGSize(
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height)
        
        //- Get path
        guard
            let documentDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask).first
            else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let date = dateFormatter.string(from: Date())
        let url = documentDirectory.appendingPathComponent("mergeVideo-\(date).mov")
        
        // 8 - Create Exporter
        guard let exporter = AVAssetExportSession(
            asset: mixComposition,
            presetName: AVAssetExportPresetHighestQuality)
            else { return }
        exporter.outputURL = url
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = mainComposition
        
        // 9 - Perform the Export
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                self.exportDidFinish(exporter,firstAsset:firstAsset,secondAsset: secondAsset )
            }
        }
    }
    
    func exportDidFinish(_ session: AVAssetExportSession,firstAsset: AVAsset?, secondAsset: AVAsset?) {
        // Cleanup assets
        // activityMonitor.stopAnimating()
        
        guard
            let firstAsset = firstAsset,
            let secondAsset = secondAsset
            else { return }
        // firstAsset = nil
        // secondAsset = nil
        // audioAsset = nil
        
        guard
            session.status == AVAssetExportSession.Status.completed,
            let outputURL = session.outputURL
            else { return }
        
        let saveVideoToPhotos = {
            let changes: () -> Void = {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
            }
            PHPhotoLibrary.shared().performChanges(changes) { saved, error in
                DispatchQueue.main.async {
                    let success = saved && (error == nil)
                    let title = success ? "Success" : "Error"
                    let message = success ? "Video saved" : "Failed to save video"
                    
                    let alert = UIAlertController(
                        title: title,
                        message: message,
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(
                        title: "OK",
                        style: UIAlertAction.Style.cancel,
                        handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        
        // Ensure permission to access Photo Library
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    saveVideoToPhotos()
                    LoadingView.unlockView()
                }
            }
        } else {
            saveVideoToPhotos()
            LoadingView.unlockView()
        }
    }
}

// MARK:-
extension ViewController {
    
    fileprivate func createAlertView(message: String?) {
        let messageAlertController = UIAlertController(title: message, message: message, preferredStyle: .alert)
        messageAlertController.addAction(UIAlertAction(title: oK, style: .default, handler: { (action: UIAlertAction!) in
            messageAlertController.dismiss(animated: true, completion: nil)
        }))
        DispatchQueue.main.async { [weak self] in
            self?.present(messageAlertController, animated: true, completion: nil)
        }
    }
    
    //MARK: Convert array of PHAsset to UIImages
    func getAssetThumbnail(assets: [PHAsset]) -> [UIImage] {
        var arrayOfImages = [UIImage]()
        for asset in assets {
            let manager = PHImageManager.default()
            let option = PHImageRequestOptions()
            var image = UIImage()
            option.isSynchronous = true
            manager.requestImage(for: asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFit, options: option, resultHandler: {(result, info)->Void in
                image = result!
                arrayOfImages.append(image)
            })
        }
        return arrayOfImages
    }
    
}


