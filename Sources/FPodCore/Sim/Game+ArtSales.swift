import Foundation

// MARK: - Art sales: a drawing's price follows the art-therapy score

extension Game {
    /// Keeps one value per held drawing at most; drawings given away drop the lowest values.
    func reconcileArtValues() {
        var vals = (s.artValues ?? []).sorted(by: >)
        let held = s.inventory.count(.drawing)
        if vals.count > held { vals.removeLast(vals.count - held) }
        s.artValues = vals.isEmpty ? nil : vals
    }

    func recordArtPiece(_ value: Int) {
        reconcileArtValues()
        var vals = s.artValues ?? []
        vals.append(value)
        s.artValues = vals
        reconcileArtValues()
    }

    func sellDrawing(fallback: Int, reason: String) {
        guard s.inventory.count(.drawing) > 0 else { return }
        reconcileArtValues()
        var vals = (s.artValues ?? []).sorted(by: >)
        let price = vals.isEmpty ? fallback : vals.removeFirst()
        s.artValues = vals.isEmpty ? nil : vals
        apply([.take(.drawing, 1), .credits(price, reason)])
        reconcileArtValues()
    }
}
