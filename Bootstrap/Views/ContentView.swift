//
//  ContentView.swift
//  BootstrapUI
//
//  Created by haxi0 on 21.12.2023.
//

import SwiftUI
import FluidGradient
import Foundation

struct BootstrapView: View {
    @State var LogItems: [String.SubSequence] = {
        return [""]
    }()
    
    @State var openSSH = false
    @State var showOptions = false
    @State var showCredits = false
    @State var updateAvailable = false
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let versionRegex = try? NSRegularExpression(pattern: "\\d+\\.\\d+\\.\\d+")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                FluidGradient(blobs: [.red, .orange],
                              highlights: [.red, .yellow],
                              speed: 0.5,
                              blur: 0.95)
                .background(.quaternary)
            
                VStack {
                    HStack(spacing: 15) {
                        Image("Bootstrap")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(18)
                    
                        VStack(alignment: .leading, content: {
                            Text(" Bootstrap ")
                                .bold()
                                .font(Font.system(size: 35))
                            Text(NSLocalizedString("AAA", comment: ""))
                                .font(Font.system(size: 20))
                                .opacity(0.5)
                        })
                    }
                    .padding(20)
                
                    VStack {
                        Button {
                            bootstrapFr()
                        } label: {
                            if isBootstrapInstalled() {
                                Label(
                                    title: { Text("Kickstart") },
                                    icon: { Image(systemName: "terminal") }
                                )
                                .padding(25)
                            } else {
                                Label(
                                    title: { Text("Bootstrap") },
                                    icon: { Image(systemName: "terminal") }
                                )
                                .padding(25)
                            }
                        }
                        .background {
                            Color(UIColor.systemBackground)
                                .cornerRadius(20)
                                .opacity(0.5)
                        }
                        .disabled(isSystemBootstrapped())
                    
                        if isBootstrapInstalled() {
                            Button {
                                unbootstrapFr()
                            } label: {
                                Label(
                                    title: { Text("Uninstall") },
                                    icon: { Image(systemName: "trash") }
                                )
                                .padding(25)
                            }
                            .background {
                                Color(UIColor.systemBackground)
                                    .cornerRadius(20)
                                    .opacity(0.5)
                            }
                            .disabled(isSystemBootstrapped())
                        }

                        if updateAvailable {
                            Button {
                                let link = "https://github.com/wwg135/Bootstrap/releases"
                                if let url = URL(string: link) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label(
                                    title: { Text("Button_Update_Available") },
                                    icon: { Image(systemName: "arrow.down.circle") }
                                )
                                .padding(25)
                            }
                            .background {
                                Color(UIColor.systemBackground)
                                    .cornerRadius(20)
                                    .opacity(0.5)
                            }
                        }
                    
                        HStack {
                            Button {
                                withAnimation {
                                    showOptions.toggle()
                                }
                            } label: {
                                Label(
                                    title: { Text("Settings") },
                                    icon: { Image(systemName: "gear") }
                                )
                                .padding(25)
                            }
                            .background {
                                Color(UIColor.systemBackground)
                                    .cornerRadius(20)
                                    .opacity(0.5)
                            }
                        
                            Button {
                                respringFr()
                            } label: {
                                Label(
                                    title: { Text("Respring") },
                                    icon: { Image(systemName: "arrow.clockwise") }
                                )
                                .padding(25)
                            }
                            .background {
                                Color(UIColor.systemBackground)
                                    .cornerRadius(20)
                                    .opacity(0.5)
                            }
                            .disabled(!isSystemBootstrapped())
                        }
                    
                        VStack {
                            ScrollView {
                                ScrollViewReader { scroll in
                                    VStack(alignment: .leading) {
                                        ForEach(0..<LogItems.count, id: \.self) { LogItem in
                                            Text("\(String(LogItems[LogItem]))")
                                                .textSelection(.enabled)
                                                .font(.custom("Menlo", size: 15))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .onReceive(NotificationCenter.default.publisher(for: LogStream.shared.reloadNotification)) { obj in
                                        DispatchQueue.global(qos: .utility).async {
                                            FetchLog()
                                            scroll.scrollTo(LogItems.count - 1)
                                        }
                                    }
                                }
                            }
                            .frame(height: 150)
                        }
                        .frame(width: 253)
                        .padding(20)
                        .background {
                            Color(.black)
                                .cornerRadius(20)
                                .opacity(0.5)
                        }
                    
                        Text("UI made with love by haxi0. ♡")
                            .font(Font.system(size: 13))
                            .opacity(0.5)
                    }
                }

                Button {
                    withAnimation {
                        showCredits.toggle()
                    }
                } label: {
                    Label(
                        title: { Text("Credits") },
                        icon: { Image(systemName: "person") }
                    )
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(25)
            }
            .ignoresSafeArea()
            .overlay {
                if showCredits {
                    CreditsView(showCredits: $showCredits)
                }
            
                if showOptions {
                    OptionsView(showOptions: $showOptions, openSSH: $openSSH)
                }
            }
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                Task {
                    do {
                        try await checkForUpdates()
                    } catch {
                        print("Error: ", error)
                    }
                }
            }
        }
    }

    func checkForUpdates() async throws {
        let currentAppVersion = "AAB"      
        let releasesURL = URL(string: "https://api.github.com/repos/wwg135/Bootstrap/releases")!
        let releasesRequest = URLRequest(url: releasesURL)
        let (releasesData, _) = try await URLSession.shared.data(for: releasesRequest)
        guard let releasesJSON = try JSONSerialization.jsonObject(with: releasesData, options: []) as? [[String: Any]] else {
            return
        }

        if releasesJSON.first(where: {
            if let version = $0["name"] as? String, versionRegex?.firstMatch(in: version, options: [], range: NSRange(location: 0, length: version.utf16.count)) != nil {   
                if let latestName = $0["tag_name"] as? String, let latestVersion = $0["name"] as? String {
                    if latestName.count == 10 && currentAppVersion.count == 10 {
                        if latestName > currentAppVersion && versionRegex?.firstMatch(in: latestVersion, options: [], range: NSRange(location: 0, length: latestVersion.utf16.count)) != nil {
                            return true  
                        }
                    }
                }
            }
            return false
        }) != nil {
            updateAvailable = true
        }
    }
    
    private func FetchLog() {
        guard let AttributedText = LogStream.shared.outputString.copy() as? NSAttributedString else {
            LogItems = ["Error Getting Log!"]
            return
        }
        LogItems = AttributedText.string.split(separator: "\n")
    }
}
