import SwiftUI
import Charts
import Cocoa

typealias ViewState<Value> = SwiftUI.State<Value>

let brand = Color(red: 0.15, green: 0.65, blue: 0.62)
let categoryColors: [String: Color] = ["Installed apps": .mint, "Applications": .indigo, "Caches": .teal, "Developer": .blue, "Cloud & personal": .cyan, "System": .orange, "Installer staging": .pink, "Logs": .purple]
let sections = [("Overview", "chart.pie"), ("Applications", "app.badge"), ("Cleanup", "sparkles"), ("Installers", "shippingbox"), ("All locations", "internaldrive"), ("Developer", "hammer"), ("System", "gearshape.2"), ("Cloud & personal", "cloud"), ("History", "clock.arrow.circlepath")]

@main struct StorageLensApp: App {
    @StateObject private var model = StorageModel()
    var body: some Scene {
        WindowGroup("Storage Lens — By Eridyn") { MainView().environmentObject(model).frame(minWidth: 1100, minHeight: 740) }
            .defaultSize(width: 1320, height: 880)
            .commands {
                CommandGroup(replacing: .appInfo) { Button("About Storage Lens") { NSApplication.shared.orderFrontStandardAboutPanel(options: [.applicationName: "Storage Lens", .applicationVersion: "1.1.3", .version: "5"]) } }
                CommandGroup(after: .newItem) { Button("Scan Mac") { model.scan() }.keyboardShortcut("r").disabled(model.busy) }
            }
    }
}
struct MainView: View {
    @EnvironmentObject var model: StorageModel
    @ViewState<String> private var section = "Overview"
    @ViewState<String> private var search = ""
    @ViewState<String> private var filter = "All items"
    @ViewState<Int64> private var minimum: Int64 = 0
    @ViewState<Set<String>> private var selection = Set<String>()
    @ViewState<String?> private var appFilter: String?
    @ViewState<String> private var sort = "Largest first"
    @ViewState<[StorageItem]> private var visibleRows = []
    @ViewState<[String: StorageItem]> private var visibleByID = [:]
    @ViewState<[String: Int]> private var rowDepths = [:]
    @ViewState<Bool> private var showResearch = false
    @ViewState<String> private var researchQuery = "macOS file storage"
    private var source: [StorageItem] {
        if model.drillPath != nil { return model.drilled }
        if section == "Cleanup" { return model.candidates }
        if section == "Installers" { return model.installers }
        if let owner = appFilter { return model.entries.filter { ownerName($0) == owner } }
        if ["Developer", "System", "Cloud & personal"].contains(section) { return model.entries.filter { $0.category == section } }
        return model.entries
    }
    private var rows: [StorageItem] { visibleRows }
    private func refreshRows() {
        let visible = model.flattened(source, sort: sort)
        let result = visible.filter { item in
            let matches = search.isEmpty || (item.path + " " + item.category + " " + model.itemSubtitle(item)).localizedCaseInsensitiveContains(search)
            let safe = filter == "Rebuildable / old logs" || filter == "Review manually" ? model.displayEligible(item) : false
            let filterMatch = filter == "All items" || (filter == "Rebuildable / old logs" && safe) || (filter == "Review manually" && !safe && item.category != "System" && !item.partial) || (filter == "System managed" && item.category == "System") || (filter == "Incomplete scan" && item.partial)
            return matches && item.bytes >= minimum && filterMatch
        }
        var matches = Set(result.map(\.path))
        for item in result {
            var parent = (item.path as NSString).deletingLastPathComponent
            while parent != "/" && !parent.isEmpty { matches.insert(parent); parent = (parent as NSString).deletingLastPathComponent }
        }
        visibleRows = visible.filter { matches.contains($0.path) }
        visibleByID = Dictionary(visibleRows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let rootPaths = Set(source.map(\.path))
        var depths = [String: Int]()
        for item in visibleRows { depths[item.path] = rootPaths.contains(item.path) ? 0 : (depths[(item.path as NSString).deletingLastPathComponent] ?? 0) + 1 }
        rowDepths = depths
    }
    private var selectedItems: [StorageItem] { selection.sorted().compactMap { visibleByID[$0] } }
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "internaldrive.fill").font(.title2).foregroundStyle(brand)
                    VStack(alignment: .leading, spacing: 2) { Text("Storage Lens").font(.headline); Text("BY ERIDYN").font(.system(size: 9, weight: .semibold, design: .rounded)).tracking(2).foregroundStyle(.secondary) }
                }.padding(20)
                List(selection: $section) {
                    ForEach(sections, id: \.0) { name, icon in Label(name, systemImage: icon).tag(name).padding(.vertical, 4) }
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Local & private", systemImage: "lock.shield").font(.caption.weight(.medium))
                    Text("Local scans. Online research only when requested.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text("Eridyn · 1.1.3").font(.caption2).foregroundStyle(.secondary)
                }.padding(18)
            }.navigationSplitViewColumnWidth(min: 195, ideal: 210, max: 240)
        } detail: {
            VStack(spacing: 0) {
                header
                Divider()
                if section == "Overview" { dashboard }
                else if section == "Applications" && appFilter == nil { applications }
                else if section == "History" { history }
                else { explorer }
                Divider()
                HStack(spacing: 8) {
                    if model.busy { ProgressView().controlSize(.small) }
                    Text(model.status).font(.caption).lineLimit(1)
                    Spacer()
                    if model.scannedAt != nil { Text(model.scannedAt!, style: .time).font(.caption).foregroundStyle(.secondary) }
                    if !model.warnings.isEmpty { Button("Scan coverage") { model.showAccess = true }.buttonStyle(.link).font(.caption) }
                }.padding(.horizontal, 22).padding(.vertical, 12)
                if model.busy { ProgressView(value: model.progress).tint(brand).frame(height: 3) }
            }.background(Color(nsColor: .windowBackgroundColor))
        }
        .onChange(of: section) { _, _ in model.resetDrill(); appFilter = nil; selection = []; search = ""; filter = "All items" }
        .onChange(of: selection) { _, _ in showResearch = false }
        .onAppear { refreshRows() }
        .onChange(of: model.chromeProfileNames) { _, _ in refreshRows() }
        .onChange(of: model.entries) { _, _ in refreshRows() }
        .onChange(of: model.candidates) { _, _ in refreshRows() }
        .onChange(of: model.installers) { _, _ in refreshRows() }
        .onChange(of: model.childrenByPath) { _, _ in refreshRows() }
        .onChange(of: model.expanded) { _, _ in refreshRows() }
        .onChange(of: section) { _, _ in refreshRows() }
        .onChange(of: appFilter) { _, _ in refreshRows() }
        .onChange(of: search) { _, _ in refreshRows() }
        .onChange(of: filter) { _, _ in refreshRows() }
        .onChange(of: minimum) { _, _ in refreshRows() }
        .onChange(of: sort) { _, _ in refreshRows() }
        .sheet(isPresented: $model.showReview) { ReviewView().environmentObject(model) }
        .sheet(isPresented: $model.showAccess) { AccessView().environmentObject(model) }
        .alert("Storage Lens · Eridyn", isPresented: $model.showNotice) { Button("OK", role: .cancel) {} } message: { Text(model.notice) }
    }
    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(appFilter ?? section).font(.system(size: 26, weight: .semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Menu { Button("Export JSON report") { model.export(json: true) }; Button("Export CSV report") { model.export(json: false) } } label: { Label("Export", systemImage: "square.and.arrow.up") }.fixedSize().disabled(model.busy || model.scannedAt == nil)
            if model.busy { Button("Stop") { model.cancel() } }
            else { Button(action: { selection = []; model.scan() }) { Label(model.scannedAt == nil ? "Scan Mac" : "Scan again", systemImage: "arrow.clockwise") }.buttonStyle(.borderedProminent).tint(brand) }
        }.padding(24)
    }
    private var subtitle: String {
        switch section {
        case "Overview": return "Understand your storage before changing it."
        case "Applications": return "Installed apps and associated data, grouped by likely owner."
        case "Cleanup": return "Recognized caches and old logs. Review consequences before moving anything."
        case "History": return "See what changed. Restore items while they remain in Trash."
        default: return "Explore folders, understand their purpose, and choose the right action."
        }
    }
    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    StatCard(title: "Available on disk", value: readableSize(model.free), detail: "of \(readableSize(model.capacity)) capacity", icon: "internaldrive", color: brand)
                    StatCard(title: "Measured locations", value: model.scannedAt == nil ? "—" : readableSize(model.measured), detail: "Apps and selected storage locations", icon: "folder", color: .indigo)
                    StatCard(title: "Cleanup candidates", value: model.scannedAt == nil ? "—" : readableSize(model.cacheBytes), detail: "Includes caches that may be in use", icon: "sparkles", color: .orange)
                }
                if model.scannedAt == nil {
                    VStack(spacing: 14) { Image(systemName: "internaldrive").font(.system(size: 50)).foregroundStyle(brand); Text("Get a clear picture of your Mac").font(.title2.weight(.semibold)); Text("Scan common app-support, cache, developer and system locations.\nYour files stay on this Mac; the scan does not delete anything.").multilineTextAlignment(.center).foregroundStyle(.secondary); Button("Start read-only scan") { model.scan() }.buttonStyle(.borderedProminent).tint(brand).disabled(model.busy) }.frame(maxWidth: .infinity).padding(45).card()
                } else {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your disk").font(.headline)
                            Chart {
                                SectorMark(angle: .value("Bytes", max(0, model.capacity - model.free)), innerRadius: .ratio(0.72), angularInset: 2).foregroundStyle(brand)
                                SectorMark(angle: .value("Bytes", model.free), innerRadius: .ratio(0.72), angularInset: 2).foregroundStyle(Color.secondary.opacity(0.17))
                            }.frame(height: 190).chartBackground { _ in VStack { Text(String(format: "%.0f%%", model.capacity > 0 ? Double(model.capacity - model.free) / Double(model.capacity) * 100 : 0)).font(.system(size: 30, weight: .semibold, design: .rounded)); Text("used").foregroundStyle(.secondary) } }
                            HStack { Circle().fill(brand).frame(width: 8, height: 8); Text("Used \(readableSize(max(0, model.capacity - model.free)))"); Spacer(); Text("Free \(readableSize(model.free))").foregroundStyle(.secondary) }.font(.caption)
                            Text("Volume-reported capacity and free space. Available space can change as macOS reclaims storage.").font(.caption).foregroundStyle(.secondary)
                        }.padding(20).frame(maxWidth: .infinity).card()
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Measured storage by category").font(.headline)
                            ForEach(model.categories, id: \.0) { name, bytes in
                                VStack(spacing: 5) {
                                    HStack { Circle().fill(categoryColors[name] ?? .gray).frame(width: 8, height: 8); Text(name).font(.caption); Spacer(); Text(readableSize(bytes)).font(.caption.monospacedDigit()) }
                                    GeometryReader { g in RoundedRectangle(cornerRadius: 3).fill((categoryColors[name] ?? .gray).opacity(0.8)).frame(width: max(2, g.size.width * Double(bytes) / Double(max(1, model.measured)))) }.frame(height: 5)
                                }
                            }
                            Text("These measured folders are a subset of the Mac. They are not Apple’s System Data classification; unreadable files and APFS sharing affect totals.").font(.caption).foregroundStyle(.secondary)
                        }.padding(20).frame(maxWidth: .infinity).card()
                    }
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Largest measured locations").font(.headline)
                            ForEach(Array(model.entries.prefix(6))) { item in
                                Button { section = "All locations"; DispatchQueue.main.async { selection = [item.id] } } label: {
                                    HStack(spacing: 10) { Image(nsImage: appIcon(ownerName(item))).resizable().scaledToFit().frame(width: 28, height: 28); VStack(alignment: .leading) { Text(model.itemTitle(item)).lineLimit(1); Text(item.category).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(readableSize(item.bytes)).monospacedDigit() }
                                }.buttonStyle(.plain)
                            }
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).card()
                        VStack(alignment: .leading, spacing: 14) {
                            Text("A safer way to clean").font(.headline)
                            guide("1", "Understand the item", "Read its purpose and what cleanup changes.")
                            guide("2", "Quit the related app", "Running processes and open files are checked.")
                            guide("3", "Preview, then move to Trash", "Only recognized caches and old logs are eligible.")
                            guide("4", "Try your apps before emptying Trash", "Use History to restore. Storage is freed when you empty Trash yourself.")
                            Button("Review cleanup candidates") { section = "Cleanup" }.buttonStyle(.borderedProminent).tint(brand)
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).card()
                    }
                }
            }.padding(24)
        }
    }
    private func guide(_ n: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 10) { Text(n).font(.caption.bold()).frame(width: 24, height: 24).background(brand.opacity(0.15), in: Circle()); VStack(alignment: .leading, spacing: 3) { Text(title).font(.subheadline.weight(.medium)); Text(body).font(.caption).foregroundStyle(.secondary) } }
    }
    private var applications: some View {
        VStack(spacing: 12) {
            searchBox.padding(.horizontal, 24).padding(.top, 16)
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(model.apps.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { group in
                        Button { appFilter = group.name; selection = []; search = "" } label: {
                            HStack(spacing: 16) {
                                Image(nsImage: appIcon(group.name)).resizable().scaledToFit().frame(width: 42, height: 42)
                                VStack(alignment: .leading, spacing: 4) { Text(group.name).font(.headline); Text("\(group.items.count) measured location(s) · \(group.items.contains(where: \.partial) ? "partial access" : "support files & caches")").font(.caption).foregroundStyle(.secondary) }
                                Spacer(); Text(readableSize(group.bytes)).font(.title3.monospacedDigit()); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }.padding(16).card()
                        }.buttonStyle(.plain)
                    }
                    if model.apps.isEmpty { Text("Run a scan to see app-related storage.").foregroundStyle(.secondary).padding(40) }
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
    }
    private var searchBox: some View {
        HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Search measured files, folders or apps", text: $search).textFieldStyle(.plain); if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) } }.padding(9).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
    private var explorer: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                if let path = model.drillPath {
                    HStack { Button { selection = []; model.back() } label: { Label("Back", systemImage: "chevron.left") }; Text(path.replacingOccurrences(of: userHome, with: "~")).font(.caption).lineLimit(1).truncationMode(.middle); Spacer() }
                } else if appFilter != nil { HStack { Button("← All applications") { appFilter = nil; selection = [] }; Spacer() } }
                HStack(spacing: 12) {
                    searchBox
                    Picker("Show", selection: $filter) { ForEach(["All items", "Rebuildable / old logs", "Review manually", "System managed", "Incomplete scan"], id: \.self) { Text($0) } }.labelsHidden().frame(width: 175)
                    Picker("Size", selection: $minimum) { Text("Any size").tag(Int64(0)); Text("100 MB+").tag(Int64(100_000_000)); Text("1 GB+").tag(Int64(1_000_000_000)) }.labelsHidden().frame(width: 105)
                    Picker("Sort", selection: $sort) { ForEach(["Largest first", "Smallest first", "Name A–Z"], id: \.self) { Text($0) } }.labelsHidden().frame(width: 125)
                }
                if section == "Installers" { Text("Downloaded .dmg and .pkg files found in Downloads, user caches and Application Support. Only recognized cache locations receive a lower-risk rating; other installers require review.").font(.caption).foregroundStyle(.secondary) }
                if section == "Cleanup" { Label("Candidates are not guaranteed free space. Quit related apps and review the effects; cleanup never empties Trash.", systemImage: "info.circle").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
            }.padding(18)
            HSplitView {
                VStack(spacing: 0) {
                    Table(rows, selection: $selection) {
                        TableColumn("Item / owner") { item in
                            HStack(spacing: 6) {
                                if item.directory {
                                    Button { model.toggleFolder(item) } label: {
                                        Image(systemName: model.expanded.contains(item.path) ? "chevron.down" : "chevron.right").frame(width: 16)
                                    }.buttonStyle(.plain).disabled(model.busy && model.loadingPath != item.path).help("Expand or collapse folder")
                                } else { Color.clear.frame(width: 16, height: 1) }
                                Image(nsImage: (rowDepths[item.path] ?? 0) == 0 ? appIcon(ownerName(item)) : fileIcon(item.path)).resizable().scaledToFit().frame(width: 25, height: 25)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.itemTitle(item)).lineLimit(1).help(model.itemTitle(item) + "\n" + item.path)
                                    if model.loadingPath == item.path { Text("Measuring contents…").font(.caption2).foregroundStyle(brand) }
                                    else if let message = model.folderMessages[item.path], !message.isEmpty { Text(message).font(.caption2).foregroundStyle(.secondary) }
                                    else { Text(model.itemSubtitle(item)).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                                    if (rowDepths[item.path] ?? 0) > 0 { Text("Included in parent total").font(.system(size: 9)).foregroundStyle(.secondary) }
                                }
                            }.padding(.leading, CGFloat((rowDepths[item.path] ?? 0)) * 16).padding(.vertical, 3)
                        }.width(min: 240, ideal: 350)

                        TableColumn("On disk") { item in Text(item.measuring ? "Calculating…" : (item.partial ? "≥ " : "") + readableSize(item.bytes)).monospacedDigit() }.width(95)
                        TableColumn("Guidance") { item in Text(model.assessment(item)).font(.caption).foregroundStyle(tone(item)).lineLimit(2) }.width(min: 140, ideal: 170)
                    }.contextMenu(forSelectionType: String.self) { ids in
                        if let first = rows.first(where: { ids.contains($0.id) }) {
                            Button("Show in Finder") { reveal(first) }
                            Button("Move to Bin…") { model.prepare(rows.filter { ids.contains($0.id) }, manual: true) }.disabled(model.busy || !model.safety.manualEligible(first))
                            if first.directory { Button(model.expanded.contains(first.path) ? "Collapse folder" : "Expand folder") { model.toggleFolder(first) } }
                        }
                    }
                    HStack { Text("\(rows.count) items · ⌘-click to select multiple").font(.caption).foregroundStyle(.secondary); Spacer(); if !selectedItems.isEmpty { Text("\(selectedItems.count) selected").font(.caption) } }.padding(12)
                }.frame(minWidth: 530)
                inspector.frame(minWidth: 270, idealWidth: 295, maxWidth: 345)
            }
            HStack {
                Text(selectedItems.isEmpty ? "Select an item for its meaning and cleanup guidance." : "Selected: \(readableSize(selectedItems.reduce(0) { $0 + $1.bytes }))").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Move to Bin…") { model.prepare(selectedItems, manual: true) }.disabled(model.busy || selectedItems.isEmpty || !selectedItems.allSatisfy(model.safety.manualEligible))
                Button("Preview cleanup…") { model.prepare(selectedItems) }.buttonStyle(.borderedProminent).tint(brand).disabled(model.busy || selectedItems.isEmpty || !selectedItems.contains(where: model.displayEligible))
            }.padding(16)
        }
    }
    private func tone(_ item: StorageItem) -> Color { if item.partial { return .orange }; if model.displayEligible(item) { return model.safety.blockers(item, processNames: model.processes).isEmpty ? brand : .orange }; return .secondary }
    private func reveal(_ item: StorageItem) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)]) }
    private var inspector: some View {
        ScrollView {
            if let item = selectedItems.first {
                VStack(alignment: .leading, spacing: 18) {
                    Image(nsImage: appIcon(ownerName(item))).resizable().scaledToFit().frame(width: 48, height: 48)
                    Text(model.itemTitle(item)).font(.title3.weight(.semibold)).textSelection(.enabled)
                    if let profile = model.profileLabel(item) {
                        Text("Chrome profile: " + profile).font(.caption).textSelection(.enabled)
                        if let id = ChromeProfiles.identifier(for: item.path), model.chromeProfileNames[id] == nil {
                            Text("Account details are unavailable. Chrome’s local metadata may be protected, absent or unreadable. Folder identifiers are shown instead.").font(.caption).foregroundStyle(.secondary)
                            Button("Profile access help") { model.showAccess = true }
                        } else {
                            Text("Profile/account details saved locally by Chrome; live sign-in status is not checked. These details are not sent to web research.").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Text(model.assessment(item)).font(.caption.weight(.semibold)).foregroundStyle(tone(item)).padding(8).background(tone(item).opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                    Text((item.partial ? "At least " : "") + readableSize(item.bytes)).font(.system(size: 26, weight: .semibold, design: .rounded))
                    Divider()
                    Text("What is this?").font(.headline)
                    Text(model.safety.explanation(item)).font(.subheadline).foregroundStyle(.secondary)
                    if let guide = model.safety.browserGuidance(item) {
                        Text(guide.kind).font(.headline)
                        Text("Why keep it?").font(.caption.bold())
                        Text(guide.benefit).font(.caption).foregroundStyle(.secondary)
                        Text("Recommended action").font(.caption.bold())
                        Text(guide.action).font(.caption)
                        Text("Evidence").font(.caption.bold())
                        Text(guide.confidence).font(.caption).foregroundStyle(.secondary)
                        Link("Read the source", destination: URL(string: guide.source)!)
                        Text("Rule reviewed \(guide.reviewed)").font(.caption2).foregroundStyle(.secondary)
                        if model.safety.chromeCacheRule(item.path) == nil {
                            Text("In Chrome: Settings → Privacy and security → Delete browsing data. Choose categories deliberately; clearing cookies may sign you out.").font(.caption)
                        }
                    }
                    Text("Removal risk").font(.headline)
                    Text(model.safety.risk(item)).font(.caption.weight(.medium))
                    Text("Based on the local path and file type. Online sources do not certify that your copy is unused.").font(.caption).foregroundStyle(.secondary)
                    Button("Research on Web") {
                        researchQuery = researchTerms(item)
                        showResearch.toggle()
                    }
                    if showResearch {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Research on Web").font(.headline)
                            TextField("Search terms", text: $researchQuery).textFieldStyle(.roundedBorder)
                            Button("Search Google ↗") {
                                var components = URLComponents(string: "https://www.google.com/search")!
                                components.queryItems = [URLQueryItem(name: "q", value: researchQuery)]
                                if let url = components.url { NSWorkspace.shared.open(url) }
                            }
                            Text("For now, Google opens in your browser. Inline web summaries are not connected yet. Only these search terms are sent; file contents stay on your Mac.").font(.caption2).foregroundStyle(.secondary)
                        }.padding(10).card()
                    }
                    if let rule = model.safety.rule(item.path) {
                        Text("Before cleanup").font(.headline)
                        Text(rule.owner == "npm" ? "Stop package installs before cleaning. Unrelated Node processes do not block this cache. Preview checks processes with open files or working directories in the selected cache, and checks again before moving it to Bin. A process can start using it after a check, so avoid starting installs during cleanup." : "Quit \(rule.owner) and stop related downloads/builds. Storage Lens checks running processes and open files, then moves the selected cache to Trash. It cannot guarantee that every third-party app handles a missing cache identically.").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Location").font(.caption.weight(.semibold)); Text(item.path).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    if let d = item.modified { Text("Modified \(d.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                    Button("Show in Finder") { reveal(item) }
                    Button("Move to Bin…") { model.prepare([item], manual: true) }.disabled(model.busy || !model.safety.manualEligible(item))
                    if item.directory { Button(model.expanded.contains(item.path) ? "Collapse folder" : "Expand folder") { model.toggleFolder(item) }.disabled(model.busy) }
                    if item.category == "System" { Button("Open macOS Storage") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.Storage")!) } }
                    if selectedItems.count > 1 { Text("Showing details for the first of \(selectedItems.count) selected items. The preview reviews each item individually.").font(.caption).foregroundStyle(.secondary) }
                }.padding(20)
            } else {
                VStack(spacing: 12) { Image(systemName: "info.circle").font(.largeTitle).foregroundStyle(brand); Text("Know before you clean").font(.headline); Text("Select a row to see what it means, whether cleanup is supported, and what happens afterward.").multilineTextAlignment(.center).font(.subheadline).foregroundStyle(.secondary) }.padding(25).frame(maxWidth: .infinity)
            }
        }.background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    private var history: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Moving to Trash does not reclaim space yet. Test your apps, then empty Trash yourself when you are satisfied. Restores never overwrite recreated folders.").font(.subheadline).foregroundStyle(.secondary)
                if model.history.isEmpty { ContentUnavailableView("No cleanup yet", systemImage: "clock.arrow.circlepath", description: Text("Items moved by Storage Lens will appear here.")) }
                ForEach(model.history) { record in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Image(systemName: record.restored ? "arrow.uturn.backward.circle" : "trash").foregroundStyle(brand); Text(URL(fileURLWithPath: record.original).lastPathComponent).font(.headline); Spacer(); Text(readableSize(record.bytes)); Text(record.restored ? "Restored" : "Moved to Trash").font(.caption).foregroundStyle(.secondary) }
                        Text(record.original).font(.caption).textSelection(.enabled)
                        HStack { Text(record.date.formatted()).font(.caption).foregroundStyle(.secondary); Spacer(); Button("Show Trash item") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: record.trashed)]) }.disabled(record.restored); Button("Restore…") { model.restore(record) }.disabled(record.restored || model.busy) }
                    }.padding(16).card()
                }
            }.padding(24)
        }
    }
}
struct StatCard: View {
    let title: String, value: String, detail: String, icon: String
    let color: Color
    var body: some View { VStack(alignment: .leading, spacing: 10) { HStack { Text(title).font(.subheadline).foregroundStyle(.secondary); Spacer(); Image(systemName: icon).foregroundStyle(color) }; Text(value).font(.system(size: 30, weight: .semibold, design: .rounded)); Text(detail).font(.caption).foregroundStyle(.secondary) }.padding(20).frame(maxWidth: .infinity, alignment: .leading).card() }
}
extension View { func card() -> some View { self.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.06), lineWidth: 1)) } }
struct ReviewView: View {
    @EnvironmentObject var model: StorageModel
    @ViewState<Bool> private var acknowledged = false
    var ready: [ReviewItem] { model.review.filter { $0.problem == nil } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.manualReview ? "Review before moving to Bin" : "Review before cleanup").font(.title2.weight(.semibold))
            Text("\(ready.count) eligible item(s) · \(readableSize(ready.reduce(0) { $0 + $1.item.bytes })) to move to Trash").font(.headline).foregroundStyle(brand)
            ScrollView { VStack(alignment: .leading, spacing: 14) { ForEach(model.review) { row in VStack(alignment: .leading, spacing: 6) { HStack { Text(model.itemTitle(row.item)).font(.headline); Spacer(); Text(readableSize(row.item.bytes)) }; Text(row.item.path).font(.caption).textSelection(.enabled); Text(row.problem ?? model.safety.explanation(row.item)).font(.caption).foregroundStyle(row.problem == nil ? Color.secondary : .orange) }.padding(12).card() } } }.frame(maxHeight: 360)
            Text("Blocked items will be skipped. Eligible items are checked again immediately before moving. Caches may rebuild or download again; old logs may no longer be available for troubleshooting.").font(.subheadline).foregroundStyle(.secondary)
            if model.manualReview { Text("Manual removal can reset settings, remove saved work, or break app features. A file being movable does not mean it is safe to remove. Restoring from Bin may not undo changes an app makes afterward.").foregroundStyle(.orange) }
            Toggle("I have closed related apps and stopped builds/downloads. I understand the effects above.", isOn: $acknowledged).toggleStyle(.checkbox)
            Text("Nothing is permanently deleted. Disk space is freed only after you empty Trash in Finder.").font(.caption).foregroundStyle(.secondary)
            HStack { Button("Cancel") { model.showReview = false }.keyboardShortcut(.cancelAction); Spacer(); Button("Move \(ready.count) item(s) to Trash") { model.cleanReviewed() }.buttonStyle(.borderedProminent).tint(brand).disabled(!acknowledged || ready.isEmpty) }
        }.padding(26).frame(width: 690)
    }
}
struct AccessView: View {
    @EnvironmentObject var model: StorageModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scan coverage & access").font(.title2.weight(.semibold))
            Text("Storage Lens scans common storage locations, not every file on the disk. macOS protects some folders. An unreadable folder is unknown, never assumed empty.")
            Text("For broader visibility, you can grant Storage Lens Full Disk Access in System Settings → Privacy & Security, then quit and reopen it. This is optional and broadens what the app can read; cleanup rules stay restricted.").foregroundStyle(.secondary)
            Button("Open Full Disk Access settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!) }
            Text("Time Machine snapshot check").font(.headline)
            Text(model.snapshots.isEmpty ? "No output available" : model.snapshots).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
            Text("Access limitations").font(.headline)
            ScrollView { Text(model.warnings.isEmpty ? "No access errors in the locations checked." : model.warnings).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 220)
            HStack { Text("Storage Lens · By Eridyn · 1.1.3").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Done") { model.showAccess = false }.keyboardShortcut(.cancelAction) }
        }.padding(26).frame(width: 720)
    }
}

// Queries use known technical names only; arbitrary personal filenames stay local.
func researchTerms(_ item: StorageItem) -> String {
    let known = ["Claude", "Codex", "Google Chrome", "Slack", "Visual Studio Code", "Android Studio", "Xcode & Simulators", "npm", "Homebrew", "pip", "Adobe"]
    let owner = ownerName(item)
    let app = known.contains(owner) ? owner : "macOS"
    let names = ["cache", "code cache", "gpucache", "indexeddb", "local storage", "vm_bundles", "codex-runtimes", "worktrees", "_cacache", "_npx", "rootfs.img", "sessiondata.img", "vmlinuz", "initrd"]
    let kind = names.contains(item.name.lowercased()) ? item.name : (item.directory ? "application support folder" : (["dmg", "pkg", "sqlite", "db", "log", "ips"].contains(URL(fileURLWithPath: item.path).pathExtension.lowercased()) ? URL(fileURLWithPath: item.path).pathExtension : "data file"))
    return "\(app) \(kind) purpose storage removal documentation"
}
