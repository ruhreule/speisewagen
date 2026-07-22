import SwiftUI

extension Color {
    // Ziegel-Rot – in Dark Mode leicht aufgehellt für ausreichenden Kontrast
    // Light: #B5341A   Dark: #D7503A
    static let swAccent: Color = {
        let ui = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 215/255, green: 80/255,  blue: 58/255,  alpha: 1)
                : UIColor(red: 181/255, green: 52/255,  blue: 26/255,  alpha: 1)
        }
        return Color(uiColor: ui)
    }()

    // Seitenhintergrund
    // Light: #FAF8F5 (Creme)   Dark: #12100E (warmes Tiefschwarz)
    static let swBg: Color = {
        let ui = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 18/255,  green: 16/255,  blue: 14/255,  alpha: 1)
                : UIColor(red: 250/255, green: 248/255, blue: 245/255, alpha: 1)
        }
        return Color(uiColor: ui)
    }()

    // Kartenoberflächen (ersetzt Color.white in Hintergründen)
    // Light: #FFFFFF   Dark: leicht erhöhte Ebene über swBg
    static let swSurface: Color = {
        let ui = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 30/255,  green: 26/255,  blue: 22/255,  alpha: 1)
                : .white
        }
        return Color(uiColor: ui)
    }()

    // Haupttext
    // Light: #1C1410 (fast schwarz)   Dark: #F5F0E8 (warm-weiß)
    static let swText: Color = {
        let ui = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 245/255, green: 240/255, blue: 232/255, alpha: 1)
                : UIColor(red: 28/255,  green: 20/255,  blue: 16/255,  alpha: 1)
        }
        return Color(uiColor: ui)
    }()

    // Gedämpfter Text / Platzhalter
    // Light: warmes Braun 40%   Dark: mittleres Warmgrau
    static let swMuted: Color = {
        let ui = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 155/255, green: 138/255, blue: 120/255, alpha: 1)
                : UIColor(red: 60/255,  green: 45/255,  blue: 30/255,  alpha: 0.4)
        }
        return Color(uiColor: ui)
    }()

    // Trennlinien und Rahmen
    // Light: warmes Braun 8%   Dark: subtile helle Linie
    static let swBorder: Color = {
        let ui = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 60/255,  green: 50/255,  blue: 40/255,  alpha: 1)
                : UIColor(red: 60/255,  green: 45/255,  blue: 30/255,  alpha: 0.08)
        }
        return Color(uiColor: ui)
    }()
}
