import UIKit
import CoreImage

/// Generiert ein PDF mit 5 × 5 cm Rezeptkarten und startet den System-Druckdialog.
///
/// **Layout**: 3 Spalten × 5 Zeilen = 15 Karten pro DIN-A4-Seite (595,28 × 841,89 pt bei 72 dpi).
/// Die Abstände zwischen den Karten werden gleichmäßig verteilt – (cols+1) horizontale
/// und (rows+1) vertikale Lücken –, damit die Karten optisch zentriert wirken und ein
/// Schneidewerkzeug sauber angesetzt werden kann.
///
/// **QR-Code-Format**: `speisewagen://recipe/{UUID}` – dasselbe Schema, das
/// `RecipeScannerView` beim Scannen erwartet. Fehlerkorrekturlevel „M" (15 %)
/// bietet einen guten Kompromiss zwischen Codegröße und Scan-Zuverlässigkeit für
/// kleine Druckflächen.
enum RecipeCardPrinter {

    /// 5 cm in Punkt bei 72 dpi: 5 / 2,54 × 72 ≈ 141,73 pt
    private static let cardPts: CGFloat = 5.0 / 2.54 * 72

    static func print(recipes: [Recipe]) {
        guard !recipes.isEmpty else { return }
        let data = buildPDF(recipes: recipes)

        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .photo
        info.jobName = "Speisewagen – Rezeptkarten"
        controller.printInfo = info
        controller.printingItem = data

        guard
            let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow })
        else { return }
        controller.present(from: window.frame, in: window, animated: true)
    }

    // MARK: – PDF

    private static func buildPDF(recipes: [Recipe]) -> Data {
        let pageW: CGFloat = 595.28   // DIN A4 bei 72 dpi
        let pageH: CGFloat = 841.89
        let card = cardPts
        let cols = 3, rows = 5, perPage = cols * rows

        // Gleichmäßige Abstände: (cols+1) horizontale und (rows+1) vertikale Lücken,
        // sodass erste/letzte Karte denselben Rand hat wie die Abstände dazwischen.
        let hGap = (pageW - CGFloat(cols) * card) / CGFloat(cols + 1)
        let vGap = (pageH - CGFloat(rows) * card) / CGFloat(rows + 1)

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        return renderer.pdfData { ctx in
            var idx = 0
            while idx < recipes.count {
                ctx.beginPage()
                for slot in 0..<perPage where idx < recipes.count {
                    let col = slot % cols, row = slot / cols
                    let x = hGap + CGFloat(col) * (card + hGap)
                    let y = vGap + CGFloat(row) * (card + vGap)
                    drawCard(recipe: recipes[idx],
                             in: CGRect(x: x, y: y, width: card, height: card),
                             cgCtx: ctx.cgContext)
                    idx += 1
                }
            }
        }
    }

    // MARK: – Karte zeichnen

    private static func drawCard(recipe: Recipe, in rect: CGRect, cgCtx c: CGContext) {
        // Weißer Hintergrund + dünner Rahmen als Schneidehilfe
        c.setFillColor(UIColor.white.cgColor)
        c.fill(rect)
        c.setStrokeColor(UIColor.systemGray4.cgColor)
        c.setLineWidth(0.4)
        c.stroke(rect)

        // Obere 58 % der Karte: Foto; untere 42 %: Titel + QR-Code
        let imgH   = rect.height * 0.58
        let botH   = rect.height - imgH
        let imgRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: imgH)
        let botY    = rect.minY + imgH

        // Foto mit Aspect-Fill in den Bildbereich einpassen
        c.saveGState()
        c.clip(to: imgRect)
        if let data = recipe.imageData, let img = UIImage(data: data) {
            // Skalierungsfaktor so wählen, dass Bild den Rahmen vollständig füllt
            let s = max(imgRect.width / img.size.width, imgRect.height / img.size.height)
            img.draw(in: CGRect(x: imgRect.midX - img.size.width  * s / 2,
                                y: imgRect.midY - img.size.height * s / 2,
                                width:  img.size.width  * s,
                                height: img.size.height * s))
        } else {
            c.setFillColor(UIColor.systemGray5.cgColor)
            c.fill(imgRect)
        }
        c.restoreGState()

        // Trennlinie zwischen Foto und Textbereich
        c.setStrokeColor(UIColor.systemGray5.cgColor)
        c.setLineWidth(0.4)
        c.move(to: CGPoint(x: rect.minX, y: botY))
        c.addLine(to: CGPoint(x: rect.maxX, y: botY))
        c.strokePath()

        // QR-Code – quadratisch, rechtsbündig im unteren Bereich
        let qrPad: CGFloat = 4
        let qrSize = botH - qrPad * 2
        if let qr = makeQR(for: recipe, size: qrSize) {
            qr.draw(in: CGRect(x: rect.maxX - qrSize - qrPad,
                               y: botY + qrPad,
                               width: qrSize, height: qrSize))
        }

        // Rezepttitel links neben dem QR-Code
        let titleX = rect.minX + 6
        let titleW = rect.width - qrSize - qrPad * 2 - 10
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byWordWrapping
        // Textfarbe entspricht swText (#1C1410); UIColor, weil wir im CGContext zeichnen
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5, weight: .semibold),
            .foregroundColor: UIColor(red: 28/255, green: 20/255, blue: 16/255, alpha: 1),
            .paragraphStyle: para
        ]
        (recipe.title ?? "Rezept").draw(
            in: CGRect(x: titleX, y: botY + 6, width: titleW, height: botH - 12),
            withAttributes: attrs)
    }

    // MARK: – QR-Code-Bild

    private static func makeQR(for recipe: Recipe, size: CGFloat) -> UIImage? {
        guard let id = recipe.id else { return nil }
        // URL-Schema muss mit RecipeScannerView.Coordinator übereinstimmen
        let payload = "speisewagen://recipe/\(id.uuidString)"
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        // Fehlerkorrekturlevel M (15 %): robust genug für gedruckte Karten, aber kompakter als H
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let out = filter.outputImage else { return nil }
        let scale = size / out.extent.size.width
        let scaled = out.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
