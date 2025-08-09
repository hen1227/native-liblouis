// In NativeLiblouisModule.swift

import Foundation
import ExpoModulesCore

public final class NativeLiblouisModule: Module {

    private static var didInit = false

    private static var tablesPath: String = ""

    private static func ensureInitialized() {
        guard !didInit else { return }

        let moduleBundle = Bundle(for: NativeLiblouisModule.self)  // Bundle for native-liblouis.framework
        let resourceBundleName = "NativeLiblouisModule"  // Name of the .bundle defined in Podspec

        print("[NativeLiblouisModule] Initializing...")
        print("[NativeLiblouisModule] Module (framework) bundle path: \(moduleBundle.bundlePath)")

        // Find the 'native-liblouis.bundle' within the framework bundle
        guard
            let resourceBundleURL = moduleBundle.url(
                forResource: resourceBundleName, withExtension: "bundle")
        else {
            print(
                "[NativeLiblouisModule] CRITICAL ERROR: Could not find the resource bundle '\(resourceBundleName).bundle' within the module bundle."
            )
            fatalError("Resource bundle '\(resourceBundleName).bundle' not found.")
        }
        print("[NativeLiblouisModule] Found resource bundle URL: \(resourceBundleURL.path)")

        // Load the resource bundle itself
        guard let tablesResourceBundle = Bundle(url: resourceBundleURL) else {
            print(
                "[NativeLiblouisModule] CRITICAL ERROR: Could not load the resource bundle at \(resourceBundleURL.path)."
            )
            fatalError("Could not load resource bundle at \(resourceBundleURL.path).")
        }
        print(
            "[NativeLiblouisModule] Successfully loaded resource bundle: \(tablesResourceBundle.bundlePath)"
        )

        // This is the path to the root of 'native-liblouis.bundle'
        let bundleRootPath = tablesResourceBundle.bundlePath

        // Liblouis expects a 'tables' (or 'liblouis/tables') subdirectory within the path given to lou_setDataPath.
        // So, we give it the bundleRootPath, and it will look for bundleRootPath + "/tables/"
        let expectedTablesSubDirPath = (bundleRootPath as NSString).appendingPathComponent("tables")
//        let expectedTablesSubDirPath = bundleRootPath

        // Check if this 'tables' subdirectory actually exists
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: expectedTablesSubDirPath, isDirectory: &isDir)
            && isDir.boolValue
        {
            print(
                "[NativeLiblouisModule] Found 'tables' subdirectory at: \(expectedTablesSubDirPath)"
            )

            tablesPath = expectedTablesSubDirPath

            print(
                "[NativeLiblouisModule] Calling lou_setDataPath with: \(bundleRootPath) (which contains the 'tables' subdirectory)"
            )
            lou_setDataPath(bundleRootPath)  // Pass the parent of the 'tables' dir
            lou_setLogLevel(LOU_LOG_ALL)
            didInit = true
            print("[NativeLiblouisModule] Liblouis initialized.")

        } else {
            print(
                "[NativeLiblouisModule] CRITICAL ERROR: Did not find a 'tables' subdirectory at '\(expectedTablesSubDirPath)'."
            )
            print(
                "   Liblouis expects tables to be in a 'tables' (or 'liblouis/tables') subdirectory within the path given to lou_setDataPath."
            )
            print("   The path passed to lou_setDataPath would have been: \(bundleRootPath)")
            print(
                "   Ensure your Podspec (`resource_bundles`) and source file structure (e.g., `ios/liblouis_assets/tables/`) are correct."
            )
            let actualBundleContents = try? FileManager.default.contentsOfDirectory(
                atPath: bundleRootPath)
            print(
                "   Actual contents of '\(bundleRootPath)': \(actualBundleContents ?? ["Error listing contents"])"
            )
            fatalError("Liblouis 'tables' subdirectory not found as expected.")
        }
    }

    // MARK: – Helper -----------------------------------------------------------
    private static func runLouis(table: String, input: String, isBack: Bool) throws -> String {
        ensureInitialized()  // This will now print detailed logs

        let sanitizedInput = input.replacingOccurrences(of: "\u{2800}", with: " ")  // BRAILLE PATTERN BLANK
        if sanitizedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && input.contains("\u{2800}")
        {
            // If the input was all \u2800, and now it's empty...
        }
        if sanitizedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !input.isEmpty
        {
            return String(repeating: " ", count: input.count)
        }

        var inBuf = Array(sanitizedInput.utf16)
        var inLen = Int32(inBuf.count)
        var outBuf = Array<UInt16>(repeating: 0, count: inBuf.count * 4 + 1)  // +1 for null terminator, just in case
        var outLen = Int32(outBuf.count)

        let tablePaths =
            table
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { (tablesPath as NSString).appendingPathComponent(String($0)) }
            .joined(separator: ",")

        let ok: Int32 = tablePaths.withCString { cTable in
            if isBack {
                return lou_backTranslateString(
                    cTable, &inBuf, &inLen, &outBuf, &outLen, nil, nil, 0)
            } else {
                return lou_translateString(cTable, &inBuf, &inLen, &outBuf, &outLen, nil, nil, 0)
            }
        }

        guard ok == 1 else {
            print(
                "[NativeLiblouisModule] liblouis operation failed. Code: \(ok), Input: '\(sanitizedInput)', Table: '\(table)'"
            )
            throw NSError(
                domain: "LibLouis", code: Int(ok),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "liblouis returned error \(ok) with input: \(input) and table: \(table). Check console for 'Cannot resolve table' messages from liblouis itself."
                ])
        }
        return String(utf16CodeUnits: outBuf, count: Int(outLen))
    }

    // MARK: – Expo modules API --------------------------------------------------
    public func definition() -> ModuleDefinition {
        Name("NativeLiblouisModule")

        Constants([
            "status": "NativeLiblouisModule is loaded"
        ])

        Function("lou_translateString") { (text: String, table: String) throws -> String in
            try Self.runLouis(table: table, input: text, isBack: false)
        }

        Function("lou_backTranslateString") { (dots: String, table: String) throws -> String in
            try Self.runLouis(table: table, input: dots, isBack: true)
        }

        Function("lou_isInitialized") {
            // Return whether the module has been initialized
            return Self.didInit
        }
    }
}
