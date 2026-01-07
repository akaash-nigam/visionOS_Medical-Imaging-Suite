//
//  AuthenticationView.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    @EnvironmentObject var appState: AppState
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "faceid")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 16) {
                Text("Authentication Required")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Medical Imaging Suite requires biometric authentication to protect patient data")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding()
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            Button(action: authenticate) {
                if isAuthenticating {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Label("Authenticate with OpticID", systemImage: "faceid")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAuthenticating)
        }
        .padding(40)
    }

    private func authenticate() {
        isAuthenticating = true
        errorMessage = nil

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            errorMessage = "Biometric authentication not available"
            isAuthenticating = false
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to access patient data"
        ) { success, error in
            DispatchQueue.main.async {
                isAuthenticating = false

                if success {
                    appState.isAuthenticated = true
                    // TODO: Load user profile
                } else {
                    errorMessage = error?.localizedDescription ?? "Authentication failed"
                }
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AppState())
}
