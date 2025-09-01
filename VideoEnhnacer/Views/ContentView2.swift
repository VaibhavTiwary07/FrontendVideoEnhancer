import SwiftUI
import PhotosUI
import AVKit
import UIKit
import Foundation
import OSLog

struct ContentView2: View {
    @State private var selectedVideo: URL? = nil
    @State private var enhancementType: String = "colorization"
    @State private var level: String = "medium"
    @State private var taskId: String = ""
    @State private var progress: Double = 0.0
    @State private var status: String = ""
    @State private var processedURL: String = ""
    @State private var originalURL: String = ""
    @State private var isUploading = false
    @State private var isPolling = false
    @State private var errorMessage: String = ""
    @State private var showVideoPicker = false
    @State private var processedVideoURL: URL? = nil
    @State private var originalVideoURL: URL? = nil
    @State private var showSaveSuccess = false
    @State private var saveSuccessMessage = ""
    @State private var showSaveOptions = false
    @State private var isSaving = false
    @State private var documentPickerDelegate: DocumentPickerDelegate?
    @State private var showExportOptions = false
    @State private var selectedResolution = "1080p"
    @State private var selectedFrameRate = "30fps"
    @State private var selectedFormat = "MP4"

    private let baseURL = AppConfig.baseURL

    private let enhancementTypes = ["brightness", "denoise", "face_enhance", "colorization", "stabilization", "interpolation", "upscale"]
    private let levels = ["low", "medium", "high"]
    private let upscaleLevels = ["1080", "2K", "4K"]
    private let interpolationLevels = ["smooth", "fluid"]

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        enhancementControls
                        
