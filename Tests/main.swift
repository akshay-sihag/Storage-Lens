import Cocoa

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
let testRoot = URL(fileURLWithPath: files.currentDirectoryPath).appendingPathComponent("build/tests/fixture-" + UUID().uuidString).path
try files.createDirectory(atPath: testRoot, withIntermediateDirectories: true)
defer { try? files.removeItem(atPath: testRoot) }
let safety = Safety(home: testRoot)
let cache = testRoot + "/.npm/_cacache"
try files.createDirectory(atPath: cache, withIntermediateDirectories: true)
try Data(repeating: 1, count: 8192).write(to: URL(fileURLWithPath: cache + "/fixture"))
func item(_ p: String, partial: Bool = false) -> StorageItem { StorageItem(path: p, bytes: 8192, category: "Test", partial: partial, identity: fileIdentity(p), modified: nil) }
let original = item(cache)
expect(safety.eligible(original), "recognized npm cache accepted")
expect(!safety.eligible(item(testRoot + "/.npm")), "parent folder rejected")
expect(!safety.eligible(item(cache, partial: true)), "partial scan rejected")
expect(!safety.eligible(item(cache + "/../_cacache")), "noncanonical path rejected")
expect(!safety.eligible(item("/private/var")), "system path rejected")
expect(safety.blockers(original, processNames: ["node", "npm", "npx"]).isEmpty, "unrelated Node processes no longer block npm cache")
expect(safety.blockers(original, processNames: ["Finder"]).isEmpty, "unrelated process does not block")
try files.moveItem(atPath: cache, toPath: testRoot + "/saved")
try files.createSymbolicLink(atPath: cache, withDestinationPath: testRoot + "/saved")
expect(!safety.eligible(item(cache)), "symlink target rejected")
expect(!safety.eligible(original), "changed identity rejected")
try files.removeItem(atPath: cache)
try files.createDirectory(atPath: cache, withIntermediateDirectories: true)
expect(!safety.eligible(original), "replacement directory rejected")
let appData = testRoot + "/Library/Application Support/Claude"
try files.createDirectory(atPath: appData + "/Cache", withIntermediateDirectories: true)
try files.createDirectory(atPath: appData + "/IndexedDB", withIntermediateDirectories: true)
expect(safety.eligible(item(appData + "/Cache")), "specific renderer cache accepted")
expect(!safety.eligible(item(appData)), "whole app support rejected")
expect(!safety.eligible(item(appData + "/IndexedDB")), "application database rejected")
expect(!safety.blockers(item(appData + "/Cache"), processNames: ["Claude Helper (Renderer)"]).isEmpty, "app helpers block cleanup")
let log = testRoot + "/Library/Logs/Example/old.log"
try files.createDirectory(atPath: URL(fileURLWithPath: log).deletingLastPathComponent().path, withIntermediateDirectories: true)
try Data("test".utf8).write(to: URL(fileURLWithPath: log))
expect(!safety.oldLog(log), "recent log rejected")
try files.setAttributes([.modificationDate: Date().addingTimeInterval(-31 * 86400)], ofItemAtPath: log)
expect(safety.oldLog(log), "old diagnostic log accepted")
let db = testRoot + "/Library/Logs/Example/important.sqlite"
try files.copyItem(atPath: log, toPath: db)
expect(!safety.oldLog(db), "non-log file in logs rejected")
let trashDir = testRoot + "/.Trash/cache-fixture"
try files.createDirectory(atPath: trashDir, withIntermediateDirectories: true)
let restoreRecord = CleanupRecord(id: UUID(), date: Date(), original: testRoot + "/Library/Caches/typescript", trashed: trashDir, identity: fileIdentity(trashDir), bytes: 0, restored: false)
expect(safety.restorable(restoreRecord), "recognized restore destination accepted")
let maliciousRecord = CleanupRecord(id: UUID(), date: Date(), original: testRoot + "/.ssh/config", trashed: trashDir, identity: fileIdentity(trashDir), bytes: 0, restored: false)
expect(!safety.restorable(maliciousRecord), "history cannot restore into arbitrary sensitive paths")
try files.createDirectory(atPath: restoreRecord.original, withIntermediateDirectories: true)
expect(!safety.restorable(restoreRecord), "restore refuses existing destination")
let scanner = DiskScanner()
let (rows, _) = scanner.children(item(testRoot + "/saved"))
expect(rows.contains(where: { $0.name == "fixture" }), "drill-down includes files")
let (parents, _) = scanner.measure(testRoot + "/Library", category: "Test")
expect(!parents.contains(where: { $0.path == testRoot + "/Library" }), "parent total excluded to avoid double counting")
let (oldLogs, _) = scanner.oldLogs(safety: safety)
expect(oldLogs.count == 1, "old logs scan excludes unsupported files")
scanner.cancel()
let (_, _, code) = scanner.command("/bin/echo", ["should not run"])
expect(code == -2, "cancelled scanner does not launch commands")
// Test a real reversible Trash round-trip with only this generated fixture.
let trashFixture = testRoot + "/trash-fixture.txt"
try Data("Storage Lens synthetic test".utf8).write(to: URL(fileURLWithPath: trashFixture))
var result: NSURL?
try files.trashItem(at: URL(fileURLWithPath: trashFixture), resultingItemURL: &result)
expect(!files.fileExists(atPath: trashFixture), "fixture moved out of original location")
expect(result != nil && files.fileExists(atPath: result!.path!), "Trash destination returned")
try files.moveItem(at: result! as URL, to: URL(fileURLWithPath: trashFixture))
let restoredText = try String(contentsOfFile: trashFixture, encoding: .utf8)
expect(restoredText == "Storage Lens synthetic test", "fixture restored intact")
expect(safety.eligible(item(appData + "/Cache")), "cache root remains recognized")
let cacheFile = appData + "/Cache/download.pkg"
try Data("synthetic installer".utf8).write(to: URL(fileURLWithPath: cacheFile))
expect(safety.eligible(item(cacheFile)), "individual file in recognized cache accepted")
expect(!safety.blockers(item(cacheFile), processNames: ["Claude Helper"]).isEmpty, "cache child inherits process blockers")
expect(safety.installer(item(cacheFile)), "installer file recognized")
let downloads = testRoot + "/Downloads"
try files.createDirectory(atPath: downloads, withIntermediateDirectories: true)
let personalInstaller = downloads + "/saved.pkg"
try Data("synthetic personal package".utf8).write(to: URL(fileURLWithPath: personalInstaller))
expect(!safety.eligible(item(personalInstaller)), "installer extension alone does not authorize cleanup")
expect(safety.manualEligible(item(personalInstaller)), "download allows explicit manual review")
expect(!safety.manualEligible(item(personalInstaller, partial: true)), "manual cleanup rejects incomplete measurement")
expect(safety.manualEligible(item(appData)), "app support can be explicitly reviewed for manual removal")
expect(!safety.manualEligible(item(testRoot + "/Library")), "Library root protected")
expect(!safety.manualPath(testRoot + "/Library/Application Support/Storage Lens"), "own history protected")
expect(!safety.manualPath(testRoot + "/Documents/test.app/Contents"), "app bundle contents protected")
expect(!safety.manualPath(testRoot + "/Library/CloudStorage/drive/file"), "cloud files protected")
let link = downloads + "/linked.pkg"
try files.createSymbolicLink(atPath: link, withDestinationPath: personalInstaller)
expect(!safety.manualEligible(item(link)), "manual cleanup rejects symlink")
let (installerItems, _) = DiskScanner().installers(safety: safety)
expect(installerItems.contains { $0.path == personalInstaller }, "installer discovery finds Downloads files")
expect(installerItems.contains { $0.path == cacheFile }, "installer discovery finds cached files")
expect(!installerItems.contains { $0.path == link }, "installer discovery skips symlinks")
let manualRecord = CleanupRecord(id: UUID(), date: Date(), original: downloads + "/absent.pkg", trashed: trashDir, identity: fileIdentity(trashDir), bytes: 0, restored: false, manual: true)
expect(safety.restorable(manualRecord), "manual cleanup can restore to approved location")
let tree = StorageModel()
let treeRoot = item(appData)
let treeChild = item(appData + "/Cache")
let treeFile = item(cacheFile)
tree.childrenByPath[treeRoot.path] = [treeChild]
tree.childrenByPath[treeChild.path] = [treeFile]
expect(tree.flattened([treeRoot], sort: "Largest first").count == 1, "collapsed tree hides descendants")
tree.expanded = [treeRoot.path, treeChild.path]
expect(tree.flattened([treeRoot], sort: "Largest first").map(\.path) == [treeRoot.path, treeChild.path, treeFile.path], "expanded tree preserves parent child ordering")
expect(tree.depth(treeFile, roots: [treeRoot]) == 2, "nested file indentation follows hierarchy")
tree.expanded.remove(treeRoot.path)
expect(tree.flattened([treeRoot], sort: "Largest first").count == 1, "collapsing parent hides all descendant rows")
expect(DiskScanner().mountedImageProblem(item(personalInstaller)) == nil, "unmounted synthetic file passes disk-image check")
let chromeRoot = testRoot + "/Library/Caches/Google/Chrome"
let chromeCache = chromeRoot + "/Default/Cache"
let chromeStorage = chromeRoot + "/Default/Storage"
let chromeProfile = testRoot + "/Library/Application Support/Google/Chrome/Default"
for path in [chromeCache, chromeStorage, chromeProfile + "/IndexedDB", chromeRoot + "/Profile 2/Cache"] { try files.createDirectory(atPath: path, withIntermediateDirectories: true) }
for name in ["Cookies", "Login Data", "Bookmarks", "History"] { try Data("synthetic".utf8).write(to: URL(fileURLWithPath: chromeProfile + "/" + name)) }
expect(!safety.eligible(item(chromeRoot)), "whole Chrome cache root is not eligible")
expect(!safety.manualEligible(item(chromeRoot)), "manual mode cannot bypass mixed Chrome root protection")
expect(safety.eligible(item(chromeCache)), "identified Chrome page cache is eligible")
expect(!safety.eligible(item(chromeStorage)), "Chrome Storage is not treated as page cache")
expect(!safety.manualEligible(item(chromeStorage)), "Chrome Storage is protected in manual mode")
expect(!safety.manualEligible(item(chromeProfile)), "whole browser profile protected")
expect(!safety.manualPath(testRoot + "/Library/Application Support/Google"), "browser ancestor cannot bypass protection")
expect(!safety.manualEligible(item(chromeProfile + "/Cookies")), "cookies protected")
expect(!safety.manualEligible(item(chromeProfile + "/IndexedDB")), "offline site databases protected")
expect(!safety.manualEligible(item(chromeProfile + "/Bookmarks")), "bookmarks protected")
expect(!safety.manualEligible(item(chromeProfile + "/Login Data")), "saved credentials protected")
expect(safety.browserGuidance(item(chromeProfile + "/Cookies"))?.kind == "Cookies and sign-in state", "cookies have distinct explanation")
expect(safety.browserGuidance(item(chromeStorage))?.kind == "Site storage / offline data", "Storage receives offline-data warning")
expect(safety.discoveredChromeCaches().count == 2, "Chrome cache discovery supports multiple profiles")
expect(!safety.blockers(item(chromeCache), processNames: ["Google Chrome Helper (Renderer)"]).isEmpty, "Chrome helper blocks page cache removal")
expect(safety.chromeCacheRule(chromeRoot + "/Unknown/Cache") == nil, "unknown profile layout not auto-approved")
let fastModel = StorageModel(safety: safety)
let cachedFile = item(cacheFile)
expect(fastModel.displayEligible(cachedFile), "presentation eligibility cached from valid item")
try files.removeItem(atPath: cacheFile)
expect(fastModel.displayEligible(cachedFile), "display hint does not recheck disk on every redraw")
expect(!safety.eligible(cachedFile), "action-time validation rejects deleted item despite cached hint")
let metadataPath = downloads + "/metadata-test"
try files.createDirectory(atPath: metadataPath, withIntermediateDirectories: true)
let metadataItem = item(metadataPath)
try files.removeItem(atPath: metadataPath)
expect(metadataItem.directory, "directory display metadata is a scan snapshot")
expect(!safety.manualEligible(metadataItem), "snapshot cannot authorize removal after filesystem changes")
let preview = DiskScanner().immediateChildren(item(downloads))
expect(!preview.isEmpty && preview.allSatisfy { $0.measuring && $0.partial }, "early folder preview never claims measured sizes or cleanup eligibility")
let benchmarkStart = Date()
for _ in 0..<10000 { _ = fastModel.displayEligible(cachedFile) }
print(String(format: "10,000 cached display checks: %.2f ms", Date().timeIntervalSince(benchmarkStart) * 1000))
expect(DiskScanner.usageProblem(output: "p123\ncnode\n", error: "", code: 0)?.contains("node (PID 123)") == true, "usage blocker identifies process and PID")
expect(DiskScanner.usageProblem(output: "", error: "", code: 1) == nil, "no matching open handles permits cleanup")
expect(DiskScanner.usageProblem(output: "", error: "permission denied", code: 1) != nil, "usage permission failure blocks cleanup")
expect(DiskScanner.usageProblem(output: "", error: "", code: -3) != nil, "usage timeout blocks cleanup")
expect(DiskScanner.usageProblem(output: "p123\n", error: "", code: 0) != nil, "unparseable process record fails closed")
let usageDir = downloads + "/usage-fixture"
try files.createDirectory(atPath: usageDir, withIntermediateDirectories: true)
let usageFile = usageDir + "/held.txt"
try Data("test".utf8).write(to: URL(fileURLWithPath: usageFile))
let holder = Process(); holder.executableURL = URL(fileURLWithPath: "/bin/sh")
holder.arguments = ["-c", "exec 3< \"$1\"; exec /bin/sleep 30", "storage-lens-test", usageFile]
try holder.run()
defer { if holder.isRunning { holder.terminate(); holder.waitUntilExit() } }
var heldProblem: String?
for _ in 0..<5 {
    heldProblem = DiskScanner().usageProblem(item(usageDir))
    if heldProblem?.contains("PID \(holder.processIdentifier)") == true { break }
    Thread.sleep(forTimeInterval: 0.1)
}
expect(heldProblem?.contains("PID \(holder.processIdentifier)") == true, "real nested open file blocks and identifies holder")
expect(DiskScanner().usageProblem(item(personalInstaller)) == nil, "process holding different file does not block selected file")
holder.terminate(); holder.waitUntilExit()
expect(DiskScanner().usageProblem(item(usageDir)) == nil, "closing holder clears actual-use blocker")
let profileJSON = Data(#"{"profile":{"info_cache":{"Default":{"name":"Personal"},"Profile 1":{"name":"Work"},"Profile 2":{"name":"  "}}}}"#.utf8)
let profileNames = ChromeProfiles.names(from: profileJSON)
expect(profileNames["Default"] == "Personal", "Chrome profile display name decoded")
expect(profileNames["Profile 1"] == "Work", "secondary Chrome profile display name decoded")
expect(profileNames["Profile 2"] == nil, "blank name falls back to folder identifier")
expect(ChromeProfiles.names(from: Data("invalid".utf8)).isEmpty, "malformed profile metadata fails gracefully")
expect(ChromeProfiles.identifier(for: chromeCache + "/Cache_Data", home: testRoot) == "Default", "cache descendants retain profile identity")
expect(ChromeProfiles.identifier(for: testRoot + "/Library/Caches/Google/ChromeOther/Default/Cache", home: testRoot) == nil, "similar unrelated directory is not a Chrome profile")
let profileModel = StorageModel(safety: safety); profileModel.chromeProfileNames = profileNames
expect(profileModel.itemTitle(item(chromeCache)).contains("Personal · Default"), "cache title includes friendly name and stable profile identifier")
expect(!safety.eligible(item(chromeProfile + "/Cookies")), "cookie file excluded from cache cleanup")
let accountJSON = Data(#"{"profile":{"info_cache":{"Profile 1":{"name":"Work","gaia_name":"Example Person","user_name":"person@example.test"},"Default":{"name":"Local only"},"Profile 2":{"user_name":"second@example.test"}}}}"#.utf8)
let accounts = ChromeProfiles.names(from: accountJSON)
expect(accounts["Profile 1"] == "Work — Example Person (person@example.test)", "profile label shows account name and email")
expect(accounts["Default"] == "Local only", "unsigned local profile does not invent an account")
expect(accounts["Profile 2"] == "second@example.test", "email-only metadata remains identifiable")
print("PASS: \(checks) safety, scan, cancellation and reversible Trash assertions")
