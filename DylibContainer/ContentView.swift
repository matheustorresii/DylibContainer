//
//  ContentView.swift
//  DylibContainer
//
//  Created by Matheus Torres on 06/07/24.
//
import SwiftUI

struct ContentView: View {
    @State private var isDylibDownloaded = false
    @State private var downloadError: String?

    var body: some View {
        VStack {
            Button("Download dylib") {
                downloadDylib()
            }
            .padding()
            
            Text(isDylibDownloaded ? "Downloaded :)" : "Not Downloaded :(" )

            Button("Navigate") {
                if isDylibDownloaded {
                    navigateToDynamicView()
                } else {
                    print("Please download the dylib first.")
                }
            }
            .padding()

            if let error = downloadError {
                ScrollView {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                }
            }
        }.onAppear {
            clearCache()
        }
    }
    
    private func getDylibName() -> String {
        #if targetEnvironment(simulator)
            return "libDylibPackage-sim.dylib"
        #else
            return "libDylibPackage.dylib"
        #endif
    }

    func downloadDylib() {
        guard let url = URL(string: "https://github.com/matheustorresii/DylibPackage/raw/main/\(getDylibName())") else {
            print("Invalid URL")
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { (tempLocalUrl, response, error) in
            guard let tempLocalUrl = tempLocalUrl, error == nil else {
                DispatchQueue.main.async {
                    downloadError = error?.localizedDescription ?? "Unknown error"
                }
                print("Error downloading file: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            // Move the downloaded file to a permanent location
            let fileManager = FileManager.default
            let docsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationUrl = docsPath.appendingPathComponent(url.lastPathComponent)

            do {
                if fileManager.fileExists(atPath: destinationUrl.path) {
                    try fileManager.removeItem(at: destinationUrl)
                }
                try fileManager.copyItem(at: tempLocalUrl, to: destinationUrl)
                DispatchQueue.main.async {
                    isDylibDownloaded = true
                }
            } catch {
                DispatchQueue.main.async {
                    downloadError = error.localizedDescription
                }
                print("Error moving file: \(error.localizedDescription)")
            }
        }
        task.resume()
    }

    func navigateToDynamicView() {
        let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dylibPath = docsPath.appendingPathComponent(getDylibName())
        
        guard FileManager.default.fileExists(atPath: dylibPath.path) else {
            downloadError = "Dylib not found. Please download it first."
            print("Dylib not found. Please download it first.")
            return
        }

        let handle = dlopen(dylibPath.path, RTLD_NOW)
        guard handle != nil else {
            if let error = dlerror() {
                downloadError = "dlopen error: \(String(cString: error))"
                print("dlopen error: \(String(cString: error))")
            }
            return
        }

        typealias DynamicViewLoaderType = @convention(c) () -> AnyObject
        let symbol = dlsym(handle, "createDynamicView")
        guard symbol != nil else {
            if let error = dlerror() {
                downloadError = "dlsym error"
                print("dlsym error: \(String(cString: error))")
            }
            return
        }

        let dynamicViewLoader = unsafeBitCast(symbol, to: DynamicViewLoaderType.self)
        let view = dynamicViewLoader() as! AnyView
        
        let dynamicViewController = UIHostingController(rootView: view)
        if let window = UIApplication.shared.windows.first {
            window.rootViewController?.present(dynamicViewController, animated: true, completion: nil)
        }
    }
    
    func clearCache() {
        let cacheUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileManager = FileManager.default
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: cacheUrl, includingPropertiesForKeys: nil, options: [])
            for file in directoryContents {
                do {
                    try fileManager.removeItem(at: file)
                } catch let error as NSError {
                    print("clear cache error: \(error)")
                }
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
}
