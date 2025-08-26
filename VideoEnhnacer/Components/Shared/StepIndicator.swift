import SwiftUI

// MARK: - Shared Step Indicator Component
/// Standardized step progress indicator used across all navigation flows
/// Shows current step with connected dots and descriptive text
struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                ForEach(1...totalSteps, id: \.self) { step in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(step <= currentStep ? Color.accentWarm : Color.accentWarm.opacity(0.3))
                            .frame(width: step == currentStep ? 10 : 8, height: step == currentStep ? 10 : 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.accentWarm, lineWidth: step == currentStep ? 2 : 1)
                                    .opacity(step == currentStep ? 1 : 0.5)
                            )
                        
                        if step < totalSteps {
                            Rectangle()
                                .fill(step < currentStep ? Color.accentWarm : Color.accentWarm.opacity(0.3))
                                .frame(width: 12, height: 2)
                                .cornerRadius(1)
                        }
                    }
                }
            }
            
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.accentWarm)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        StepIndicator(currentStep: 1, totalSteps: 4)
        StepIndicator(currentStep: 2, totalSteps: 4) 
        StepIndicator(currentStep: 3, totalSteps: 4)
        StepIndicator(currentStep: 4, totalSteps: 4)
    }
    .padding()
}