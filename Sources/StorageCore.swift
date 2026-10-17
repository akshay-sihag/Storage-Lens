import Cocoa

let files = FileManager.default
let userHome = files.homeDirectoryForCurrentUser.path
func readableSize(_ n: Int64) -> String { n == 0 ? "0 B" : ByteCountFormatter.string(fromByteCount: n, countStyle: .decimal) }
func fileIdentity(_ path: String) -> String {
    guard let a = try? files.attributesOfItem(atPath: path) else { return "" }
    return "\(a[.systemNumber] ?? ""):\(a[.systemFileNumber] ?? "")"
}
struct StorageItem: Identifiable, Hashable, Codable {
    var id: String { path }
    let path: String
    let bytes: Int64
    let category: String
    let partial: Bool
    let identity: String
    let modified: Date?
    var name: String { URL(fileURLWithPath: path).lastPathComponent }
    let directory: Bool
    let measuring: Bool
    init(path: String, bytes: Int64, category: String, partial: Bool, identity: String, modified: Date?, directory: Bool? = nil, measuring: Bool = false) {
        self.path = path; self.bytes = bytes; self.category = category; self.partial = partial
        self.identity = identity; self.modified = modified; self.measuring = measuring
        self.directory = directory ?? ((try? files.attributesOfItem(atPath: path)[.type] as? FileAttributeType) == .typeDirectory)
    }
}
struct ChromeProfiles {
    static func identifier(for path: String, home: String = userHome) -> String? {
        for relative in ["/Library/Caches/Google/Chrome/", "/Library/Application Support/Google/Chrome/"] {
            let prefix = home + relative
            if path.hasPrefix(prefix), let first = path.dropFirst(prefix.count).split(separator: "/").first {
                let id = String(first)
                if Safety(home: home).validChromeProfile(id) { return id }
            }
        }
        return nil
    }
    static func names(from data: Data) -> [String: String] {
        struct Entry: Decodable { let name: String?; let gaia_name: String?; let user_name: String? }
        struct Profile: Decodable { let info_cache: [String: Entry]? }
        struct State: Decodable { let profile: Profile? }
        guard let state = try? JSONDecoder().decode(State.self, from: data) else { return [:] }
        return (state.profile?.info_cache ?? [:]).reduce(into: [:]) { names, pair in
            func clean(_ value: String?) -> String { (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
            let profile = clean(pair.value.name), account = clean(pair.value.gaia_name), email = clean(pair.value.user_name)
            var label = profile
            if !account.isEmpty && account != profile { label = label.isEmpty ? account : label + " — " + account }
            if !email.isEmpty && email != label { label = label.isEmpty ? email : label + " (" + email + ")" }
            if !label.isEmpty { names[pair.key] = label }
        }
    }
    static func load(home: String = userHome) -> [String: String] {
        let url = URL(fileURLWithPath: home + "/Library/Application Support/Google/Chrome/Local State")
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return names(from: data)
    }
}
struct CleanupRule {
    let relative: String
    let owner: String
    let processes: [String]
    let explanation: String
}
struct FileGuidance {
    let kind: String
    let purpose: String
    let benefit: String
    let effect: String
    let risk: String
    let action: String
    let confidence: String
    let source: String
    let reviewed = "17 October 2026"
}
struct Safety {
    var home: String = userHome
    static let rules: [CleanupRule] = {
        var r = [
            CleanupRule(relative: "/.npm/_cacache", owner: "npm", processes: [], explanation: "Downloaded package cache. Installed project dependencies are preserved; future installs may need internet."),
            CleanupRule(relative: "/Library/Caches/Homebrew", owner: "Homebrew", processes: ["brew"], explanation: "Downloaded installers and build cache. Installed packages are preserved; future installs may download again."),
            CleanupRule(relative: "/Library/Caches/pip", owner: "pip", processes: ["pip", "pip3"], explanation: "Downloaded Python packages and wheels. Installed environments are preserved."),
            CleanupRule(relative: "/Library/Caches/node-gyp", owner: "Node build tools", processes: ["node", "node-gyp", "npm"], explanation: "Build headers for native Node modules. Later builds may download these again."),
            CleanupRule(relative: "/Library/Caches/typescript", owner: "TypeScript", processes: ["node", "Code", "Cursor"], explanation: "TypeScript cache. Editors may rebuild it after restart.")
        ]
        for (folder, owner, processes) in [
            ("Claude", "Claude", ["Claude", "claude"]), ("Codex", "Codex", ["Codex", "codex"]),
            ("Code", "Visual Studio Code", ["Code", "code"]), ("Slack", "Slack", ["Slack"]), ("Cursor", "Cursor", ["Cursor", "cursor"])
        ] {
            for cache in ["Cache", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache", "GraphiteDawnCache"] {
                r.append(CleanupRule(relative: "/Library/Application Support/\(folder)/\(cache)", owner: owner, processes: processes, explanation: "Rendered web, compiled code or graphics cache. Conversations, credentials, settings and databases are excluded. The app may start more slowly once."))
            }
        }
        for (folder, owner, processes) in [
            ("com.openai.codex", "Codex", ["Codex", "codex"]), ("Codex", "Codex", ["Codex", "codex"]),
            ("com.anthropic.claudefordesktop", "Claude", ["Claude", "claude"]),
            ("com.tinyspeck.slackmacgap", "Slack", ["Slack"])
        ] {
            r.append(CleanupRule(relative: "/Library/Caches/" + folder, owner: owner, processes: processes, explanation: "App cache only. Quit the app and its helpers first. Cached content may download again; first launch may be slower."))
        }
        return r
    }()
    func chromeCacheRule(_ path: String) -> CleanupRule? {
        let base = home + "/Library/Caches/Google/Chrome/"
        guard path.hasPrefix(base) else { return nil }
        let parts = String(path.dropFirst(base.count)).split(separator: "/").map(String.init)
        guard parts.count >= 2, validChromeProfile(parts[0]), parts[1] == "Cache" else { return nil }
        return CleanupRule(relative: "/Library/Caches/Google/Chrome/" + parts[0] + "/Cache", owner: "Google Chrome", processes: ["Google Chrome"], explanation: "Downloaded page resources used to speed up repeat visits. This targets the identified Cache folder only, excluding cookies and site databases. Pages may reload more slowly and download resources again. Quit Chrome first. Sign-in state is not intentionally removed; this is not a guarantee about every website.")
    }
    func validChromeProfile(_ name: String) -> Bool {
        name == "Default" || (name.hasPrefix("Profile ") && Int(name.dropFirst(8)) != nil)
    }
    func browserProtected(_ path: String) -> Bool {
        let roots = ["/Library/Application Support/Google/Chrome", "/Library/Application Support/Google/Chrome Beta", "/Library/Application Support/Google/Chrome Dev", "/Library/Application Support/Google/Chrome Canary", "/Library/Application Support/Chromium", "/Library/Application Support/Microsoft Edge", "/Library/Application Support/BraveSoftware", "/Library/Application Support/Firefox", "/Library/Safari", "/Library/Caches/Google/Chrome"]
        return roots.contains { relative in let root = home + relative; return path == root || path.hasPrefix(root + "/") || root.hasPrefix(path + "/") }
    }
    func rule(_ path: String) -> CleanupRule? {
        if let chrome = chromeCacheRule(path) { return chrome }
        return Self.rules.first { path == home + $0.relative || path.hasPrefix(home + $0.relative + "/") }
    }
    func discoveredChromeCaches() -> [CleanupRule] {
        let root = home + "/Library/Caches/Google/Chrome"
        return ((try? files.contentsOfDirectory(atPath: root)) ?? []).compactMap { profile in
            guard validChromeProfile(profile) else { return nil }
            return chromeCacheRule(root + "/" + profile + "/Cache")
        }
    }
    func browserGuidance(_ item: StorageItem) -> FileGuidance? {
        let p = item.path
        guard p.hasPrefix(home + "/Library/Application Support/Google/Chrome/") || p == home + "/Library/Application Support/Google/Chrome" || p.hasPrefix(home + "/Library/Caches/Google/Chrome/") || p == home + "/Library/Caches/Google/Chrome" else { return nil }
        let parts = p.split(separator: "/").map { $0.lowercased() }
        let source = "https://support.google.com/chrome/answer/2392709?hl=en"
        if chromeCacheRule(p) != nil {
            return FileGuidance(kind: "Cached page resources", purpose: "Local copies of downloaded web resources.", benefit: "Speeds up repeat page loads and avoids downloading the same content again.", effect: "Removing these copies may slow the next visit and use network data. Cookies, passwords and site databases are outside this rule.", risk: "Lower risk · pages may download again", action: "Optional cleanup after quitting Chrome; useful if you need space. Cache is useful data, not automatically junk.", confidence: "Documented cache location and type; individual website behavior is not verified.", source: source)
        }
        if parts.contains(where: { $0 == "cookies" || $0.hasPrefix("cookies-") }) {
            return FileGuidance(kind: "Cookies and sign-in state", purpose: "Website state that can keep you signed in and remember preferences.", benefit: "Avoids repeated logins and preserves website preferences.", effect: "Deleting cookies may sign you out and reset site preferences.", risk: "Disruptive · may sign you out", action: "Keep for routine space cleanup. To remove intentionally, use Chrome’s Delete browsing data or individual-site controls.", confidence: "Recognized cookie filename in Chrome’s standard profile location.", source: "https://support.google.com/chrome/answer/95647?hl=en")
        }
        if parts.contains(where: { ["indexeddb", "local storage", "session storage", "service worker", "storage", "webstorage", "file system"].contains($0) }) {
            return FileGuidance(kind: "Site storage / offline data", purpose: "Storage that can support website state, local databases or offline features; the exact contents are not inspected.", benefit: "Can preserve offline access and work that has not synced.", effect: "Removal may reset websites or lose offline content. The folder name does not prove the data can be downloaded again.", risk: "High risk · possible offline-data loss", action: "Review through Chrome’s site-data controls. Excluded from direct cleanup.", confidence: "Location-based classification; individual site contents and sync status unknown.", source: source)
        }
        if parts.contains(where: { ["login data", "login data-journal", "web data", "bookmarks", "history", "sessions", "preferences", "secure preferences", "extensions"].contains($0) }) {
            return FileGuidance(kind: "Browser profile data", purpose: "Personal browser data or configuration, potentially including credentials, bookmarks, history, tabs or extensions.", benefit: "Preserves your browser setup and continuity.", effect: "Deletion may remove saved information or reset browser features; some browser-managed deletion can affect synced devices.", risk: "High risk · personal browser data", action: "Keep. Use Chrome’s own controls for intentional deletion.", confidence: "Recognized profile component; contents are not read.", source: source)
        }
        return FileGuidance(kind: "Mixed or unverified browser data", purpose: "Chrome data whose individual role has not been verified by a cleanup rule.", benefit: "May support browser performance, sessions, offline features or settings.", effect: "Removing the whole folder could remove more than the disposable data you intended.", risk: "Unknown · inspect children", action: "Expand this folder. Only specifically identified page-cache folders are offered for cleanup.", confidence: "Known Chrome location; contents are mixed or not yet researched.", source: "https://chromium.googlesource.com/chromium/src/+/HEAD/docs/user_data_dir.md")
    }
    func canonicalOwned(_ path: String) -> Bool {
        let u = URL(fileURLWithPath: path)
        guard u.standardizedFileURL.path == path, u.resolvingSymlinksInPath().path == path,
              path.hasPrefix(home + "/"), let a = try? files.attributesOfItem(atPath: path),
              (a[.ownerAccountID] as? NSNumber)?.uint32Value == getuid() else { return false }
        return true
    }
    func oldLog(_ path: String, now: Date = Date()) -> Bool {
        guard canonicalOwned(path), path.hasPrefix(home + "/Library/Logs/"),
              let a = try? files.attributesOfItem(atPath: path), a[.type] as? FileAttributeType == .typeRegular,
              let m = a[.modificationDate] as? Date, now.timeIntervalSince(m) > 30 * 86400 else { return false }
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        return name.hasSuffix(".log") || name.hasSuffix(".ips") || name.hasSuffix(".crash") || name.hasSuffix(".log.gz")
    }
    func eligible(_ item: StorageItem) -> Bool {
        guard !item.partial, !item.identity.isEmpty, canonicalOwned(item.path), fileIdentity(item.path) == item.identity else { return false }
        if rule(item.path) != nil { return true }
        return oldLog(item.path)
    }
    // Explicit manual review is separate from the rebuildable-data allowlist.
    func manualPath(_ path: String) -> Bool {
        let roots = ["/Downloads/", "/Documents/", "/Desktop/", "/Library/Application Support/", "/Library/Caches/"]
        guard roots.contains(where: { path.hasPrefix(home + $0) }), !browserProtected(path),
              !path.hasPrefix(home + "/Library/Application Support/Storage Lens"),
              !path.split(separator: "/").contains(where: { $0.hasSuffix(".app") || $0 == ".git" }),
              !["cloudstorage", "mobile documents", "keychain", "credentials", "cookies", "login data"].contains(where: { path.lowercased().contains($0) }) else { return false }
        return true
    }
    func manualEligible(_ item: StorageItem) -> Bool {
        eligible(item) || (!item.partial && !item.identity.isEmpty && canonicalOwned(item.path) && fileIdentity(item.path) == item.identity && manualPath(item.path))
    }
    func installer(_ item: StorageItem) -> Bool {
        ["dmg", "pkg", "mpkg"].contains(URL(fileURLWithPath: item.path).pathExtension.lowercased()) && !item.directory
    }
    func risk(_ item: StorageItem) -> String {
        if item.partial { return "Unknown · incomplete scan" }
        if let guide = browserGuidance(item) { return guide.risk }
        if eligible(item) { return "Lower risk · rebuildable or old diagnostic data" }
        if installer(item) { return "Review required · installer may still be needed" }
        if item.path.contains("/Library/Application Support/") { return "High risk · may reset app data or features" }
        if manualEligible(item) { return "Review required · may be your only copy" }
        return "Protected · use the owning app or macOS"
    }
    func blockers(_ item: StorageItem, processNames: [String]) -> [String] {
        guard let rule = rule(item.path) else {
            if item.path.contains("/Library/Application Support/") {
                let suffix = item.path.components(separatedBy: "/Library/Application Support/").last ?? ""
                let owner = suffix.components(separatedBy: "/").first?.lowercased() ?? ""
                return processNames.filter { !owner.isEmpty && $0.lowercased().contains(owner) }
            }
            return []
        }
        return rule.processes.filter { expected in
            processNames.contains { actual in
                let a = actual.lowercased(), e = expected.lowercased()
                return a == e || a.hasPrefix(e + " ") || a.hasPrefix(e + "-")
            }
        }
    }
    func restorable(_ record: CleanupRecord) -> Bool {
        let src = URL(fileURLWithPath: record.trashed), dst = URL(fileURLWithPath: record.original)
        guard !record.restored, canonicalOwned(src.path), src.path.hasPrefix(home + "/.Trash/"),
              dst.path.hasPrefix(home + "/"), dst.standardizedFileURL.path == dst.path,
              dst.deletingLastPathComponent().resolvingSymlinksInPath().path == dst.deletingLastPathComponent().path,
              !files.fileExists(atPath: dst.path), !record.identity.isEmpty, fileIdentity(src.path) == record.identity else { return false }
        if rule(dst.path) != nil { return true }
        if record.manual == true && manualPath(dst.path) { return true }
        guard dst.path.hasPrefix(home + "/Library/Logs/"), let a = try? files.attributesOfItem(atPath: src.path),
              a[.type] as? FileAttributeType == .typeRegular, let m = a[.modificationDate] as? Date,
              Date().timeIntervalSince(m) > 30 * 86400 else { return false }
        let name = dst.lastPathComponent.lowercased()
        return name.hasSuffix(".log") || name.hasSuffix(".ips") || name.hasSuffix(".crash") || name.hasSuffix(".log.gz")
    }
    func explanation(_ item: StorageItem) -> String {
        if let guide = browserGuidance(item) { return guide.purpose + " " + guide.effect }
        if let rule = rule(item.path) { return rule.explanation }
        if oldLog(item.path) { return "Diagnostic log older than 30 days. It may be useful for troubleshooting; recent logs are kept. Open-file checks run before cleanup." }
        if installer(item) { return "Downloaded disk image or installation package. It normally installs an app rather than storing its settings. Keep it while installing, updating, or if you need an offline reinstall. A disk image can also contain personal files; its extension alone does not prove it is disposable." }
        let name = item.name.lowercased()
        if item.path.hasSuffix(".app") { return "The installed application itself. Storage Lens does not uninstall apps or remove components from their bundles. Use the app’s supported uninstaller or macOS Storage settings if you no longer need it." }
        if item.path.contains("/vm_bundles/") && name != "claudevm.bundle" {
            if name == "rootfs.img" { return "Virtual-machine root disk image inside Claude’s runtime bundle. It provides the guest operating environment. It can be large without being waste; removing it can prevent local agent tasks from starting." }
            if name == "sessiondata.img" { return "Virtual-machine session disk. It may hold task state or working data. Treat it as potentially unique app data and manage it through Claude." }
            if name.hasSuffix(".zst") { return "Compressed component inside Claude’s virtual-machine runtime. It may support provisioning or repairs. Its compressed format does not prove it is an unused installer; keep it unless the app documents removal." }
            if name.hasPrefix("vmlinuz") || name.hasPrefix("initrd") { return "Boot component for the virtual machine. It is needed to start the guest environment and is not a general-purpose cache." }
            return "Component of Claude’s virtual-machine runtime bundle. Its exact role is unverified; removing individual components may prevent the runtime from working. Use the app’s controls." }
        if name == "vm_bundles" || name.hasSuffix(".bundle") && item.path.contains("Claude") { return "Claude’s local virtual-machine environment. It supports local agent tasks and can contain working state. Removing it can reset or break those features; manage it through Claude. It is not disposable cache." }
        if name == "codex-runtimes" { return "Local runtimes and libraries used by Codex tools. They occupy disk space because tools need executable environments. Removing them can interrupt active tasks or require downloads; automatic cleanup is disabled." }
        if name == "_npx" { return "Temporary package environments created by npx. They may still be used by running commands or development tools. Automatic cleanup is disabled because active use is hard to establish reliably." }
        if name == "indexeddb" || name == "local storage" || name.contains("cookies") || name.hasSuffix(".sqlite") || name.hasSuffix(".db") { return "Persistent application or website data, possibly including sessions, offline content or settings. This is not a cache that Storage Lens can safely discard. Use the owning app’s controls." }
        if name == "worktrees" { return "Separate Git working copies used for development tasks. They may contain uncommitted changes. Archive or remove them through the development tool after reviewing their state." }
        if item.category == "Logs" { return "Diagnostic logs used for troubleshooting. Cleanup only offers individual recognized log files older than 30 days; recent logs and unknown file types stay untouched." }
        if item.category == "Cloud & personal" { return "Personal or synced files. Deleting may propagate to cloud storage. Manage local copies in the cloud provider’s app." }
        if item.path.contains(".adobeTemp") { return "Adobe installer staging. Some files may be leftovers, but interrupted installations may still need them. Review with Creative Cloud; automatic cleanup is disabled." }
        if item.path.contains("Simulator") || item.path.contains("Android") { return "Developer runtimes or emulators. Remove unused versions through Xcode or Android Studio so their registries remain consistent." }
        if item.category == "System" { return "Managed by macOS. Use macOS Storage settings or the owning tool. This app does not remove snapshots, swap, OS assets or system files." }
        return "May contain application databases, projects, backups, virtual machines or settings. Inspect it in Finder or manage it through the owning application. Automatic cleanup is disabled."
    }
}
final class DiskScanner: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    private var process: Process?
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func cancel() { lock.lock(); stopped = true; let p = process; lock.unlock(); if p?.isRunning == true { p?.terminate() } }
    func command(_ executable: String, _ args: [String]) -> (String, String, Int32) {
        if cancelled { return ("", "Scan cancelled", -2) }
        let temp = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try files.createDirectory(at: temp, withIntermediateDirectories: true)
            defer { try? files.removeItem(at: temp) }
            let out = temp.appendingPathComponent("stdout"), err = temp.appendingPathComponent("stderr")
            files.createFile(atPath: out.path, contents: nil); files.createFile(atPath: err.path, contents: nil)
            let oh = try FileHandle(forWritingTo: out), eh = try FileHandle(forWritingTo: err)
            defer { try? oh.close(); try? eh.close() }
            let p = Process(); p.executableURL = URL(fileURLWithPath: executable); p.arguments = args; p.standardOutput = oh; p.standardError = eh
            lock.lock()
            if stopped { lock.unlock(); return ("", "Scan cancelled", -2) }
            do { try p.run(); process = p; lock.unlock() } catch { lock.unlock(); throw error }
            let deadline = Date().addingTimeInterval(180)
            var timedOut = false
            while p.isRunning {
                if Date() > deadline { timedOut = true; p.terminate(); break }
                Thread.sleep(forTimeInterval: 0.04)
            }
            p.waitUntilExit(); lock.lock(); process = nil; lock.unlock()
            let o = (try? String(contentsOf: out, encoding: .utf8)) ?? ""
            let e = (try? String(contentsOf: err, encoding: .utf8)) ?? ""
            return (o, e + (timedOut ? "\nTimed out: \(args.last ?? executable)" : ""), timedOut ? -3 : (cancelled ? -2 : p.terminationStatus))
        } catch { return ("", error.localizedDescription, -1) }
    }
    func measure(_ path: String, category: String, children: Bool = true) -> ([StorageItem], String) {
        guard files.fileExists(atPath: path) else { return ([], "") }
        if children && category == "Downloads" {
            return self.children(StorageItem(path: path, bytes: 0, category: category, partial: false, identity: fileIdentity(path), modified: nil))
        }
        let (out, err, code) = command("/usr/bin/du", children ? ["-k", "-x", "-d", "1", path] : ["-k", "-x", "-s", path])
        let entries = out.split(separator: "\n").compactMap { line -> StorageItem? in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let k = Int64(parts[0]) else { return nil }
            let p = String(parts[1]); if children && p == path { return nil }
            let attrs = try? files.attributesOfItem(atPath: p)
            return StorageItem(path: p, bytes: k * 1024, category: category, partial: code < 0 || (code != 0 && (err.contains(p) || err.isEmpty)), identity: fileIdentity(p), modified: attrs?[.modificationDate] as? Date)
        }
        return (entries, err)
    }
    func immediateChildren(_ item: StorageItem) -> [StorageItem] {
        guard item.directory, URL(fileURLWithPath: item.path).resolvingSymlinksInPath().path == item.path else { return [] }
        guard let urls = try? files.contentsOfDirectory(at: URL(fileURLWithPath: item.path), includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        return urls.compactMap { url in
            guard !cancelled, let a = try? files.attributesOfItem(atPath: url.path) else { return nil }
            return StorageItem(path: url.path, bytes: 0, category: item.category, partial: true, identity: fileIdentity(url.path), modified: a[.modificationDate] as? Date, directory: a[.type] as? FileAttributeType == .typeDirectory, measuring: true)
        }
    }
    // Drill-down includes files as well as directories, never follows symlinks.
    func children(_ item: StorageItem) -> ([StorageItem], String) {
        guard item.directory, URL(fileURLWithPath: item.path).resolvingSymlinksInPath().path == item.path else { return ([], "Symlink or non-folder: inspection stopped.") }
        var result = [StorageItem](); var warnings = ""
        do {
            let urls = try files.contentsOfDirectory(at: URL(fileURLWithPath: item.path), includingPropertiesForKeys: nil)
            for start in stride(from: 0, to: urls.count, by: 100) {
                if cancelled { break }
                let paths = Array(urls[start..<min(start + 100, urls.count)]).map(\.path)
                let (out, err, code) = command("/usr/bin/du", ["-k", "-x", "-s"] + paths)
                warnings += err
                result += out.split(separator: "\n").compactMap { line in
                    let p = line.split(separator: "\t", maxSplits: 1)
                    guard p.count == 2, let n = Int64(p[0]) else { return nil }
                    let path = String(p[1]); let attrs = try? files.attributesOfItem(atPath: path)
                    return StorageItem(path: path, bytes: n * 1024, category: item.category, partial: code < 0 || (code != 0 && (err.contains(path) || err.isEmpty)), identity: fileIdentity(path), modified: attrs?[.modificationDate] as? Date)
                }
            }
        } catch { warnings += error.localizedDescription }
        return (result, warnings)
    }

    static func roots(_ home: String) -> [(String, String, Bool)] {
        [(home + "/Downloads", "Downloads", true), ("/Applications", "Installed apps", true), (home + "/Applications", "Installed apps", true), (home + "/Library/Caches", "Caches", true), (home + "/.npm", "Developer", true),
         (home + "/.cache", "Developer", true), (home + "/Library/Application Support", "Applications", true),
         (home + "/Library/Containers", "Applications", true), (home + "/Library/Group Containers", "Applications", true),
         (home + "/Library/CloudStorage", "Cloud & personal", true), (home + "/Library/Logs", "Logs", false),
         (home + "/Library/Developer", "Developer", true), (home + "/Library/Android", "Developer", true),
         (home + "/.codex", "Developer", true), (home + "/.ollama", "Developer", true),
         (home + "/.android", "Developer", false), (home + "/.pub-cache", "Developer", false),
         ("/Library/Application Support", "Applications", true), ("/Library/Developer", "Developer", true),
         ("/Library/Caches", "System", true), ("/Library/Logs", "System", false), ("/private/var", "System", true),
         ("/System/Volumes/Data/.adobeTemp", "Installer staging", true),
         ("/System/Volumes/Data/System/Library/AssetsV2", "System", true),
         ("/Users/Shared", "Applications", true), ("/opt", "Developer", true)]
    }
    // Query only the selected file or subtree, not every process with a matching name.
    func usageProblem(_ item: StorageItem) -> String? {
        let args = ["-n", "-P", "+c", "0", "-Fpc"] + (item.directory ? ["+D", item.path] : [item.path])
        let (output, error, code) = command("/usr/sbin/lsof", args)
        return Self.usageProblem(output: output, error: error, code: code)
    }
    static func usageProblem(output: String, error: String, code: Int32) -> String? {
        var pid: String?, users = [String]()
        for line in output.split(separator: "\n") {
            if line.first == "p" { pid = String(line.dropFirst()) }
            if line.first == "c", let id = pid, Int(id) != nil {
                users.append("\(line.dropFirst()) (PID \(id))")
                pid = nil
            }
        }
        if !users.isEmpty {
            return "Currently using this location: " + Array(Set(users)).sorted().joined(separator: ", ") + ". Finish the related task or close that process, then preview again."
        }
        guard error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (code == 0 || code == 1), output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Could not reliably check which processes are using this location. Nothing will be moved; retry after resolving scan access or timeout errors."
        }
        return nil
    }
    func mountedImageProblem(_ item: StorageItem) -> String? {
        let (output, _, code) = command("/usr/bin/hdiutil", ["info", "-plist"])
        guard code == 0, let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let images = plist["images"] as? [[String: Any]] else { return "Could not check mounted disk images. Try again before removing this item." }
        for image in images {
            if let path = image["image-path"] as? String {
                let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
                if resolved == item.path || resolved.hasPrefix(item.path + "/") { return "Contains a mounted disk image. Eject it in Finder before moving it to Bin." }
            }
        }
        return nil
    }
    func installers(safety: Safety) -> ([StorageItem], String) {
        var found = [StorageItem](), warnings = ""
        for relative in ["/Downloads", "/Library/Caches", "/Library/Application Support"] {
            let root = safety.home + relative
            guard files.fileExists(atPath: root) else { continue }
            guard let enumerator = files.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey, .fileAllocatedSizeKey, .contentModificationDateKey], options: [.skipsPackageDescendants], errorHandler: { u, error in warnings += "\(u.path): \(error.localizedDescription)\n"; return true }) else { continue }
            for case let url as URL in enumerator {
                if cancelled { break }
                guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .fileAllocatedSizeKey, .contentModificationDateKey]) else { warnings += "Could not inspect \(url.path)\n"; continue }
                if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
                guard values.isDirectory != true, ["dmg", "pkg", "mpkg"].contains(url.pathExtension.lowercased()) else { continue }
                found.append(StorageItem(path: url.path, bytes: Int64(values.fileAllocatedSize ?? 0), category: "Installers", partial: values.fileAllocatedSize == nil, identity: fileIdentity(url.path), modified: values.contentModificationDate))
            }
        }
        return (found.sorted { $0.bytes > $1.bytes }, warnings)
    }
    func oldLogs(safety: Safety) -> ([StorageItem], String) {
        let root = safety.home + "/Library/Logs"; var result = [StorageItem](); var warnings = ""
        guard let e = files.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey], options: [], errorHandler: { u, error in warnings += "\(u.path): \(error.localizedDescription)\n"; return true }) else { return ([], "Cannot inspect user logs") }
        for case let u as URL in e {
            if cancelled { break }
            if (try? u.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { e.skipDescendants(); continue }
            if safety.oldLog(u.path) {
                let a = try? files.attributesOfItem(atPath: u.path)
                let disk = try? u.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                result.append(StorageItem(path: u.path, bytes: Int64(disk?.totalFileAllocatedSize ?? disk?.fileAllocatedSize ?? 0), category: "Old logs", partial: false, identity: fileIdentity(u.path), modified: a?[.modificationDate] as? Date))
            }
        }
        return (result, warnings)
    }
}
struct CleanupRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let original: String
    let trashed: String
    let identity: String
    let bytes: Int64
    var restored: Bool
    var manual: Bool? = nil
}
struct HistoryStore {
    let url = files.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Storage Lens/history.json")
    func read() throws -> [CleanupRecord] {
        guard files.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([CleanupRecord].self, from: Data(contentsOf: url))
    }
    func save(_ records: [CleanupRecord]) throws {
        let dir = url.deletingLastPathComponent()
        guard dir.resolvingSymlinksInPath().path == dir.path, url.resolvingSymlinksInPath().path == url.path else { throw NSError(domain: "StorageLens", code: 1, userInfo: [NSLocalizedDescriptionKey: "History location is a symlink. Cleanup stopped."]) }
        try files.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        try e.encode(records).write(to: url, options: .atomic)
        try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
