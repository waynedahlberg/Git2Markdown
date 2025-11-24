//
//  ContentView.swift
//  Git2Markdown
//
//  Created by Wayne Dahlberg on 11/24/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isTargeted = false
    @State private var folderURL: URL?
    @State private var extensionString = "py, js, tsx, swift, md, txt"
    @State private var excludedString = "node_modules, .git, dist, build"
    @State private var showFileExporter = false
    @State private var generatedContent = ""
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("Git2Markdown")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Main Content Area
            ZStack {
                if let url = folderURL {
                    configView(url: url)
                } else {
                    dropZoneView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 500)
        // File Save Handler
        .fileExporter(
            isPresented: $showFileExporter,
            document: TextFile(initialText: generatedContent),
            contentType: .plainText,
            defaultFilename: "repo_context.txt"
        ) { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Views
    
    var dropZoneView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 3, dash: [10]))
                .foregroundColor(isTargeted ? .blue : .gray.opacity(0.3))
                .background(isTargeted ? Color.blue.opacity(0.05) : Color.clear)
            
            VStack(spacing: 15) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 60))
                    .foregroundStyle(isTargeted ? .blue : .gray)
                
                Text("Drop Repo Folder Here")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
        }
        .padding(40)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, error) in
                if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        self.folderURL = url
                    }
                }
            }
            return true
        }
    }
    
    func configView(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                Text(url.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Clear") {
                    withAnimation { folderURL = nil }
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            Text("Configuration")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("Include Extensions (comma separated)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("py, js, ts...", text: $extensionString)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading) {
                Text("Exclude Folders (comma separated)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("node_modules, .git...", text: $excludedString)
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
            
            Button(action: generateAndExport) {
                HStack {
                    Text("Process & Save Repo")
                    Image(systemName: "arrow.right.circle.fill")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Logic
    
    func generateAndExport() {
        guard let url = folderURL else { return }
        
        // Clean inputs
        let exts = extensionString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let excludes = excludedString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        let config = RepoProcessor.Configuration(url: url, allowedExtensions: exts, excludedFolders: excludes)
        
        // Run processing in background so UI doesn't freeze on large repos
        DispatchQueue.global(qos: .userInitiated).async {
            let result = RepoProcessor.generateReport(config: config)
            
            DispatchQueue.main.async {
                self.generatedContent = result
                self.showFileExporter = true
            }
        }
    }
}

// Helper for File Export
struct TextFile: FileDocument {
    static var readableContentTypes = [UTType.plainText]
    var text = ""

    init(initialText: String = "") {
        self.text = initialText
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}
