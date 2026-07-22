import AppKit
import Darwin
import Foundation

private enum LauncherError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case let .missingResource(name):
            return "The application is incomplete: \(name) is missing. Please rebuild the app."
        }
    }
}

@MainActor
private func showFatalError(_ error: Error) -> Never {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Super Mario 63 could not start"
    alert.informativeText = message
    alert.addButton(withTitle: "Quit")
    alert.runModal()
    exit(EXIT_FAILURE)
}

@MainActor
private func launch() throws -> Never {
    let fileManager = FileManager.default

    guard let resourcesURL = Bundle.main.resourceURL else {
        throw LauncherError.missingResource("Resources directory")
    }

    let runtimeURL = resourcesURL.appendingPathComponent("RuffleRuntime", isDirectory: false)
    let movieURL = resourcesURL.appendingPathComponent("Super Mario 63.swf", isDirectory: false)

    guard fileManager.isExecutableFile(atPath: runtimeURL.path) else {
        throw LauncherError.missingResource("RuffleRuntime")
    }
    guard fileManager.fileExists(atPath: movieURL.path) else {
        throw LauncherError.missingResource("Super Mario 63.swf")
    }

    let applicationSupport = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    ).appendingPathComponent("Super Mario 63", isDirectory: true)
    let cacheDirectory = try fileManager.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    ).appendingPathComponent("Super Mario 63", isDirectory: true)
    let saveDirectory = applicationSupport.appendingPathComponent("Saves", isDirectory: true)
    let configDirectory = applicationSupport.appendingPathComponent("Ruffle", isDirectory: true)

    for directory in [applicationSupport, cacheDirectory, saveDirectory, configDirectory] {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // Keep all relative Flash loads inside the read-only application resources.
    guard fileManager.changeCurrentDirectoryPath(resourcesURL.path) else {
        throw CocoaError(.fileNoSuchFile)
    }

    // Several MP3 streams in the 2010 SWF trigger harmless decoder warnings.
    // Avoid formatting those every frame in production; developers can opt in
    // to the upstream warning output with SM63_DEBUG=1.
    if ProcessInfo.processInfo.environment["SM63_DEBUG"] != "1" {
        setenv("RUST_LOG", "error", 1)
    }

    var arguments = [
        runtimeURL.path,
        "--graphics", "metal",
        "--power", "high",
        "--width", "900",
        "--height", "600",
        "--quality", "high",
        "--scale", "show-all",
        "--force-scale",
        "--letterbox", "on",
        "--storage", "disk",
        "--save-directory", saveDirectory.path,
        "--config", configDirectory.path,
        "--cache-directory", cacheDirectory.path,
        "--base", resourcesURL.absoluteString,
        "--open-url-mode", "confirm",
        "--filesystem-access-mode", "deny",
        "--no-gui",
        "--gamepad-button", "d-pad-up=up",
        "--gamepad-button", "d-pad-down=down",
        "--gamepad-button", "d-pad-left=left",
        "--gamepad-button", "d-pad-right=right",
        "--gamepad-button", "south=z",
        "--gamepad-button", "east=x",
        "--gamepad-button", "west=space",
        "--gamepad-button", "start=p",
    ]

    switch CommandLine.arguments.dropFirst().first {
    case "--fullscreen":
        arguments.append("--fullscreen")
    case "--runtime-version":
        arguments = [runtimeURL.path, "--version"]
    default:
        break
    }

    if arguments.last != "--version" {
        arguments.append(movieURL.path)
    }

    var cArguments = arguments.map { strdup($0) }
    cArguments.append(nil)
    defer {
        for argument in cArguments where argument != nil {
            free(argument)
        }
    }

    _ = cArguments.withUnsafeMutableBufferPointer { buffer in
        execv(runtimeURL.path, buffer.baseAddress)
    }
    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
}

MainActor.assumeIsolated {
    do {
        try launch()
    } catch {
        showFatalError(error)
    }
}
