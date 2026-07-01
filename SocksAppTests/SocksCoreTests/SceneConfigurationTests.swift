import XCTest

final class SceneConfigurationTests: XCTestCase {
    func testInfoPlistDeclaresApplicationSceneConfiguration() throws {
        let plistURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let plist = try XCTUnwrap(object as? [String: Any])
        let manifest = try XCTUnwrap(plist["UIApplicationSceneManifest"] as? [String: Any])
        let configurations = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
        let applicationRole = try XCTUnwrap(configurations["UIWindowSceneSessionRoleApplication"] as? [[String: Any]])
        let firstConfiguration = try XCTUnwrap(applicationRole.first)

        XCTAssertEqual(firstConfiguration["UISceneConfigurationName"] as? String, "Default Configuration")
    }

    func testSwiftUIContentViewObservesScenePhase() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/ContentView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("@Environment(\\.scenePhase)"))
        XCTAssertTrue(source.contains("handleScenePhase"))
    }

    func testContentViewUsesLargeVisibleNavigationTitles() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/ContentView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertEqual(source.components(separatedBy: ".navigationBarTitleDisplayMode(.large)").count - 1, 2)
        XCTAssertTrue(source.contains(".navigationTitle(L10n.string(\"tab.home\"))"))
        XCTAssertTrue(source.contains(".navigationTitle(L10n.string(\"tab.logs\"))"))
        XCTAssertTrue(source.contains(".navigationBarTitleDisplayMode(.inline)"))
        XCTAssertTrue(source.contains("largeTitleTextAttributes"))
        XCTAssertTrue(source.contains("UINavigationBar.appearance().largeTitleTextAttributes"))
        XCTAssertTrue(source.contains("UIColor.label"))
        XCTAssertFalse(source.contains("toolbarBackground"))
        XCTAssertFalse(source.contains("backgroundColor = UIColor.systemBackground"))
        XCTAssertFalse(source.contains("gearshape"))
    }

    func testHeroPowerButtonTogglesServer() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/ContentView.swift")
        let source = try String(contentsOf: sourceURL)
        let modelURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/SocksAppModel.swift")
        let modelSource = try String(contentsOf: modelURL)

        XCTAssertTrue(source.contains("model.toggleServer()"))
        XCTAssertTrue(source.contains("L10n.string(\"accessibility.stop_proxy\")"))
        XCTAssertTrue(modelSource.contains("func toggleServer()"))
        XCTAssertTrue(modelSource.contains("func stopServer()"))
    }

    func testHeroPowerButtonDoesNotSqueezeStatusText() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/ContentView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("StatusHeroLayout"))
        XCTAssertTrue(source.contains("@Environment(\\.horizontalSizeClass)"))
        XCTAssertTrue(source.contains("powerButton(diameter: 124)"))
        XCTAssertTrue(source.contains("frame(minWidth: 160"))
        XCTAssertTrue(source.contains("powerButton(diameter: 96)"))
        XCTAssertFalse(source.contains("GeometryReader { geometry in"))
        XCTAssertFalse(source.contains(".frame(minHeight: 154)"))
    }

    func testLogTabKeepsOnlyLogRegionScrollable() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/ContentView.swift")
        let source = try String(contentsOf: sourceURL)

        let logTabRange = try XCTUnwrap(source.range(of: "private struct LogTab"))
        let statusStripRange = try XCTUnwrap(source.range(of: "private struct StatusStrip"))
        let logTabSource = String(source[logTabRange.lowerBound..<statusStripRange.lowerBound])

        XCTAssertEqual(logTabSource.components(separatedBy: "ScrollView {").count - 1, 1)
        XCTAssertTrue(logTabSource.contains("StatusStrip(model: model)"))
        XCTAssertTrue(logTabSource.contains(".frame(maxHeight: .infinity)"))
        XCTAssertTrue(logTabSource.contains(".navigationBarTitleDisplayMode(.inline)"))
    }

    func testDefaultListenPortIs5151() throws {
        let modelURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/SocksAppModel.swift")
        let modelSource = try String(contentsOf: modelURL)
        let serverURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/Sources/SocksCore/SocksServer.swift")
        let serverSource = try String(contentsOf: serverURL)

        XCTAssertTrue(modelSource.contains("var port: UInt16 = 5_151"))
        XCTAssertTrue(modelSource.contains("var portDraft = \"5151\""))
        XCTAssertFalse(modelSource.contains("9_876"))
        XCTAssertFalse(modelSource.contains("\"9876\""))
        XCTAssertTrue(serverSource.contains("port: UInt16 = 5_151"))
    }

    func testProxyShareAndCopyUseSocks5URL() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/ContentView.swift")
        let source = try String(contentsOf: sourceURL)
        let modelURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/SocksAppModel.swift")
        let modelSource = try String(contentsOf: modelURL)

        XCTAssertTrue(modelSource.contains("\"socks5://\\(proxyUsername):\\(proxyToken)@\\(host):\\(port)\""))
        XCTAssertTrue(modelSource.contains("\"socks5://\\(host):\\(port)\""))
        XCTAssertTrue(source.contains("QRCodeView(value: model.proxyURLString)"))
        XCTAssertTrue(source.contains("ShareSheetButton(item: proxyText)"))
        XCTAssertTrue(source.contains("copy(proxyText)"))
        XCTAssertFalse(source.contains("\"SOCKS5 \\(model.host):\\(model.port)\""))
    }

    func testAuthenticationControlsAndComplianceCopyAreVisible() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/ContentView.swift")
        let source = try String(contentsOf: sourceURL)
        let modelURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/SocksAppModel.swift")
        let modelSource = try String(contentsOf: modelURL)
        let stringsURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/Resources/Localizable.xcstrings")
        let strings = try String(contentsOf: stringsURL)

        XCTAssertTrue(source.contains("L10n.string(\"auth.open_mode\")"))
        XCTAssertTrue(source.contains("L10n.string(\"auth.generate_token\")"))
        XCTAssertTrue(source.contains("L10n.string(\"privacy.local_only.title\")"))
        XCTAssertTrue(strings.contains("开放模式"))
        XCTAssertTrue(strings.contains("生成临时 token"))
        XCTAssertTrue(strings.contains("仅本地网络使用"))
        XCTAssertTrue(strings.contains("不上传流量、不出售数据，日志仅保存在本机"))
        XCTAssertTrue(strings.contains("Local SOCKS5 server for development and debugging"))
        XCTAssertTrue(modelSource.contains("func regenerateProxyToken()"))
        XCTAssertTrue(modelSource.contains("func setOpenAccess"))
        XCTAssertTrue(modelSource.contains("authenticationMode"))
    }

    func testOpenAccessModePersistsInUserDefaults() throws {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let modelSource = try String(contentsOf: rootURL.appendingPathComponent("SocksApp/App/SocksAppModel.swift"))

        XCTAssertTrue(modelSource.contains("UserDefaults.standard.bool(forKey: UserDefaultsKey.openAccessEnabled)"))
        XCTAssertTrue(modelSource.contains("UserDefaults.standard.set(isOpenAccessEnabled, forKey: UserDefaultsKey.openAccessEnabled)"))
        XCTAssertTrue(modelSource.contains("UserDefaults.standard.set(false, forKey: UserDefaultsKey.openAccessEnabled)"))
        XCTAssertTrue(modelSource.contains("private enum UserDefaultsKey"))
        XCTAssertTrue(modelSource.contains("openAccessEnabled"))
    }

    func testAppDeclaresChineseAndEnglishLocalizations() throws {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let stringsURL = rootURL.appendingPathComponent("SocksApp/Resources/Localizable.xcstrings")
        let projectURL = rootURL.appendingPathComponent("SocksApp.xcodeproj/project.pbxproj")
        let l10nURL = rootURL.appendingPathComponent("SocksApp/App/L10n.swift")

        XCTAssertTrue(FileManager.default.fileExists(atPath: stringsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: l10nURL.path))

        let project = try String(contentsOf: projectURL)
        XCTAssertTrue(project.contains("zh-Hans"))
        XCTAssertTrue(project.contains("Localizable.xcstrings in Resources"))
        XCTAssertTrue(project.contains("L10n.swift in Sources"))

        let strings = try String(contentsOf: stringsURL)
        let stringsData = try Data(contentsOf: stringsURL)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: stringsData))
        let stringsObject = try XCTUnwrap(JSONSerialization.jsonObject(with: stringsData) as? [String: Any])
        XCTAssertEqual(stringsObject["sourceLanguage"] as? String, "en")
        XCTAssertTrue(strings.contains("\"zh-Hans\""))
        XCTAssertTrue(strings.contains("\"tab.home\""))
        XCTAssertTrue(strings.contains("\"Home\""))
        XCTAssertTrue(strings.contains("\"首页\""))
        XCTAssertTrue(strings.contains("\"privacy.summary\""))
        XCTAssertTrue(strings.contains("不上传流量、不出售数据，日志仅保存在本机。"))
    }

    func testContentViewAndModelUseLocalizationHelper() throws {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(contentsOf: rootURL.appendingPathComponent("SocksApp/App/ContentView.swift"))
        let modelSource = try String(contentsOf: rootURL.appendingPathComponent("SocksApp/App/SocksAppModel.swift"))

        XCTAssertTrue(source.contains("L10n.string(\"tab.home\")"))
        XCTAssertTrue(source.contains("L10n.string(\"tab.logs\")"))
        XCTAssertTrue(source.contains("L10n.string(\"tab.about\")"))
        XCTAssertTrue(source.contains("L10n.format(\"usage.computer.subtitle\""))
        XCTAssertTrue(modelSource.contains("L10n.string(\"access.mode.open\")"))
        XCTAssertTrue(modelSource.contains("L10n.string(\"port.error.invalid\")"))
    }

    func testNoNetworkAlertAcknowledgementDoesNotTerminateTheApp() throws {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let modelSource = try String(contentsOf: rootURL.appendingPathComponent("SocksApp/App/SocksAppModel.swift"))

        XCTAssertTrue(modelSource.contains("func acknowledgeNoNetworkAlert()"))
        XCTAssertFalse(modelSource.contains("terminate:"))
        XCTAssertFalse(modelSource.contains("exit("))
        XCTAssertFalse(modelSource.contains("perform(selector"))
    }

    func testNetworkPathChangesTriggerProxyRestartWhenIPAddressChanges() throws {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let modelSource = try String(contentsOf: rootURL.appendingPathComponent("SocksApp/App/SocksAppModel.swift"))

        XCTAssertTrue(modelSource.contains("import Network"))
        XCTAssertTrue(modelSource.contains("NWPathMonitor()"))
        XCTAssertTrue(modelSource.contains("pathUpdateHandler"))
        XCTAssertTrue(modelSource.contains("scheduleNetworkPathRefresh()"))
        XCTAssertTrue(modelSource.contains("handleNetworkPathChange()"))
        XCTAssertTrue(modelSource.contains("restartServerForNetworkChange(advertisedHost:"))
        XCTAssertTrue(modelSource.contains("NetworkInterfaceProvider.deviceIPAddress"))
        XCTAssertTrue(modelSource.contains("newHost != host"))
        XCTAssertTrue(modelSource.contains("server = makeServer(port: port)"))
        XCTAssertTrue(modelSource.contains("try server?.start(advertisedHost: advertisedHost)"))
        XCTAssertTrue(modelSource.contains("L10n.string(\"network.status.restart\")"))
    }

    func testAboutPageDoesNotShowBackgroundKeepaliveOrIconFormatRows() throws {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(contentsOf: rootURL.appendingPathComponent("SocksApp/App/ContentView.swift"))

        XCTAssertFalse(source.contains("about.background_keepalive"))
        XCTAssertFalse(source.contains("about.audio_mode"))
        XCTAssertFalse(source.contains("about.icon_format"))
        XCTAssertFalse(source.contains("AppIcon.icon\")"))
    }

    func testContentViewUsesThreeTabsAndRemovesVPNInstruction() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/ContentView.swift")
        let source = try String(contentsOf: sourceURL)
        let modelURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SocksApp/App/SocksAppModel.swift")
        let modelSource = try String(contentsOf: modelURL)

        XCTAssertTrue(source.contains("TabView"))
        XCTAssertTrue(source.contains("L10n.string(\"tab.home\")"))
        XCTAssertTrue(source.contains("L10n.string(\"tab.logs\")"))
        XCTAssertTrue(source.contains("L10n.string(\"tab.about\")"))
        XCTAssertTrue(source.contains("portDraft"))
        XCTAssertTrue(source.contains("FocusState"))
        XCTAssertTrue(source.contains("portStatusMessage"))
        XCTAssertTrue(modelSource.contains("L10n.string(\"port.status.restart_after_save\")"))
        XCTAssertFalse(source.contains("开启 VPN"))
    }

    func testProjectBuildSettingsAndSwiftUIUseIOS15CompatibleAPIs() throws {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let package = try String(contentsOf: rootURL.appendingPathComponent("Package.swift"))
        let project = try String(contentsOf: rootURL.appendingPathComponent("SocksApp.xcodeproj/project.pbxproj"))
        let contentView = try String(contentsOf: rootURL.appendingPathComponent("SocksApp/App/ContentView.swift"))

        XCTAssertTrue(package.contains(".iOS(.v15)"))
        XCTAssertTrue(project.contains("IPHONEOS_DEPLOYMENT_TARGET = 15.0;"))
        XCTAssertFalse(contentView.contains("NavigationStack"))
        XCTAssertFalse(contentView.contains("ViewThatFits"))
        XCTAssertFalse(contentView.contains("ShareLink"))
        XCTAssertFalse(contentView.contains(".onChange(of: scenePhase) { _, phase in"))
        XCTAssertFalse(contentView.contains(".onChange(of: model.logEntries) { _, entries in"))
    }

    func testProjectUsesIconComposerAppIcon() throws {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let iconURL = rootURL.appendingPathComponent("SocksApp/AppIcon.icon")
        let projectURL = rootURL.appendingPathComponent("SocksApp.xcodeproj/project.pbxproj")
        let project = try String(contentsOf: projectURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("SocksApp/Assets.xcassets").path))
        XCTAssertTrue(project.contains("folder.iconcomposer.icon"))
        XCTAssertTrue(project.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"))
    }
}
