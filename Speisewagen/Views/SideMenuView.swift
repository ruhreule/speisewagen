import SwiftUI

struct SideMenuView: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Menü")
                        .font(.custom("Georgia", size: 20))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.swText)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.swMuted)
                            .frame(width: 30, height: 30)
                            .background(Color.swBg)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Rectangle()
                    .fill(Color.swBorder)
                    .frame(height: 0.5)

                Button(action: onClose) {
                    menuRow(icon: "calendar", title: "Wochenübersicht")
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.swBorder)
                    .frame(height: 0.5)
                    .padding(.leading, 56)

                NavigationLink {
                    ImpressumView()
                } label: {
                    menuRow(icon: "info.circle", title: "Impressum")
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.swBorder)
                    .frame(height: 0.5)

                Spacer()
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .shadow(color: .black.opacity(0.12), radius: 24, x: -6, y: 0)
    }

    private func menuRow(icon: String, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.swAccent)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color.swText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.swMuted.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
