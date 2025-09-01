//
//  ContentView.swift
//  VideoEnhancementApp
//
//  Created by apple on 21/08/25.
//
import SwiftUI
import PhotosUI
import AVKit
import MobileCoreServices
import UIKit

struct ContentShree2: View {
    @State private var selectedVideo: URL? = nil
    @State private var enhancementType: String = "brightness"
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
    
    let baseURL = AppConfig.baseURL
    
    let enhancementTypes = ["brightness", "denoise", "face_enhance", "colorization", "stabilization", "interpolation", "upscale"]
    let levels = ["low", "medium", "high"]
    let upscaleLevels = ["1080", "2K", "4K"]
    let interpolationLevels = ["smooth", "fluid"]
    
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Enhancement Controls
                    VStack {
                        Picker("Enhancement Type", selection: $enhancementType) {
                            ForEach(enhancementTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: enhancementType) { _ in
                            // Reset level when enhancement type changes
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
                        
                        // Conditional Picker for level based on enhancement type
                        if enhancementType == "brightness" || enhancementType == "denoise" || enhancementType == "stabilization" {
                            Picker("Level", selection: $level) {
                                ForEach(levels, id: \.self) { lvl in
                                    Text(lvl).tag(lvl)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        } else if enhancementType == "upscale" {
                            Picker("Level", selection: $level) {
                                ForEach(upscaleLevels, id: \.self) { lvl in
                                    Text(lvl).tag(lvl)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        } else if enhancementType == "interpolation" {
                            Picker("Level", selection: $level) {
                                ForEach(interpolationLevels, id: \.self) { lvl in
                                    Text(lvl).tag(lvl)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
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
                            Text("Input Video")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VideoPlayer(player: AVPlayer(url: selectedVideo))
                                .frame(height: 200)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                    }
                    
                    // Process Button
                    Button("Upload and Enhance") {
                        uploadVideo()
                    }
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
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
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
                    
                    // Output Video Player
                    if let processedVideoURL = processedVideoURL {
                        VStack(alignment: .leading) {
                            Text("Enhanced Video")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VideoPlayer(player: AVPlayer(url: processedVideoURL))
                                .frame(height: 200)
                                .cornerRadius(10)
                                .padding(.horizontal)
                            
                            // Save Button
                            Button(action: { showSaveOptions = true }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Save Video")
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .scaleEffect(0.8)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal)
                            .disabled(isSaving)
                            .confirmationDialog("Save Video", isPresented: $showSaveOptions) {
                                Button("Save to Files App") { saveVideoToFiles(processedVideoURL) }
                                Button("Save to App Documents") { saveVideoToAppDocuments(processedVideoURL) }
                                #if !targetEnvironment(simulator)
                                Button("Save to Photos") { saveVideoToPhotos(processedVideoURL) }
                                #endif
                                Button("Cancel", role: .cancel) { }
                            }
                            .alert("Success", isPresented: $showSaveSuccess) {
                                Button("OK", role: .cancel) { }
                            } message: {
                                Text(saveSuccessMessage)
                            }
                        }
                    }
                    
//                    // Show saved videos location info
//                    if !getSavedVideos().isEmpty {
//                        VStack(alignment: .leading) {
//                            Text("Saved Videos")
//                                .font(.headline)
//                                .padding(.horizontal)
//
//                            Text("Videos are saved in: \(getDocumentsDirectory().path)")
//                                .font(.caption)
//                                .foregroundColor(.gray)
//                                .padding(.horizontal)
//
//                            ForEach(getSavedVideos(), id: \.self) { videoURL in
//                                HStack {
//                                    Text(videoURL.lastPathComponent)
//                                        .font(.caption)
//                                    Spacer()
//                                    Button("Open") {
//                                        openVideoInPlayer(videoURL)
//                                    }
//                                    .buttonStyle(.bordered)
//                                    .font(.caption)
//                                }
//                                .padding(.horizontal)
//                            }
//                        }
//                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Video Enhancement")
            .onAppear {
                if !taskId.isEmpty {
                    pollProgress()
                }
            }
        }
    }
    
    // MARK: - Video Processing Methods
    
    func uploadVideo() {
        isUploading = true
        errorMessage = ""
        status = "Uploading video..."
        progress = 0.1
        
        let endpoint = getEndpoint()
        var request = URLRequest(url: URL(string: baseURL + endpoint)!)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add level if required
        if enhancementType != "face_enhance" && enhancementType != "colorization" {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"level\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(level)\r\n".data(using: .utf8)!)
        }
        
        // Add video file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(try! Data(contentsOf: selectedVideo!))
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isUploading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: String], let id = json["task_id"] {
                    taskId = id
                    status = "Processing started..."
                    progress = 0.3
                    pollProgress()
                } else {
                    errorMessage = "Invalid response from server"
                }
            }
        }.resume()
    }
    
    func pollProgress() {
        isPolling = true
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            guard let url = URL(string: baseURL + "/progress/" + taskId) else {
                DispatchQueue.main.async {
                    errorMessage = "Invalid progress URL"
                    timer.invalidate()
                    isPolling = false
                }
                return
            }
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    // Handle network errors
                    if let error = error {
                        errorMessage = error.localizedDescription
                        timer.invalidate()
                        isPolling = false
                        return
                    }
                    
                    // Check HTTP status code
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 404 {
                            errorMessage = "Task not found on server"
                            timer.invalidate()
                            isPolling = false
                            return
                        }
                        if httpResponse.statusCode != 200 {
                            errorMessage = "Unexpected server response: \(httpResponse.statusCode)"
                            timer.invalidate()
                            isPolling = false
                            return
                        }
                    }
                    
                    // Parse JSON response
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Check for error field in JSON (e.g., {"error": "Task not found"})
                        if let errorMsg = json["error"] as? String {
                            errorMessage = errorMsg
                            timer.invalidate()
                            isPolling = false
                            return
                        }
                        
                        // Handle task status
                        status = json["status"] as? String ?? "Unknown"
                        progress = json["progress"] as? Double ?? 0.0
                        if status == "completed" {
                            getResult()
                            timer.invalidate()
                            isPolling = false
                        } else if status == "failed" {
                            errorMessage = json["error"] as? String ?? "Unknown error"
                            timer.invalidate()
                            isPolling = false
                        }
                    } else {
                        // Handle JSON parsing failure
                        errorMessage = "Failed to parse server response"
                        timer.invalidate()
                        isPolling = false
                    }
                }
            }.resume()
        }
    }
    
    func getResult() {
        status = "Downloading result..."
        progress = 0.9
        
        let url = URL(string: baseURL + "/result/" + taskId)!
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    processedURL = json["processed_url"] ?? ""
                    originalURL = json["original_url"] ?? ""
                    
                    if !processedURL.isEmpty {
                        downloadProcessedVideo()
                    }
                    if !originalURL.isEmpty {
                        downloadOriginalVideo()
                    }
                    
                    status = "Completed!"
                    progress = 1.0
                } else {
                    errorMessage = "Invalid result from server"
                }
            }
        }.resume()
    }
    
    func downloadProcessedVideo() {
        let url = URL(string: baseURL + processedURL)!
        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Download failed: \(error.localizedDescription)"
                }
                return
            }
            
            if let tempURL = tempURL {
                let destURL = getDocumentsDirectory().appendingPathComponent("enhanced_video_\(UUID().uuidString).mp4")
                do {
                    try? FileManager.default.removeItem(at: destURL)
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    DispatchQueue.main.async {
                        processedVideoURL = destURL
                    }
                } catch {
                    DispatchQueue.main.async {
                        errorMessage = "Failed to save video: \(error.localizedDescription)"
                    }
                }
            }
        }.resume()
    }
    
    func downloadOriginalVideo() {
        let url = URL(string: baseURL + originalURL)!
        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let tempURL = tempURL {
                let destURL = getDocumentsDirectory().appendingPathComponent("original_video_\(UUID().uuidString).mp4")
                do {
                    try? FileManager.default.removeItem(at: destURL)
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    DispatchQueue.main.async {
                        originalVideoURL = destURL
                    }
                } catch {
                    print("Failed to save original video: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // MARK: - Video Saving Methods
    
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
                            isSaving = false
                            if success {
                                saveSuccessMessage = "Video saved to Photos successfully!"
                                showSaveSuccess = true
                            } else if let error = error {
                                errorMessage = "Failed to save video: \(error.localizedDescription)"
                            }
                        }
                    }
                } else {
                    isSaving = false
                    errorMessage = "Photo library access denied. Please enable access in Settings."
                }
            }
        }
    }
    
    func saveVideoToFiles(_ videoURL: URL) {
            isSaving = true
            
            let picker = UIDocumentPickerViewController(forExporting: [videoURL], asCopy: true)
            documentPickerDelegate = DocumentPickerDelegate(
                onComplete: {
                    DispatchQueue.main.async {
                        isSaving = false
                        saveSuccessMessage = "Video saved to Files app successfully!"
                        showSaveSuccess = true
                    }
                },
                onError: { error in
                    DispatchQueue.main.async {
                        isSaving = false
                        errorMessage = "Failed to save video: \(error?.localizedDescription ?? "Unknown error")"
                    }
                }
            )
            picker.delegate = documentPickerDelegate
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(picker, animated: true)
            }
        }
    
    func saveVideoToAppDocuments(_ videoURL: URL) {
        isSaving = true
        
        let destinationURL = getDocumentsDirectory().appendingPathComponent("saved_video_\(Date().timeIntervalSince1970).mp4")
        
        do {
            try FileManager.default.copyItem(at: videoURL, to: destinationURL)
            
            DispatchQueue.main.async {
                isSaving = false
                saveSuccessMessage = "Video saved to App Documents!\nPath: \(destinationURL.path)"
                showSaveSuccess = true
                
                // Refresh the saved videos list
                _ = getSavedVideos()
            }
        } catch {
            DispatchQueue.main.async {
                isSaving = false
                errorMessage = "Failed to save video: \(error.localizedDescription)"
            }
        }
    }
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func getSavedVideos() -> [URL] {
        let documentsURL = getDocumentsDirectory()
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension.lowercased() == "mp4" }
        } catch {
            return []
        }
    }
    
    func openVideoInPlayer(_ videoURL: URL) {
        let player = AVPlayer(url: videoURL)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(playerViewController, animated: true) {
                player.play()
            }
        }
    }
    
    func getEndpoint() -> String {
        switch enhancementType {
        case "brightness":
            return "/brightness"
        case "denoise":
            return "/denoise"
        case "face_enhance":
            return "/face_enhance"
        case "colorization":
            return "/colorization"
        case "stabilization":
            return "/stabilization"
        case "interpolation":
            return "/interpolation"
        case "upscale":
            return "/upscale"
        default:
            return ""
        }
    }
}

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideo: URL?
    @Environment(\.presentationMode) var presentationMode
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else { return }
            provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                if let error = error {
                    print("Error loading video: \(error.localizedDescription)")
                    return
                }
                guard let sourceURL = url else {
                    print("No URL provided by item provider")
                    return
                }
                let destination = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mp4")
                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                    DispatchQueue.main.async {
                        self.parent.selectedVideo = destination
                    }
                } catch {
                    print("Error copying video file: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    ContentShree2()
}
