//
//  FrameInterpolationService.swift
//  VideoEnhnacer
//
//  Created by Vaibhav Tiwary on 26/08/25.
//

import Foundation
import SwiftUI
import Photos
import AVFoundation

// MARK: - Frame Interpolation Service
/// Service for server-based frame interpolation processing based on ContentShree.swift pattern
class FrameInterpolationService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var taskId: String = ""
    @Published var progress: Double = 0.0
    @Published var status: String = ""
    @Published var processedURL: String = ""
    @Published var originalURL: String = ""
    @Published var isUploading: Bool = false
    @Published var isPolling: Bool = false
    @Published var errorMessage: String = ""
    @Published var processedVideoURL: URL? = nil
    @Published var originalVideoURL: URL? = nil
    @Published var showSaveSuccess: Bool = false
    @Published var saveSuccessMessage: String = ""
    @Published var showSaveOptions: Bool = false
    @Published var isSaving: Bool = false
    
    // MARK: - Configuration
    private let baseURL = AppConfig.baseURL
    private var currentTimer: Timer?
    private var documentPickerDelegate: DocumentPickerDelegate?
    
    // MARK: - Public Methods
    
    /// Upload video for frame interpolation processing
    func uploadVideo(videoURL: URL, level: String) {
        isUploading = true
        errorMessage = ""
        status = "Uploading video..."
        progress = 0.1
        
        let endpoint = "/interpolation"
        var request = URLRequest(url: URL(string: baseURL + endpoint)!)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add level parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"level\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(level)\r\n".data(using: .utf8)!)
        
        // Add video file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        
        do {
            let videoData = try Data(contentsOf: videoURL)
            body.append(videoData)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to read video file: \(error.localizedDescription)"
                self.isUploading = false
            }
            return
        }
        
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isUploading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                if let data = data, 
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String], 
                   let id = json["task_id"] {
                    self.taskId = id
                    self.status = "Processing started..."
                    self.progress = 0.3
                    self.pollProgress()
                } else {
                    self.errorMessage = "Invalid response from server"
                }
            }
        }.resume()
    }
    
    /// Poll server for processing progress
    private func pollProgress() {
        isPolling = true
        currentTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            let url = URL(string: self.baseURL + "/progress/" + self.taskId)!
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        self.stopPolling()
                        return
                    }
                    if let data = data, 
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        self.status = json["status"] as? String ?? "Unknown"
                        self.progress = json["progress"] as? Double ?? 0.0
                        if self.status == "completed" {
                            self.getResult()
                            self.stopPolling()
                        } else if self.status == "failed" {
                            self.errorMessage = json["error"] as? String ?? "Unknown error"
                            self.stopPolling()
                        }
                    }
                }
            }.resume()
        }
    }
    
    /// Stop progress polling
    private func stopPolling() {
        currentTimer?.invalidate()
        currentTimer = nil
        isPolling = false
    }
    
    /// Get processing result from server
    private func getResult() {
        status = "Downloading result..."
        progress = 0.9
        
        let url = URL(string: baseURL + "/result/" + taskId)!
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                if let data = data, 
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    self.processedURL = json["processed_url"] ?? ""
                    self.originalURL = json["original_url"] ?? ""
                    
                    if !self.processedURL.isEmpty {
                        self.downloadProcessedVideo()
                    }
                    if !self.originalURL.isEmpty {
                        self.downloadOriginalVideo()
                    }
                    
                    self.status = "Completed!"
                    self.progress = 1.0
                } else {
                    self.errorMessage = "Invalid result from server"
                }
            }
        }.resume()
    }
    
    /// Download processed video from server
    private func downloadProcessedVideo() {
        guard let url = URL(string: baseURL + processedURL) else {
            errorMessage = "Invalid processed video URL"
            return
        }
        
        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Download failed: \(error.localizedDescription)"
                }
                return
            }
            
            if let tempURL = tempURL {
                let destURL = self.getDocumentsDirectory().appendingPathComponent("enhanced_video_\(UUID().uuidString).mp4")
                do {
                    try? FileManager.default.removeItem(at: destURL)
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    DispatchQueue.main.async {
                        self.processedVideoURL = destURL
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to save video: \(error.localizedDescription)"
                    }
                }
            }
        }.resume()
    }
    
    /// Download original video from server
    private func downloadOriginalVideo() {
        guard let url = URL(string: baseURL + originalURL) else { return }
        
        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let tempURL = tempURL {
                let destURL = self.getDocumentsDirectory().appendingPathComponent("original_video_\(UUID().uuidString).mp4")
                do {
                    try? FileManager.default.removeItem(at: destURL)
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    DispatchQueue.main.async {
                        self.originalVideoURL = destURL
                    }
                } catch {
                    print("Failed to save original video: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // MARK: - Save Methods
    
    /// Save video to Photos library
    func saveVideoToPhotos(_ videoURL: URL) {
        isSaving = true
        errorMessage = ""
        
        #if targetEnvironment(simulator)
        errorMessage = "Cannot save to Photos on simulator. Please use 'Save to Files' or 'Save to App Documents'."
        isSaving = false
        return
        #endif
        
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                    }) { success, error in
                        DispatchQueue.main.async {
                            self.isSaving = false
                            if success {
                                self.saveSuccessMessage = "Video saved to Photos successfully!"
                                self.showSaveSuccess = true
                            } else if let error = error {
                                self.errorMessage = "Failed to save video: \(error.localizedDescription)"
                            }
                        }
                    }
                } else {
                    self.isSaving = false
                    self.errorMessage = "Photo library access denied. Please enable access in Settings."
                }
            }
        }
    }
    
    /// Save video to Files app
    func saveVideoToFiles(_ videoURL: URL) {
        isSaving = true
        
        let picker = UIDocumentPickerViewController(forExporting: [videoURL], asCopy: true)
        documentPickerDelegate = DocumentPickerDelegate(
            onComplete: {
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.saveSuccessMessage = "Video saved to Files app successfully!"
                    self.showSaveSuccess = true
                }
            },
            onError: { error in
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.errorMessage = "Failed to save video: \(error?.localizedDescription ?? "Unknown error")"
                }
            }
        )
        picker.delegate = documentPickerDelegate
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(picker, animated: true)
        }
    }
    
    /// Save video to app documents directory
    func saveVideoToAppDocuments(_ videoURL: URL) {
        isSaving = true
        
        let destinationURL = getDocumentsDirectory().appendingPathComponent("saved_video_\(Date().timeIntervalSince1970).mp4")
        
        do {
            try FileManager.default.copyItem(at: videoURL, to: destinationURL)
            
            DispatchQueue.main.async {
                self.isSaving = false
                self.saveSuccessMessage = "Video saved to App Documents!\nPath: \(destinationURL.path)"
                self.showSaveSuccess = true
            }
        } catch {
            DispatchQueue.main.async {
                self.isSaving = false
                self.errorMessage = "Failed to save video: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Get documents directory
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Cancel current processing
    func cancelProcessing() {
        stopPolling()
        taskId = ""
        progress = 0.0
        status = ""
        errorMessage = ""
        isUploading = false
        isPolling = false
    }
    
    /// Reset service state
    func resetState() {
        cancelProcessing()
        processedURL = ""
        originalURL = ""
        processedVideoURL = nil
        originalVideoURL = nil
        showSaveSuccess = false
        saveSuccessMessage = ""
        showSaveOptions = false
        isSaving = false
    }
}

// MARK: - Supporting Types
// DocumentPickerDelegate is defined in ContentShree.swift and used throughout the app
