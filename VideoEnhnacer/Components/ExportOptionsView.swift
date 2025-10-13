import SwiftUI
import OSLog
import UIKit
import Photos
import Combine
import AVFoundation

struct ExportOptionsView: View {
    @Environment(\.diContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    @Binding var selectedResolution: String
    @Binding var selectedFrameRate: String
    @Binding var selectedFormat: String
    let onExport: () -> Void
    let videoURL: URL
    let onCompleted: (URL) -> Void
    
    private let resolutionOptions = ["original", "2x","4x"]
    private let frameRateOptions = ["30fps", "60fps"]
    private let formatOptions = ["MP4", "MOV"]

    // Local export state
    @State private var isExporting: Bool = false
    @State private var exportError: String? = nil
    @State private var showError: Bool = false
    @State private var showFinalPage: Bool = false
    @State private var exportProgress: Double = 0.0
    @State private var isExportComplete: Bool = false
    @State private var exportedVideoURL: URL? = nil
    @State private var showSavedAlert: Bool = false
    @State private var savedAlertMessage: String = ""
    // One-shot guard to prevent duplicate Home ad intents during navigation
    @State private var homeAdIntentPosted: Bool = false
    
    private var estimatedSize: String {
        let baseSize: Double
        let formatMultiplier: Double
        let resolutionMultiplier: Double
        let frameRateMultiplier: Double
        
        // Base size in MB for 1 minute of video
        baseSize = 50
        
        // Format multipliers
        switch selectedFormat {
        case "MP4": formatMultiplier = 1.0
        case "MOV": formatMultiplier = 1.2
        default: formatMultiplier = 1.0
        }
        
        // Resolution multipliers
        switch selectedResolution {
        case "4x": resolutionMultiplier = 4.0
        case "2x": resolutionMultiplier = 2.0
        default: resolutionMultiplier = 1.0
        }
        
        // Frame rate multipliers
        switch selectedFrameRate {
        case "30fps": frameRateMultiplier = 1.0
        case "60fps": frameRateMultiplier = 1.6
        default: frameRateMultiplier = 1.0
        }
        
        let totalSize = baseSize * formatMultiplier * resolutionMultiplier * frameRateMultiplier
        
        if totalSize < 1024 {
            return String(format: "%.0f MB", totalSize)
        } else {
            return String(format: "%.1f GB", totalSize / 1024)
        }
    }
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if !showFinalPage {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                }
            
            if showFinalPage {
                finalPage
            } else {
                exportOptionsPage
            }
        }
        .alert("Export Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError ?? "Unknown error")
        }
        .alert("Saved to Photos", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(savedAlertMessage)
        }
    }
    
    @ViewBuilder
    private var exportOptionsPage: some View {
        VStack {
            HStack {
                Spacer()
                
                // Export options panel
                    VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Export Options")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            // Just close the export overlay - stay on results view
                            withAnimation(.easeOut(duration: 0.3)) {
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                    }
                    .padding(.bottom, 10)
                    
                    // Resolution Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Resolution")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            ForEach(resolutionOptions, id: \.self) { option in
                                optionButton(
                                    title: option,
                                    isSelected: selectedResolution == option,
                                    action: { selectedResolution = option }
                                )
                            }
                            Spacer()
                        }
                    }
                    
                    // Frame Rate Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Frame Rate")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            ForEach(frameRateOptions, id: \.self) { option in
                                optionButton(
                                    title: option,
                                    isSelected: selectedFrameRate == option,
                                    action: { selectedFrameRate = option }
                                )
                            }
                            Spacer()
                        }
                    }
                    
                    // Format Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Format")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            ForEach(formatOptions, id: \.self) { option in
                                optionButton(
                                    title: option,
                                    isSelected: selectedFormat == option,
                                    action: { selectedFormat = option }
                                )
                            }
                            Spacer()
                        }
                    }
                    
                    // Estimated Size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated Size")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(estimatedSize)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    
                    // Export Button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showFinalPage = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                            Text(isExporting ? "Exporting..." : "Export")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient.primaryTheme)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented)
                    .disabled(isExporting)
                }
                .padding(24)
                .frame(width: 280)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(LinearGradient.primaryTheme.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 20, x: -5, y: 0)
                .padding(.trailing, 16)
                .padding(.top, 60) // Position at top
                }
                Spacer()
            }
        }
    }
    
    private func optionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .background(buttonBackground(isSelected: isSelected))
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func buttonBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient.primaryTheme)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
    }

// MARK: - Export Integration (iOS 15 friendly)
extension ExportOptionsView {
    @ViewBuilder
    var finalPage: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    let isSmall = DeviceSize.isSmallPhone
                    let playerHeight = isSmall ? max(240, geo.size.height * 0.52) : max(360, geo.size.height * 0.72)
                    let gravity: AVLayerVideoGravity = isSmall ? .resizeAspectFill : .resizeAspect

