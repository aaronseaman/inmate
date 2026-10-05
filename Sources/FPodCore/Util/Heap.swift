/// Minimal binary min-heap keyed by Double priority.
public struct MinHeap<T> {
    private var items: [(Double, T)] = []
    public init() {}
    public var isEmpty: Bool { items.isEmpty }
    public var count: Int { items.count }

    public mutating func push(_ v: T, _ priority: Double) {
        items.append((priority, v))
        var i = items.count - 1
        while i > 0 {
            let p = (i - 1) / 2
            if items[p].0 <= items[i].0 { break }
            items.swapAt(p, i)
            i = p
        }
    }

    public mutating func pop() -> (T, Double)? {
        guard !items.isEmpty else { return nil }
        let top = items[0]
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var i = 0
            let n = items.count
            while true {
                let l = 2 * i + 1, r = l + 1
                var m = i
                if l < n && items[l].0 < items[m].0 { m = l }
                if r < n && items[r].0 < items[m].0 { m = r }
                if m == i { break }
                items.swapAt(m, i)
                i = m
            }
        }
        return (top.1, top.0)
    }
}
