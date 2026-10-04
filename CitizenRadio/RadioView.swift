import AVKit
import SwiftUI

@MainActor
struct RadioView: View {
    @ObservedObject var player: RadioPlayer
    @State private var draftURL = StreamStore().savedURL
    @State private var savedURL = StreamStore().savedURL
    @State private var settingsError: String?
    @FocusState private var editingURL: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)

                        Text("Your station. Your drive.")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Label(player.state.title, systemImage: player.state.symbol)
                            .font(.headline)
                            .accessibilityIdentifier("playbackStatus")

                        if player.state == .connecting {
                            ProgressView("Connecting to your stream")
                        }

                        if let message = player.state.errorMessage {
                            Text(message)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            editingURL = false
                            if player.state.canStop {
                                player.stop()
                            } else {
                                player.playFromControls()
                            }
                        } label: {
                            Label(
                                player.state.canStop ? "Stop Radio" : "Play Radio",
                                systemImage: player.state.canStop ? "stop.fill" : "play.fill"
                            )
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(savedURL.isEmpty && !player.state.canStop)
                        .accessibilityIdentifier("playbackButton")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stream URL")
                            .font(.headline)
                        TextField("https://radio.example.org/live", text: $draftURL)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($editingURL)
                            .onSubmit(saveStream)
                            .accessibilityLabel("Stream URL")
                            .accessibilityIdentifier("streamURL")
                    }
                    Button("Save Stream", action: saveStream)
                        .frame(minHeight: 44)
                        .disabled(draftURL == savedURL)
                        .accessibilityIdentifier("saveStream")
                    if let settingsError {
                        Text(settingsError)
                            .foregroundStyle(.red)
                    } else if !savedURL.isEmpty && draftURL == savedURL {
                        Label("Stream saved", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Your station")
                } footer: {
                    Text("Enter a direct MP3 or AAC stream URL. Use HTTPS when available.")
                }

                Section("Audio output") {
                    HStack {
                        Label(player.outputName, systemImage: "speaker.wave.2")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        AudioRoutePicker()
                            .frame(width: 44, height: 44)
                    }
                    Text("Use the iPhone or car controls to change the volume.")
                        .foregroundStyle(.secondary)
                }

                Section("Play in your car") {
                    Text("Create a Bluetooth automation in Shortcuts for your car.")
                    Text("Add the Play CitizenRadio action and enable automatic execution.")
                    Text("CitizenRadio uses the stream saved above.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("CitizenRadio")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editingURL = false }
                }
            }
        }
    }

    private func saveStream() {
        do {
            let address = try StreamStore().save(draftURL)
            if address.url.absoluteString != savedURL {
                player.stop()
            }
            savedURL = address.url.absoluteString
            draftURL = savedURL
            settingsError = nil
            editingURL = false
        } catch {
            settingsError = error.localizedDescription
        }
    }
}

private struct AudioRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
