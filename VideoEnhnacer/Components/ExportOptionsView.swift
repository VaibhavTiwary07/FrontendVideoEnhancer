import SwiftUI
import OSLog
import UIKit

struct ExportOptionsView: View {
    @Binding var isPresented: Bool
    @Binding var selectedResolution: String
    @Binding var selectedFrameRate: String
    @Binding var selectedFormat: String
    let onExport: () -> Void
    let videoURL: URL
    let onCompleted: (URL) -> Void
    
    private let resolutionOptions = ["720p", "1080p"]
    private let frameRateOptions = ["30fps", "60fps"]
    private let formatOptions = ["MP4", "3GP", "AVI"]

    // Local export state
    @State private var isExporting: Bool = false
    @State private var exportError: String? = nil
    @State private var showError: Bool = false
    
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
        case "3GP": formatMultiplier = 0.4
        case "AVI": formatMultiplier = 1.5
        default: formatMultiplier = 1.0
        }
        
        // Resolution multipliers
        switch selectedResolution {
        case "720p": resolutionMultiplier = 0.6
        case "1080p": resolutionMultiplier = 1.0
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
                    withAnimation(.easeOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
            
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
                        onExport()
                        startExport()
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
        .alert("Export Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError ?? "Unknown error")
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
}

// MARK: - Export Integration (iOS 15 friendly)
extension ExportOptionsView {
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

    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "mp4": return "video/mp4"
        case "3gp": return "video/3gpp"
        case "avi": return "video/x-msvideo"
        default: return "application/octet-stream"
        }
    }

    private func presentShareSheet(for url: URL) {
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootViewController.present(activityController, animated: true)
        }
    }
}

#Preview {
    ExportOptionsView(
        isPresented: .constant(true),
        selectedResolution: .constant("1080p"),
        selectedFrameRate: .constant("30fps"),
        selectedFormat: .constant("MP4"),
        onExport: { },
        videoURL: URL(fileURLWithPath: "/tmp/dummy.mp4"),
        onCompleted: { _ in }
    )
}
