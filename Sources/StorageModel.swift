import Cocoa
import SwiftUI

struct ReviewItem: Identifiable {
    var id: String { item.id }
    let item: StorageItem
    let problem: String?
}
struct AppGroup: Identifiable {
    var id: String { name }
    let name: String
    let items: [StorageItem]
    var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
}
func ownerName(_ item: StorageItem) -> String {
    if let rule = Safety().rule(item.path) { return rule.owner }
    let p = item.path.lowercased()
    for (term, owner) in [("claude", "Claude"), ("anthropic", "Claude"), ("codex", "Codex"), ("openai", "Codex"), ("adobe", "Adobe"), ("google", "Google Chrome"), ("slack", "Slack"), ("android", "Android Studio"), ("simulator", "Xcode & Simulators"), ("xcode", "Xcode & Simulators"), ("developer", "Developer tools"), ("logi", "Logitech"), ("nordvpn", "NordVPN"), ("onedrive", "OneDrive"), ("/.npm/", "npm"), ("/code", "Visual Studio Code")] {
        if p.contains(term) { return owner }
    }
    if item.category == "System" { return "macOS" }
    return item.name.hasSuffix(".app") ? String(item.name.dropLast(4)) : item.name
}
private var cachedAppIcons = [String: NSImage]()
private var cachedFileIcons = [String: NSImage]()
func fileIcon(_ path: String) -> NSImage {
    if let icon = cachedFileIcons[path] { return icon }
    let icon = NSWorkspace.shared.icon(forFile: path); cachedFileIcons[path] = icon; return icon
}
func appIcon(_ name: String) -> NSImage {
    if let icon = cachedAppIcons[name] { return icon }
    let icon = uncachedAppIcon(name); cachedAppIcons[name] = icon; return icon
}
private func uncachedAppIcon(_ name: String) -> NSImage {
    let ids = ["Claude": "com.anthropic.claudefordesktop", "Codex": "com.openai.codex", "Google Chrome": "com.google.Chrome", "Slack": "com.tinyspeck.slackmacgap", "Visual Studio Code": "com.microsoft.VSCode", "Android Studio": "com.google.android.studio", "Xcode & Simulators": "com.apple.dt.Xcode", "OneDrive": "com.microsoft.OneDrive", "NordVPN": "com.nordvpn.macos", "Adobe": "com.adobe.Photoshop"]
    if let id = ids[name], let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return NSWorkspace.shared.icon(forFile: url.path) }
    for root in ["/Applications/", userHome + "/Applications/"] {
        let path = root + name + ".app"
        if files.fileExists(atPath: path) { return NSWorkspace.shared.icon(forFile: path) }
    }
    return NSImage(systemSymbolName: name == "macOS" ? "desktopcomputer" : "app.dashed", accessibilityDescription: name)!
}
final class StorageModel: ObservableObject {
    @Published var chromeProfileNames = [String: String]()
    func profileLabel(_ item: StorageItem) -> String? {
        guard let id = ChromeProfiles.identifier(for: item.path, home: safety.home) else { return nil }
        if let name = chromeProfileNames[id], name != id { return "\(name) · \(id)" }
        return id
    }
    func itemTitle(_ item: StorageItem) -> String {
        if item.name == "Cache", safety.chromeCacheRule(item.path) != nil, let profile = profileLabel(item) { return "Chrome cache · " + profile }
        return item.name
    }
    func itemSubtitle(_ item: StorageItem) -> String {
        if let profile = profileLabel(item) { return "Google Chrome · " + profile }
        return ownerName(item)
    }
    @Published var entries = [StorageItem]()
    @Published var installers = [StorageItem]()
    @Published var candidates = [StorageItem]()
    @Published var history = [CleanupRecord]()
    @Published var busy = false
    @Published var progress = 0.0
    @Published var status = "Start a scan to see what is using space."
    @Published var warnings = ""
    @Published var snapshots = "Not checked yet."
    @Published var free: Int64 = 0
    @Published var capacity: Int64 = 0
    @Published var scannedAt: Date?
    @Published var processes = [String]()
    @Published var processCheckAvailable = false
    @Published var review = [ReviewItem]()
    @Published var showReview = false
    var manualReview = false
    @Published var showAccess = false
    @Published var notice = ""
    @Published var showNotice = false
    @Published var drillPath: String?
    @Published var drilled = [StorageItem]()
    @Published var expanded = Set<String>()
    @Published var childrenByPath = [String: [StorageItem]]()
    @Published var loadingPath: String?
    @Published var folderMessages = [String: String]()
    var treeGeneration = UUID()
    private let folderQueue: OperationQueue = {
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 2; queue.qualityOfService = .utility; return queue
    }()
    private var folderWorkers = [String: DiskScanner]()
    private var displayEligibility = [StorageItem: Bool]()
    func displayEligible(_ item: StorageItem) -> Bool {
        if let cached = displayEligibility[item] { return cached }
        // Display hint only. Destructive actions always call Safety.eligible afresh.
        let value = safety.eligible(item); displayEligibility[item] = value; return value
    }
    func toggleFolder(_ item: StorageItem) {
        if expanded.contains(item.path) { expanded.remove(item.path); return }
        guard !busy else { return }
        expanded.insert(item.path)
        guard childrenByPath[item.path] == nil, folderWorkers[item.path] == nil else { return }
        loadingPath = item.path; status = "Measuring contents of \(item.name)…"
        let scanner = DiskScanner(); folderWorkers[item.path] = scanner; let generation = treeGeneration
        folderQueue.addOperation {
            let preview = scanner.immediateChildren(item)
            DispatchQueue.main.async {
                guard generation == self.treeGeneration, !scanner.cancelled else { return }
                self.childrenByPath[item.path] = preview
            }
            let (rows, error) = scanner.children(item)
            let hints = Dictionary(uniqueKeysWithValues: rows.map { ($0, self.safety.eligible($0)) })
            DispatchQueue.main.async {
                guard generation == self.treeGeneration else { return }
                self.folderWorkers.removeValue(forKey: item.path)
                if self.loadingPath == item.path { self.loadingPath = nil }
                if scanner.cancelled { self.childrenByPath.removeValue(forKey: item.path); self.expanded.remove(item.path); return }
                self.displayEligibility.merge(hints) { _, new in new }
                self.childrenByPath[item.path] = rows.sorted { $0.bytes > $1.bytes }
                self.folderMessages[item.path] = error.isEmpty ? (rows.isEmpty ? "Empty folder" : "") : "Some contents could not be read. Sizes may be incomplete."
                self.status = error.isEmpty ? "\(rows.count) items measured in \(item.name)" : "Partial folder measurement"
                self.warnings += error
            }
        }
    }
    func depth(_ item: StorageItem, roots: [StorageItem]) -> Int {
        guard let root = roots.filter({ item.path.hasPrefix($0.path + "/") }).min(by: { $0.path.count < $1.path.count }) else { return 0 }
        return item.path.split(separator: "/").count - root.path.split(separator: "/").count
    }
    func flattened(_ roots: [StorageItem], sort: String) -> [StorageItem] {
        func walk(_ items: [StorageItem]) -> [StorageItem] {
            items.sorted { sort == "Name A–Z" ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : (sort == "Smallest first" ? $0.bytes < $1.bytes : $0.bytes > $1.bytes) }.flatMap { item in
                [item] + (expanded.contains(item.path) ? walk(childrenByPath[item.path] ?? []) : [])
            }
        }
        return walk(roots)
    }
    private var drillStack = [(String?, [StorageItem])]()
    private var worker: DiskScanner?
    let safety: Safety
    let store = HistoryStore()
    init(safety: Safety = Safety()) {
        self.safety = safety
        refreshDisk()
        do { history = try store.read() } catch { warnings = "Cleanup history could not be read: \(error.localizedDescription). Cleanup is disabled until this is resolved." }
    }
    func tell(_ text: String) { notice = text; showNotice = true }
    func refreshDisk() {
        if let a = try? files.attributesOfFileSystem(forPath: userHome) { free = (a[.systemFreeSize] as? NSNumber)?.int64Value ?? 0; capacity = (a[.systemSize] as? NSNumber)?.int64Value ?? 0 }
    }
    var measured: Int64 { entries.reduce(0) { $0 + $1.bytes } }
    var cacheBytes: Int64 { candidates.reduce(0) { $0 + $1.bytes } }
    var categories: [(String, Int64)] {
        Dictionary(grouping: entries, by: \.category).map { ($0.key, $0.value.reduce(Int64(0)) { $0 + $1.bytes }) }.sorted { $0.1 > $1.1 }
    }
    var apps: [AppGroup] {
        Dictionary(grouping: entries.filter { ["Applications", "Installed apps", "Caches", "Developer", "Installer staging"].contains($0.category) || $0.path.contains("iOSSimulatorRuntime") }, by: ownerName).map { AppGroup(name: $0.key, items: $0.value.sorted { $0.bytes > $1.bytes }) }.sorted { $0.bytes > $1.bytes }
    }
    func assessment(_ item: StorageItem) -> String {
        if item.measuring { return "Measuring…" }
        if item.partial { return "Incomplete scan" }
        if displayEligible(item) {
            if safety.rule(item.path)?.owner == "npm" { return "Cache · usage checked before removal" }
            if !processCheckAvailable { return "Check before cleaning" }
            if !safety.blockers(item, processNames: processes).isEmpty { return "Quit app first" }
            return item.category == "Old logs" ? "Old log · review first" : "Rebuildable cache"
        }
        if let guide = safety.browserGuidance(item) { return guide.risk }
        if safety.installer(item) { return "Installer · review first" }
        if item.category == "System" { return "Keep · system managed" }
        if item.category == "Cloud & personal" { return "Keep · personal files" }
        return "Review manually"
    }
    static func processList(_ scanner: DiskScanner) -> ([String], Bool) {
        let (out, _, code) = scanner.command("/bin/ps", ["-axo", "comm="])
        return (out.split(separator: "\n").map { URL(fileURLWithPath: $0.trimmingCharacters(in: .whitespaces)).lastPathComponent }, code == 0)
    }
    func scan() {
        guard !busy else { return }; folderWorkers.values.forEach { $0.cancel() }; folderWorkers = [:]; displayEligibility = [:]; treeGeneration = UUID(); expanded = []; childrenByPath = [:]; folderMessages = [:]; busy = true; progress = 0; status = "Measuring storage…"; drillPath = nil; drillStack = []; drilled = []
        let scanner = DiskScanner(); worker = scanner
        DispatchQueue.global(qos: .utility).async {
            let profileNames = ChromeProfiles.load(home: self.safety.home)
            var rows = [StorageItem](), cleanup = [StorageItem](); var errors = ""
            let roots = DiskScanner.roots(userHome); let rules = Safety.rules + self.safety.discoveredChromeCaches()
            let total = Double(roots.count + rules.count + 2)
            for (i, root) in roots.enumerated() {
                if scanner.cancelled { break }
                DispatchQueue.main.async { self.status = "Scanning \(root.1): \(URL(fileURLWithPath: root.0).lastPathComponent)"; self.progress = Double(i) / total }
                let (items, err) = scanner.measure(root.0, category: root.1, children: root.2); rows += items; errors += err
            }
            for (i, rule) in rules.enumerated() {
                if scanner.cancelled { break }
                DispatchQueue.main.async { self.status = "Checking rebuildable caches: \(rule.owner)"; self.progress = Double(roots.count + i) / total }
                let (items, err) = scanner.measure(userHome + rule.relative, category: "Rebuildable caches", children: false); cleanup += items.filter { self.safety.eligible($0) }; errors += err
            }
            if !scanner.cancelled { let (logs, err) = scanner.oldLogs(safety: self.safety); cleanup += logs; errors += err }
            let (foundInstallers, installerErrors) = scanner.installers(safety: self.safety); errors += installerErrors
            let (snapshot, snapshotErr, _) = scanner.command("/usr/bin/tmutil", ["listlocalsnapshots", "/"]); errors += snapshotErr
            let (names, canCheck) = Self.processList(scanner)
            let finalRows = rows.sorted { $0.bytes > $1.bytes }, finalCleanup = cleanup.sorted { $0.bytes > $1.bytes }, finalErrors = errors
            let displayHints = Dictionary((finalRows + finalCleanup + foundInstallers).map { ($0, self.safety.eligible($0)) }, uniquingKeysWith: { first, _ in first })
            DispatchQueue.main.async {
                self.busy = false; self.worker = nil
                self.chromeProfileNames = profileNames
                self.displayEligibility = displayHints
                if scanner.cancelled { self.status = "Scan cancelled. Previous completed results are kept."; return }
                self.installers = foundInstallers; self.entries = finalRows; self.candidates = finalCleanup; self.warnings = finalErrors; self.snapshots = snapshot; self.processes = names; self.processCheckAvailable = canCheck
                self.progress = 1; self.scannedAt = Date(); self.refreshDisk()
                self.status = "\(finalRows.count) locations measured · " + (finalErrors.isEmpty ? "Scan complete" : "Some protected locations could not be fully read")
            }
        }
    }
    func cancel() { worker?.cancel(); folderWorkers.values.forEach { $0.cancel() }; status = "Stopping scan…" }
    func drill(_ item: StorageItem) {
        guard !busy, item.directory else { return }; busy = true; status = "Inspecting \(item.name)…"
        let scanner = DiskScanner(); worker = scanner
        DispatchQueue.global(qos: .utility).async {
            let (rows, err) = scanner.children(item)
            DispatchQueue.main.async {
                self.busy = false; self.worker = nil
                if scanner.cancelled { self.status = "Inspection cancelled"; return }
                self.drillStack.append((self.drillPath, self.drilled)); self.drillPath = item.path; self.drilled = rows.sorted { $0.bytes > $1.bytes }
                self.status = err.isEmpty ? "\(rows.count) items in \(item.name)" : "Partial folder view · some items could not be read"
                self.warnings += err
            }
        }
    }
    func back() { if let last = drillStack.popLast() { drillPath = last.0; drilled = last.1 } }
    func resetDrill() { drillPath = nil; drilled = []; drillStack = [] }
    func prepare(_ selected: [StorageItem], manual: Bool = false) {
        guard !busy, !selected.isEmpty else { return }; manualReview = manual; busy = true; status = "Checking selected items and running apps…"
        let scanner = DiskScanner(); worker = scanner
        DispatchQueue.global(qos: .utility).async {
            let (names, available) = Self.processList(scanner)
            var review = [ReviewItem]()
            for item in selected {
                if scanner.cancelled { break }
                var problem: String?
                if !(manual ? self.safety.manualEligible(item) : self.safety.eligible(item)) { problem = "Not eligible, incomplete, or changed since the scan." }
                if !available && self.safety.rule(item.path)?.owner != "npm" { problem = "Could not check running processes. Cleanup is blocked." }
                let blockers = self.safety.blockers(item, processNames: names)
                if !blockers.isEmpty { problem = "Quit \(blockers.joined(separator: ", ")) and its helpers, then run the preview again." }
                if problem == nil { problem = scanner.mountedImageProblem(item) }
                var fresh = item
                if problem == nil {
                    let (items, err) = scanner.measure(item.path, category: item.category, children: false)
                    if let i = items.first, !i.partial, err.isEmpty, (manual ? self.safety.manualEligible(i) : self.safety.eligible(i)) { fresh = i } else { problem = "Could not completely measure this item." }
                }
                if problem == nil {
                    problem = scanner.usageProblem(fresh)
                }
                review.append(ReviewItem(item: fresh, problem: problem))
            }
            let result = review
            DispatchQueue.main.async {
                self.busy = false; self.worker = nil; self.processes = names; self.processCheckAvailable = available
                if scanner.cancelled { self.status = "Cleanup preview cancelled"; return }
                self.review = result; self.showReview = true; self.status = "Cleanup preview ready · nothing has been removed"
            }
        }
    }
    func cleanReviewed() {
        let ready = review.filter { $0.problem == nil }.map(\.item)
        guard !busy, !ready.isEmpty else { return }
        // Never accept nested selections; this also prevents double counting in the preview.
        guard !ready.contains(where: { a in ready.contains(where: { b in a.path != b.path && a.path.hasPrefix(b.path + "/") }) }) else { tell("Overlapping items selected. Choose each cache once."); return }
        let manual = manualReview
        showReview = false; busy = true; status = "Rechecking and moving selected items to Trash…"
        let scanner = DiskScanner(); worker = scanner
        DispatchQueue.global(qos: .utility).async {
            var records: [CleanupRecord]
            do { records = try self.store.read(); try self.store.save(records) }
            catch { DispatchQueue.main.async { self.busy = false; self.worker = nil; self.tell("Cleanup stopped: could not safely read or save history. \(error.localizedDescription)") }; return }
            var moved = [String](), failures = [String]()
            for item in ready {
                if scanner.cancelled { break }
                guard (manual ? self.safety.manualEligible(item) : self.safety.eligible(item)) else { failures.append("\(item.name): changed or no longer eligible"); continue }
                let (names, available) = Self.processList(scanner)
                guard (available || self.safety.rule(item.path)?.owner == "npm"), self.safety.blockers(item, processNames: names).isEmpty else { failures.append("\(item.name): related process running or process check unavailable"); continue }
                if let problem = scanner.mountedImageProblem(item) { failures.append("\(item.name): \(problem)"); continue }
                let (fresh, err) = scanner.measure(item.path, category: item.category, children: false)
                guard let current = fresh.first, err.isEmpty, !current.partial, current.bytes == item.bytes, current.modified == item.modified else { failures.append("\(item.name): contents changed after preview; scan again"); continue }
                if let problem = scanner.usageProblem(item) { failures.append("\(item.name): \(problem)"); continue }
                guard (manual ? self.safety.manualEligible(item) : self.safety.eligible(item)), !scanner.cancelled else { failures.append("\(item.name): changed or cancelled"); continue }
                do {
                    var destination: NSURL?
                    try files.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: &destination)
                    moved.append(item.path)
                    guard let path = destination?.path else { failures.append("\(item.name): moved to Trash, but restore location was not returned. Use Finder to restore."); break }
                    records.insert(CleanupRecord(id: UUID(), date: Date(), original: item.path, trashed: path, identity: fileIdentity(path), bytes: item.bytes, restored: false, manual: manual), at: 0)
                    do { try self.store.save(records) } catch { failures.append("History could not be saved. Restore the last item through Finder’s Trash. \(error.localizedDescription)"); break }
                } catch { failures.append("\(item.name): \(error.localizedDescription)") }
            }
            let finalRecords = records, finalMoved = moved, finalFailures = failures
            DispatchQueue.main.async {
                self.childrenByPath = [:]; self.expanded = []; self.folderMessages = [:]; self.history = finalRecords; self.busy = false; self.worker = nil
                self.installers.removeAll { finalMoved.contains($0.path) }; self.candidates.removeAll { finalMoved.contains($0.path) }; self.entries.removeAll { finalMoved.contains($0.path) }; self.drilled.removeAll { finalMoved.contains($0.path) }
                self.status = "\(finalMoved.count) item(s) moved to Trash. Scan again to refresh parent sizes."; self.refreshDisk()
                self.tell("\(finalMoved.count) item(s) moved to Trash. Disk space is freed only after you empty Trash in Finder. Use History to restore while the items remain in Trash.\n\n" + finalFailures.joined(separator: "\n"))
            }
        }
    }
    func restore(_ record: CleanupRecord) {
        guard !busy, !record.restored else { return }
        let src = URL(fileURLWithPath: record.trashed), dst = URL(fileURLWithPath: record.original)
        guard safety.restorable(record) else { tell("Restore blocked: the item changed, the destination was recreated, or the recorded path is not supported. Inspect it in Finder; existing folders are never overwritten."); return }

        let alert = NSAlert(); alert.messageText = "Restore \(dst.lastPathComponent)?"; alert.informativeText = "Move it from Trash back to:\n\(dst.path)"; alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Restore")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do {
            guard safety.restorable(record) else { tell("Files changed. Restore cancelled."); return }
            let (running, checked) = Self.processList(DiskScanner())
            let probe = StorageItem(path: record.original, bytes: record.bytes, category: "Restore", partial: false, identity: record.identity, modified: nil)
            guard checked, safety.blockers(probe, processNames: running).isEmpty else { tell("Quit the related app and its helpers before restoring this cache."); return }
            try files.moveItem(at: src, to: dst)
            if let i = history.firstIndex(where: { $0.id == record.id }) { history[i].restored = true }
            do { try store.save(history) } catch { tell("The item was restored, but history could not be saved: \(error.localizedDescription)"); return }
            refreshDisk(); tell("Restored successfully. Run a fresh scan to update the sizes.")
        } catch { tell("Could not restore: \(error.localizedDescription)") }
    }
    func export(json: Bool) {
        guard !busy else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = json ? "Storage-Lens-Report.json" : "Storage-Lens-Report.csv"; panel.title = "Export storage report — contains local file paths"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if json {
                struct Report: Encodable { let app = "Storage Lens"; let publisher = "Eridyn"; let version = "1.1.3"; let scannedAt: Date?; let capacity: Int64; let free: Int64; let locations: [StorageItem]; let cleanupCandidates: [StorageItem]; let accessErrors: String; let snapshots: String }
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(Report(scannedAt: scannedAt, capacity: capacity, free: free, locations: entries, cleanupCandidates: candidates, accessErrors: warnings, snapshots: snapshots)).write(to: url, options: .atomic)
            } else {
                func quote(_ s: String) -> String { let safe = ["=", "+", "-", "@", "\t", "\r"].contains(where: { s.hasPrefix($0) }) ? "'" + s : s; return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
                let rows = entries.map { [quote($0.name), quote($0.path), String($0.bytes), quote($0.category), quote(assessment($0)), $0.partial ? "true" : "false"].joined(separator: ",") }
                try ("Name,Path,Allocated bytes,Category,Cleanup guidance,Partial\n" + rows.joined(separator: "\n")).write(to: url, atomically: true, encoding: .utf8)
            }
            tell("Report saved to \(url.path). It contains local folder paths; review before sharing.")
        } catch { tell("Export failed: \(error.localizedDescription)") }
    }
}
