import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var model = SocksAppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NavigationTitleAppearance.install()
    }

    var body: some View {
        TabView {
            HomeTab(model: model)
                .tabItem {
                    Label(L10n.string("tab.home"), systemImage: "house.fill")
                }

            LogTab(model: model)
                .tabItem {
                    Label(L10n.string("tab.logs"), systemImage: "chart.bar.fill")
                }

            AboutTab(model: model)
                .tabItem {
                    Label(L10n.string("tab.about"), systemImage: "info.circle.fill")
                }
        }
        .tint(.blue)
        .onAppear {
            model.startIfNeeded()
        }
        .onChange(of: scenePhase) { phase in
            model.handleScenePhase(phase)
        }
        .alert(L10n.string("alert.no_network.title"), isPresented: $model.showsNoNetworkAlert) {
            Button(L10n.string("common.ok")) {
                model.acknowledgeNoNetworkAlert()
            }
        } message: {
            Text(L10n.string("alert.no_network.message"))
        }
    }
}

private struct HomeTab: View {
    @ObservedObject var model: SocksAppModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    StatusCard(model: model)
                    UsageCard(model: model)
                    LocalNetworkPrivacyCard()
                    ProxyInfoCard(model: model)
                    FooterStatusCard(model: model)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle(L10n.string("tab.home"))
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }
}

private struct StatusCard: View {
    @ObservedObject var model: SocksAppModel

    private var isRunning: Bool {
        model.isRunning
    }

    var body: some View {
        CardContainer {
            VStack(spacing: 0) {
                StatusHeroLayout {
                    HStack(alignment: .center, spacing: 18) {
                        powerButton(diameter: 124)
                        statusDetails
                            .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
                    }
                } compact: {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 16) {
                            powerButton(diameter: 96)
                            statusHeader
                            Spacer(minLength: 0)
                        }
                        metricStack
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 22)

                Divider()

                HStack(spacing: 0) {
                    HeroValue(title: L10n.string("hero.local_ip"), value: model.host)
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1, height: 42)
                    HeroValue(title: L10n.string("hero.listen_port"), value: String(model.port)) {
                        copy(String(model.port))
                    }
                }
                .padding(.vertical, 18)
                .background(Color(.secondarySystemBackground).opacity(0.42))
            }
        }
    }

    private var statusSubtitle: String {
        if isRunning {
            return L10n.string("status.subtitle.running")
        }
        if model.statusText.contains("No Network") {
            return L10n.string("status.subtitle.waiting_network")
        }
        return model.statusText
    }

    private var powerColor: Color {
        isRunning ? .green : .blue
    }

    private var statusDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusHeader
            metricStack
        }
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isRunning ? L10n.string("status.title.running") : L10n.string("status.title.stopped"))
                .font(.title3.weight(.bold))
                .foregroundStyle(isRunning ? Color.green : Color.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(statusSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    private var metricStack: some View {
        VStack(spacing: 10) {
            MetricPill(icon: "link", title: L10n.string("metric.uptime"), value: model.uptimeText)
            MetricPill(icon: "waveform.path.ecg", title: L10n.string("metric.connections"), value: "\(model.activeConnections)")
        }
    }

    private func powerButton(diameter: CGFloat) -> some View {
        Button {
            model.toggleServer()
        } label: {
            ZStack {
                Circle()
                    .fill(powerColor.opacity(0.08))
                    .frame(width: diameter, height: diameter)
                Circle()
                    .fill(powerColor.opacity(0.10))
                    .frame(width: diameter * 0.75, height: diameter * 0.75)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [powerColor.opacity(0.92), powerColor.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: diameter * 0.58, height: diameter * 0.58)
                    .shadow(color: powerColor.opacity(0.25), radius: 16, x: 0, y: 8)
                Image(systemName: "power")
                    .font(.system(size: diameter * 0.28, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRunning ? L10n.string("accessibility.stop_proxy") : L10n.string("accessibility.start_proxy"))
    }
}

private struct StatusHeroLayout<Regular: View, Compact: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let regular: () -> Regular
    let compact: () -> Compact

    init(
        @ViewBuilder regular: @escaping () -> Regular,
        @ViewBuilder compact: @escaping () -> Compact
    ) {
        self.regular = regular
        self.compact = compact
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regular()
            } else {
                compact()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(Color.blue.opacity(0.07), in: Circle())

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .layoutPriority(1)

            Spacer(minLength: 10)

            Text(value)
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(.blue)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.systemBackground).opacity(0.86), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(0.55), lineWidth: 1)
        }
    }
}

