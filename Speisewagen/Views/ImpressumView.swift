import SwiftUI

struct ImpressumView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Speisewagen")
                        .font(.custom("Georgia", size: 22))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.swText)
                    Text("Wochenmenü-App für iOS")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.swMuted)
                }

                Rectangle()
                    .fill(Color.swBorder)
                    .frame(height: 0.5)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Entwickler")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.swMuted)
                    Text("Matthias Barann")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.swText)
                    Link("matthias.mk@mac.com",
                         destination: URL(string: "mailto:matthias.mk@mac.com")!)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.swAccent)
                }

                Rectangle()
                    .fill(Color.swBorder)
                    .frame(height: 0.5)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Version")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.swMuted)
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.swText)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.swBg)
        .navigationTitle("Impressum")
        .navigationBarTitleDisplayMode(.inline)
    }
}
