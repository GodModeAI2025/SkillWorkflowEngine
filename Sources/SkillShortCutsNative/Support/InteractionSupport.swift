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
        .foregroundStyle(Color.enbwTextSecondary)
        .help(title)
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.enbwHeadline)
                    .foregroundStyle(Color.enbwTextPrimary)
                Text(message)
                    .font(.enbwBody)
                    .foregroundStyle(Color.enbwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 280, alignment: .leading)
            .background(Color.enbwBackgroundPrimary)
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
        HStack(alignment: .center, spacing: 8) {
            content
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)

            InfoButton(title: title, message: message)
        }
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
                        .foregroundStyle(Color.enbwTextPrimary)

                    Spacer()
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.enbwBackgroundSecondary, in: RoundedRectangle(cornerRadius: EnBWTheme.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: EnBWTheme.smallRadius)
                    .stroke(Color.enbwBorder)
            )

            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