private struct HeroValue: View {
    let title: String
    let value: String
    var copyAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 7) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(value)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let copyAction {
                    Button(action: copyAction) {
                        Image(systemName: "doc.on.doc")
                            .font(.body.weight(.medium))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(L10n.format("accessibility.copy_value", title))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct UsageCard: View {
    @ObservedObject var model: SocksAppModel

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.string("usage.title"))
                    .font(.headline.weight(.bold))

                VStack(spacing: 10) {
                    HelpRow(
                        icon: "laptopcomputer",
                        title: L10n.string("usage.computer.title"),
                        subtitle: L10n.format("usage.computer.subtitle", model.host, String(model.port))
                    )
                    HelpRow(
                        icon: "wifi",
                        title: L10n.string("usage.hotspot.title"),
                        subtitle: L10n.string("usage.hotspot.subtitle")
                    )
                }
            }
            .padding(18)
        }
    }
}

private struct HelpRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 52, height: 52)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(14)
        .background(Color(.secondarySystemBackground).opacity(0.54), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProxyInfoCard: View {
    @ObservedObject var model: SocksAppModel

    private var proxyText: String {
        model.proxyURLString
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(L10n.string("proxy.info.title"))
                        .font(.headline.weight(.bold))
                    Spacer()
                    ShareSheetButton(item: proxyText)

                    Button {
                        copy(proxyText)
                    } label: {
                        Label(L10n.string("common.copy_all"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                VStack(spacing: 0) {
                    InfoRow(title: L10n.string("proxy.type"), value: "SOCKS5", canCopy: true)
                    Divider()
                    InfoRow(title: L10n.string("proxy.server"), value: model.host, canCopy: true)
                    Divider()
                    PortEditRow(model: model)
                    Divider()
                    InfoRow(title: L10n.string("proxy.access_mode"), value: model.accessModeText, canCopy: false)
                    Divider()
                    if !model.isOpenAccessEnabled {
                        InfoRow(title: L10n.string("proxy.username"), value: model.proxyUsername, canCopy: true)
                        Divider()
                        InfoRow(title: L10n.string("proxy.temporary_token"), value: model.proxyToken, canCopy: true)
                        Divider()
                    }
                    InfoRow(title: L10n.string("proxy.udp"), value: L10n.string("common.yes"), canCopy: false)
                }
                .background(Color(.systemBackground).opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.string("auth.open_mode"), isOn: Binding(
                        get: { model.isOpenAccessEnabled },
                        set: { model.setOpenAccess($0) }
                    ))
                    .font(.subheadline.weight(.semibold))

                    Text(L10n.string("auth.open_mode.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        model.regenerateProxyToken()
                    } label: {
                        Label(L10n.string("auth.generate_token"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground).opacity(0.54), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(spacing: 14) {
                    QRCodeView(value: model.proxyURLString)
                        .frame(width: 108, height: 108)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("QR Code")
                            .font(.subheadline.weight(.bold))
                        Text(model.proxyURLString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground).opacity(0.54), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(18)
        }
    }
}

private struct ShareSheetButton: View {
    let item: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label(L10n.string("common.share"), systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .sheet(isPresented: $isPresented) {
            ActivityView(activityItems: [item])
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct LocalNetworkPrivacyCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.string("privacy.local_only.title"), systemImage: "checkmark.shield.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.green)
                Text(L10n.string("privacy.local_only.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.string("privacy.local_only.body"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String
    let canCopy: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if canCopy {
                Button {
                    copy(value)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L10n.format("accessibility.copy_value", title))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
    }
}

private struct PortEditRow: View {
    @ObservedObject var model: SocksAppModel
    @FocusState private var isPortFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(L10n.string("proxy.port"))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                TextField(L10n.string("proxy.port"), text: $model.portDraft)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.subheadline.monospacedDigit())
                    .frame(maxWidth: 92)
                    .textFieldStyle(.plain)
                    .focused($isPortFocused)
                    .onSubmit {
                        commitPortChange()
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(L10n.string("common.done")) {
                                commitPortChange()
                            }
                        }
                    }

                Button {
                    commitPortChange()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L10n.string("accessibility.save_port"))
            }

            if let message = model.portErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text(model.portStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 54)
    }

    private func commitPortChange() {
        if model.applyPortChange() {
            isPortFocused = false
        }
    }
}

private struct FooterStatusCard: View {
    @ObservedObject var model: SocksAppModel

    private var isRunning: Bool {
        model.statusText.hasPrefix("Running")
    }

    var body: some View {
        CardContainer {
            HStack {
                Image(systemName: isRunning ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(isRunning ? .green : .orange)
                Text(isRunning ? L10n.string("footer.running") : L10n.string("footer.stopped"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isRunning ? .green : .orange)
                Spacer()
                Text(L10n.format("footer.version", "1.0.0"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
    }
}

private struct LogTab: View {
    @ObservedObject var model: SocksAppModel

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                StatusStrip(model: model)
                logPanel
                    .frame(maxHeight: .infinity)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .navigationTitle(L10n.string("tab.logs"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private var logPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(model.logEntries) { entry in
                        Text(logLine(entry))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(color(for: entry.level))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id(entry.id)
                    }
                }
                .padding(10)
            }
            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .onChange(of: model.logEntries) { entries in
                guard let last = entries.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func logLine(_ entry: LogEntry) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return "[\(formatter.string(from: entry.date))]\(entry.message)"
    }

    private func color(for level: LogEntry.Level) -> Color {
        switch level {
        case .info:
            return .white
        case .success:
            return .green
        case .error:
            return .red
        case .disconnect:
            return .orange
        }
    }
}

private struct StatusStrip: View {
    @ObservedObject var model: SocksAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.statusText)
                .font(.headline)
                .foregroundStyle(statusColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(model.statsText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var statusColor: Color {
        if model.statusText.hasPrefix("Running") {
            return .green
        }
        if model.statusText.hasPrefix("Failed") || model.statusText.contains("No Network") {
            return .red
        }
        return .primary
    }
}

private struct AboutTab: View {
    @ObservedObject var model: SocksAppModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("SocksAPP", systemImage: "network")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(L10n.string("app.positioning"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(L10n.string("about.description"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                    }

                    CardContainer {
                        VStack(spacing: 0) {
                            AboutRow(icon: "antenna.radiowaves.left.and.right", title: L10n.string("about.listen_address"), value: "\(model.host):\(model.port)")
                            Divider()
                            AboutRow(icon: "lock.shield.fill", title: L10n.string("proxy.access_mode"), value: model.accessModeText)
                            Divider()
                            AboutRow(icon: "waveform.path.ecg", title: L10n.string("about.current_connections"), value: "\(model.activeConnections)")
                            Divider()
                            AboutRow(icon: "arrow.up.arrow.down", title: L10n.string("about.traffic"), value: "↑ \(model.uploadText)  ↓ \(model.downloadText)")
                        }
                        .padding(.vertical, 4)
                    }

                    CardContainer {
                        VStack(spacing: 0) {
                            AboutRow(icon: "checkmark.seal.fill", title: L10n.string("about.version"), value: "1.0.0")
                        }
                        .padding(.vertical, 4)
                    }

                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(L10n.string("privacy.title"), systemImage: "hand.raised.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(L10n.string("privacy.summary"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(L10n.string("privacy.auth_hint"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle(L10n.string("tab.about"))
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }
}

private struct AboutRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
    }
}

private struct CardContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Color(.systemBackground).opacity(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
            }
            .shadow(color: Color.blue.opacity(0.07), radius: 18, x: 0, y: 8)
    }
}

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.blue.opacity(0.045),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct QRCodeView: View {
    let value: String

    private static let context = CIContext()

    var body: some View {
        if let image = makeImage() {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .padding(8)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: "qrcode")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }
    }

    private func makeImage() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = Self.context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private func copy(_ value: String) {
    UIPasteboard.general.string = value
}

private enum NavigationTitleAppearance {
    static func install() {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label
        ]
        UINavigationBar.appearance().titleTextAttributes = titleAttributes
        UINavigationBar.appearance().largeTitleTextAttributes = titleAttributes
    }
}
