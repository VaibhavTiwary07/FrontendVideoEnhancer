import SwiftUI

/// Standardized back-arrow icon used across the app to keep sizing consistent.
struct BackButtonIcon: View {
    var body: some View {
        Image(systemName: "chevron.left")
            .font(.system(size: 18, weight: .medium))
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
    }
}