                        // Video Selection
                        Button(action: { showVideoPicker = true }) {
                            HStack {
                                Image(systemName: "video.fill")
                                Text(selectedVideo == nil ? "Select Video" : "Video Selected: \(selectedVideo!.lastPathComponent)")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .sheet(isPresented: $showVideoPicker) {
                            VideoPicker(selectedVideo: $selectedVideo)
                        }
                        
                        // Input Video Player
                        if let selectedVideo = selectedVideo {
                            VStack(alignment: .leading) {
                                Text("Input Video").font(.headline).padding(.horizontal)
                                VideoPlayer(player: AVPlayer(url: selectedVideo))
                                    .frame(height: 200)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Process Button
                        Button("Upload and Enhance") { uploadVideo() }
                            .buttonStyle(.borderedProminent)
                            .disabled(selectedVideo == nil || isUploading)
                            .frame(maxWidth: .infinity)
                        
                        // Progress View
                        if isUploading || isPolling {
                            VStack {
                                ProgressView(value: progress, total: 1.0) {
                                    HStack {
                                        Text(status)
                                        Spacer()
                                        Text("\(Int(progress * 100))%")
                                    }
                                }
                                if progress > 0 && progress < 1.0 {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle())
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        // Error Message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        // Output Video Player + Export
                        if let processedVideoURL = processedVideoURL {
                            outputVideoSection(processedVideoURL: processedVideoURL)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                
                if showExportOptions, let processedURL = processedVideoURL {
                    ExportOptionsView(
                        isPresented: $showExportOptions,
                        selectedResolution: $selectedResolution,
                        selectedFrameRate: $selectedFrameRate,
                        selectedFormat: $selectedFormat,
                        onExport: { },
                        videoURL: processedURL,
                        onCompleted: { url in
                            // Update current processed video to exported video
                            self.processedVideoURL = url
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .navigationTitle("Video Enhancement")
            .onAppear {
                if !taskId.isEmpty { pollProgress() }
            }
            .confirmationDialog("Save Video", isPresented: $showSaveOptions) {
                if let url = processedVideoURL {
                    Button("Save to Files App") { saveVideoToFiles(url) }
                    Button("Save to App Documents") { saveVideoToAppDocuments(url) }
                    #if !targetEnvironment(simulator)
                    Button("Save to Photos") { saveVideoToPhotos(url) }
                    #endif
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Success", isPresented: $showSaveSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveSuccessMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var enhancementControls: some View {
        VStack {
            Picker("Enhancement Type", selection: $enhancementType) {
                ForEach(enhancementTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: enhancementType) { _ in
                if enhancementType == "interpolation" {
                    level = interpolationLevels[0]
                } else if enhancementType == "upscale" {
                    level = upscaleLevels[0]
                } else if enhancementType == "face_enhance" || enhancementType == "colorization" {
                    level = ""
                } else {
                    level = levels[0]
                }
            }
            
            if enhancementType == "brightness" || enhancementType == "denoise" || enhancementType == "stabilization" {
                Picker("Level", selection: $level) {
                    ForEach(levels, id: \.self) { lvl in Text(lvl).tag(lvl) }
                }.pickerStyle(SegmentedPickerStyle())
            } else if enhancementType == "upscale" {
                Picker("Level", selection: $level) {
                    ForEach(upscaleLevels, id: \.self) { lvl in Text(lvl).tag(lvl) }
                }.pickerStyle(SegmentedPickerStyle())
            } else if enhancementType == "interpolation" {
                Picker("Level", selection: $level) {
                    ForEach(interpolationLevels, id: \.self) { lvl in Text(lvl).tag(lvl) }
                }.pickerStyle(SegmentedPickerStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    // MARK: - View Builder Methods
    @ViewBuilder
    private func outputVideoSection(processedVideoURL: URL) -> some View {
        VStack(alignment: .leading) {
            Text("Enhanced Video").font(.headline).padding(.horizontal)
            VideoPlayer(player: AVPlayer(url: processedVideoURL))
                .frame(height: 200)
                .cornerRadius(10)
                .padding(.horizontal)
            
            HStack {
                Button(action: { showSaveOptions = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save")
                        if isSaving { ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(0.8) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isSaving)
                
                Button(action: { showExportOptions = true }) {
                    Text("Export").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isSaving)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Video Processing Methods
    private func uploadVideo() {
        isUploading = true
        errorMessage = ""
        status = "Uploading video..."
        progress = 0.1

        let endpoint = getEndpoint()
        guard let selectedVideo = selectedVideo else { return }
        guard let url = URL(string: baseURL + endpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        if enhancementType != "face_enhance" && enhancementType != "colorization" {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"level\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(level)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        if let data = try? Data(contentsOf: selectedVideo) {
            body.append(data)
        }
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isUploading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: String], let id = json["task_id"] {
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

    private func pollProgress() {
        isPolling = true
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            guard let url = URL(string: baseURL + "/progress/" + self.taskId) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Invalid progress URL"
                    timer.invalidate()
                    self.isPolling = false
                }
                return
            }
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        timer.invalidate()
                        self.isPolling = false
                        return
                    }
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 404 {
                            self.errorMessage = "Task not found on server"
                            timer.invalidate()
                            self.isPolling = false
                            return
                        }
                        if httpResponse.statusCode != 200 {
                            self.errorMessage = "Unexpected server response: \(httpResponse.statusCode)"
                            timer.invalidate()
                            self.isPolling = false
                            return
                        }
                    }
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let errorMsg = json["error"] as? String {
                            self.errorMessage = errorMsg
                            timer.invalidate()
                            self.isPolling = false
                            return
                        }
                        self.status = json["status"] as? String ?? "Unknown"
                        self.progress = json["progress"] as? Double ?? 0.0
                        if self.status == "completed" {
                            self.getResult()
                            timer.invalidate()
                            self.isPolling = false
                        } else if self.status == "failed" {
                            self.errorMessage = json["error"] as? String ?? "Unknown error"
                            timer.invalidate()
                            self.isPolling = false
                        }
                    } else {
                        self.errorMessage = "Failed to parse server response"
                        timer.invalidate()
                        self.isPolling = false
                    }
                }
            }.resume()
        }
    }

    private func getResult() {
        status = "Downloading result..."
        progress = 0.9
        let url = URL(string: baseURL + "/result/" + taskId)!
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error { self.errorMessage = error.localizedDescription; return }
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    self.processedURL = json["processed_url"] ?? ""
                    self.originalURL = json["original_url"] ?? ""
                    if !self.processedURL.isEmpty { self.downloadProcessedVideo() }
                    if !self.originalURL.isEmpty { self.downloadOriginalVideo() }
                    self.status = "Completed!"
                    self.progress = 1.0
                } else {
                    self.errorMessage = "Invalid result from server"
                }
            }
        }.resume()
    }

    private func downloadProcessedVideo() {
        let url = URL(string: baseURL + processedURL)!
        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "Download failed: \(error.localizedDescription)" }
                return
            }
            if let tempURL = tempURL {
                let destURL = getDocumentsDirectory().appendingPathComponent("enhanced_video_\(UUID().uuidString).mp4")
                do {
                    try? FileManager.default.removeItem(at: destURL)
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    DispatchQueue.main.async { self.processedVideoURL = destURL }
                } catch {
                    DispatchQueue.main.async { self.errorMessage = "Failed to save video: \(error.localizedDescription)" }
                }
            }
        }.resume()
    }

    private func downloadOriginalVideo() {
        let url = URL(string: baseURL + originalURL)!
        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let tempURL = tempURL {
                let destURL = getDocumentsDirectory().appendingPathComponent("original_video_\(UUID().uuidString).mp4")
                do {
                    try? FileManager.default.removeItem(at: destURL)
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    DispatchQueue.main.async { self.originalVideoURL = destURL }
                } catch {
                    print("Failed to save original video: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    // MARK: - Video Saving Methods
    private func saveVideoToPhotos(_ videoURL: URL) {
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

    private func saveVideoToFiles(_ videoURL: URL) {
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

    private func saveVideoToAppDocuments(_ videoURL: URL) {
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

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func getEndpoint() -> String {
        switch enhancementType {
        case "brightness": return "/brightness"
        case "denoise": return "/denoise"
        case "face_enhance": return "/face_enhance"
        case "colorization": return "/colorization"
        case "stabilization": return "/stabilization"
        case "interpolation": return "/interpolation"
        case "upscale": return "/upscale"
        default: return ""
        }
    }
}

#Preview {
    ContentView2()
}
