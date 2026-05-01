import SwiftUI

struct InfoButton: View {
    let title: String
    let message: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.nwebTextSecondary)
        .help(title)
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.nwebHeadline)
                    .foregroundStyle(Color.nwebTextPrimary)
                Text(message)
                    .font(.nwebBody)
                    .foregroundStyle(Color.nwebTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 280, alignment: .leading)
            .background(Color.nwebBackgroundPrimary)
        }
    }
}

struct InfoControlRow<Content: View>: View {
    let title: String
    let message: String
    @ViewBuilder let content: Content

    init(_ title: String, message: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.message = message
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            content
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)

            InfoButton(title: title, message: message)
        }
    }
}

private struct PipeControlSurfaceModifier: ViewModifier {
    @Environment(\.isEnabled) private var environmentEnabled
    let isEnabled: Bool

    private var effectiveIsEnabled: Bool {
        environmentEnabled && isEnabled
    }

    func body(content: Content) -> some View {
        content
            .font(.nwebBody)
            .foregroundStyle(effectiveIsEnabled ? Color.nwebTextPrimary : PipesStyle.controlTextDisabled)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .background(
                effectiveIsEnabled ? PipesStyle.controlFill : PipesStyle.controlFillDisabled,
                in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
                    .stroke(effectiveIsEnabled ? Color.nwebBorder : Color.nwebBorder.opacity(0.8))
            )
    }
}

struct PipeSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nwebBody.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.nwebAccent : PipesStyle.controlTextDisabled)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(
                isEnabled ? Color.nwebAccent.opacity(0.14) : PipesStyle.controlFillDisabled,
                in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
                    .stroke(isEnabled ? Color.nwebAccent.opacity(0.18) : Color.nwebBorder.opacity(0.8))
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

extension View {
    func pipeControlSurface(isEnabled: Bool = true) -> some View {
        modifier(PipeControlSurfaceModifier(isEnabled: isEnabled))
    }
}

struct LargeDisclosureGroup<Content: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder let content: Content
    @State private var isExpanded = false

    init(_ title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .frame(width: 14)

                    if let systemImage {
                        Image(systemName: systemImage)
                            .frame(width: 16)
                    }

                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.nwebTextPrimary)

                    Spacer()
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.nwebBackgroundSecondary, in: RoundedRectangle(cornerRadius: NWEBTheme.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: NWEBTheme.smallRadius)
                    .stroke(Color.nwebBorder)
            )

            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