                    ZStack {
                        if let exportedVideoURL = exportedVideoURL {
                            VideoPreviewView(videoURL: exportedVideoURL, videoGravity: gravity)
                                .frame(height: playerHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: playerHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if !isExportComplete {
                            ZStack {
                                Color.black.opacity(0.6)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                VStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                                            .frame(width: 60, height: 60)
                                        Circle()
                                            .trim(from: 0, to: exportProgress)
                                            .stroke(
                                                LinearGradient.primaryTheme,
                                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                            )
                                            .frame(width: 60, height: 60)
                                            .rotationEffect(.degrees(-90))
                                            .animation(.easeInOut(duration: 0.3), value: exportProgress)
                                    }
                                    Text("Exporting...")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(height: playerHeight)
                        }
                    }
                    .padding(.horizontal, 20)

                    HStack(spacing: 8) {
                        Text("\(selectedResolution)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.2))
                            )
                        Text("\(selectedFrameRate)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.2))
                            )
                        Text("\(selectedFormat)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 0)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showFinalPage = false
                        exportProgress = 0.0
                        isExportComplete = false
                        exportedVideoURL = nil
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(Color.black.opacity(0.25)))
                }
                Spacer()
                Text("Export Preview")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { goHomeFromFinalPage() }) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(Color.black.opacity(0.25)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .background(Color.clear)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(action: { saveToPhotos() }) {
                    HStack {
                        Image(systemName: "photo.badge.plus").font(.system(size: 16, weight: .semibold))
                        Text("Save to Photos").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(isExportComplete ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isExportComplete ? AnyShapeStyle(LinearGradient.primaryTheme) : AnyShapeStyle(Color.white.opacity(0.2)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .disabled(!isExportComplete)
                .scaleEffect(isExportComplete ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExportComplete)

                Button(action: { shareVideo() }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .semibold))
                        Text("Share").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(isExportComplete ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isExportComplete ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .disabled(!isExportComplete)
                .scaleEffect(isExportComplete ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExportComplete)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            //.background(.ultraThinMaterial)
        }
        .onAppear { startFinalPageExport() }
    }

    // Centralized handler for going home from the FinalPage toolbar button
    private func goHomeFromFinalPage() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        os_log("[ExportOptionsView] Home (toolbar) tapped → broadcast goHome, request Home ad", log: OSLog.default, type: .debug)
        let performNavigation = {
            NotificationCenter.default.post(name: .goHomeRequested, object: nil)
            container.navigation.dismissCurrentModal()
            container.navigation.goToHome()
            dismiss()
            withAnimation(.easeOut(duration: 0.3)) { isPresented = false }
            if !homeAdIntentPosted {
                homeAdIntentPosted = true
                let delay: Double
                if #available(iOS 16.0, *) { delay = 0.75 } else { delay = 1.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    NotificationCenter.default.post(name: .homeAdRequested, object: nil)
                }
            }
        }

        if #available(iOS 16.0, *) {
            if let top = UIHelpers.topViewController(), top.presentedViewController != nil {
                top.dismiss(animated: true) { performNavigation() }
            } else {
                performNavigation()
            }
        } else {
            UIHelpers.dismissAllPresented(animated: true) { performNavigation() }
        }
    }
    
    private func startExport() {
        guard !isExporting else { return }
        isExporting = true
        exportError = nil

        exportVideo(videoURL: videoURL, resolution: selectedResolution, fps: selectedFrameRate, format: selectedFormat) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tempURL):
                    os_log("Export succeeded: %@", log: OSLog.default, type: .debug, tempURL.absoluteString)
                    withAnimation(.easeOut(duration: 0.25)) {
                        isPresented = false
                    }
                    onCompleted(tempURL)
                case .failure(let error):
                    os_log("Export failed: %@", log: OSLog.default, type: .error, error.localizedDescription)
                    exportError = error.localizedDescription
                    showError = true
                }
                isExporting = false
            }
        }
    }

    // Multipart upload to server which returns exported video data
    // Saves received data to a temporary file and returns its URL
    private func exportVideo(videoURL: URL, resolution: String, fps: String, format: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let endpoint = AppConfig.baseURL + "/export"
        guard let url = URL(string: endpoint) else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid export URL: \(endpoint)"])
            os_log("Invalid export URL: %@", log: OSLog.default, type: .error, endpoint)
            completion(.failure(error))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Create multipart form-data body
        var body = Data()
        
        // Add resolution field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"resolution\"\r\n\r\n\(resolution)\r\n".data(using: .utf8)!)
        
        // Add fps field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"fps\"\r\n\r\n\(fps)\r\n".data(using: .utf8)!)
        
        // Add format field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"format\"\r\n\r\n\(format)\r\n".data(using: .utf8)!)
        
        // Add video file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        let fileExt = (videoURL.pathExtension.isEmpty ? format : videoURL.pathExtension).lowercased()
        let mime = mimeType(for: fileExt)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"video.\(fileExt)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        do {
            let videoData = try Data(contentsOf: videoURL)
            body.append(videoData)
        } catch {
            os_log("Failed to read video file: %@", log: OSLog.default, type: .error, error.localizedDescription)
            completion(.failure(error))
            return
        }
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        // Perform the upload
        os_log("Starting video export to %@ with resolution=%@, fps=%@, format=%@", log: OSLog.default, type: .debug, url.absoluteString, resolution, fps, format)
        URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            if let error = error {
                os_log("Network error during export: %@", log: OSLog.default, type: .error, error.localizedDescription)
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
                os_log("Invalid server response for export to %@", log: OSLog.default, type: .error, url.absoluteString)
                completion(.failure(error))
                return
            }

            os_log("HTTP status %d for export to %@", log: OSLog.default, type: .debug, httpResponse.statusCode, url.absoluteString)
            if httpResponse.statusCode != 200 {
                let errorMsg: String
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let serverError = json["error"] as? String {
                    errorMsg = serverError
                } else {
                    errorMsg = "Unexpected server response: \(httpResponse.statusCode)"
                }
                let error = NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                os_log("Export failed: %@", log: OSLog.default, type: .error, errorMsg)
                completion(.failure(error))
                return
            }

            guard let data = data else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received from server"])
                os_log("No data received from server for export to %@", log: OSLog.default, type: .error, url.absoluteString)
                completion(.failure(error))
                return
            }

            // Save the downloaded video to a temporary file
            let ext = fileExt.isEmpty ? format.lowercased() : fileExt
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("exported_video.\(ext)")
            do {
                try data.write(to: tempURL)
                os_log("Exported video saved to: %@", log: OSLog.default, type: .debug, tempURL.absoluteString)
                completion(.success(tempURL))
            } catch {
                os_log("Failed to save exported video: %@", log: OSLog.default, type: .error, error.localizedDescription)
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func startFinalPageExport() {
        guard !isExporting else { return }
        isExporting = true
        exportError = nil
        exportProgress = 0.0
        isExportComplete = false
        
        // Simulate progress updates
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            DispatchQueue.main.async {
                if self.exportProgress < 1.0 {
                    self.exportProgress += 0.02 // Increment progress
                } else {
                    timer.invalidate()
                }
            }
        }

        exportVideo(videoURL: videoURL, resolution: selectedResolution, fps: selectedFrameRate, format: selectedFormat) { result in
            DispatchQueue.main.async {
                progressTimer.invalidate()
                self.exportProgress = 1.0
                
                switch result {
                case .success(let tempURL):
                    os_log("Export succeeded: %@", log: OSLog.default, type: .debug, tempURL.absoluteString)
                    self.exportedVideoURL = tempURL
                    self.isExportComplete = true
                    self.onCompleted(tempURL)
                case .failure(let error):
                    os_log("Export failed: %@", log: OSLog.default, type: .error, error.localizedDescription)
                    self.exportError = error.localizedDescription
                    self.showError = true
                    self.showFinalPage = false
                }
                self.isExporting = false
            }
        }
    }
    
    private func saveToPhotos() {
        guard let exportedVideoURL = exportedVideoURL else { return }

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            switch status {
            case .authorized, .limited:
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: exportedVideoURL)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.savedAlertMessage = "Video saved to your Photos."
                            self.showSavedAlert = true
                        } else {
                            self.exportError = error?.localizedDescription ?? "Failed to save to Photos."
                            self.showError = true
                        }
                    }
                }
            default:
                DispatchQueue.main.async {
                    self.exportError = "Photos permission denied. Enable it in Settings."
                    self.showError = true
                }
            }
        }
    }
    
    private func shareVideo() {
        guard let exportedVideoURL = exportedVideoURL else {
            print("DEBUG: No exported video URL available for sharing")
            return
        }
        
        print("DEBUG: Attempting to share video at: \(exportedVideoURL.path)")
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Verify file exists before sharing
        guard FileManager.default.fileExists(atPath: exportedVideoURL.path) else {
            print("DEBUG: Video file does not exist at path: \(exportedVideoURL.path)")
            exportError = "Video file not found. Please try exporting again."
            showError = true
            return
        }
        
        presentShareSheet(for: exportedVideoURL)
    }

    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "mp4": return "video/mp4"
        case "mov": return "video/mov"
        default: return "application/octet-stream"
        }
    }

    private func presentShareSheet(for url: URL) {
        print("DEBUG: Creating UIActivityViewController for URL: \(url.path)")
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityController.modalPresentationStyle = .pageSheet

        DispatchQueue.main.async {
            guard let presenter = UIHelpers.topViewController() else {
                print("DEBUG: Could not find top view controller for presenting share sheet")
                self.exportError = "Unable to open share sheet. Please try again."
                self.showError = true
                return
            }
            // Handle iPad popover
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            // If something else is being presented, present from the top-most
            let topMost = UIHelpers.topViewController(base: presenter)
            print("DEBUG: Presenting share sheet from top-most controller: \(String(describing: topMost))")
            (topMost ?? presenter).present(activityController, animated: true) {
                print("DEBUG: Share sheet presented successfully")
            }
        }
    }
}

#Preview {
    ExportOptionsView(
        isPresented: .constant(true),
        selectedResolution: .constant("original"),
        selectedFrameRate: .constant("30fps"),
        selectedFormat: .constant("MP4"),
        onExport: { },
        videoURL: Bundle.main.url(forResource: "enhanced", withExtension: "mp4") ?? URL(fileURLWithPath: "/tmp/dummy.mp4"),
        onCompleted: { _ in }
    )
}

