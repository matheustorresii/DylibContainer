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
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }
        }
    }

    func downloadDylib() {
        guard let url = URL(string: "https://github.com/matheustorresii/DylibPackage/raw/main/libDylibPackage.dylib") else {
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
        let dylibPath = docsPath.appendingPathComponent("libDylibPackage.dylib")
        
        guard FileManager.default.fileExists(atPath: dylibPath.path) else {
            print("Dylib not found. Please download it first.")
            return
        }

        let handle = dlopen(dylibPath.path, RTLD_NOW)
        guard handle != nil else {
            if let error = dlerror() {
                print("dlopen error: \(String(cString: error))")
            }
            return
        }

        typealias DynamicViewLoaderType = @convention(c) () -> AnyObject
        let symbol = dlsym(handle, "createDynamicView")
        guard symbol != nil else {
            if let error = dlerror() {
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
}
