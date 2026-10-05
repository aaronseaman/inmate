import Foundation

/// The fictional campus. Coordinates are tiles (x right, y down).
/// Invented geometry only — not modeled on any real facility.
public enum Campus {
    public static let width = 200
    public static let height = 140

    // Door rule shorthands.
    static let movement: [Activity] = [.breakfast, .work, .therapy, .chow, .afternoon, .rec, .dinner, .freeTime, .brunch, .visiting, .chapel, .review]
    static let meals: [Activity] = [.breakfast, .chow, .dinner, .brunch]
    static let cellsOpen: [Activity] = [.wakeCount, .medPass, .breakfast, .work, .therapy, .chow, .afternoon, .rec, .dinner, .freeTime, .eveningCount, .settle, .brunch, .visiting, .chapel, .review]

    /// Cells in F-Pod: number -> interior rect.
    public static let cellRects: [Int: TileRect] = {
        var d: [Int: TileRect] = [:]
        let topX = [28, 33, 38, 43]
        for (k, x) in topX.enumerated() { d[k + 1] = TileRect(x, 46, 4, 5) }
        let botX = [12, 17, 22, 27, 32, 37]
        for (k, x) in botX.enumerated() { d[k + 5] = TileRect(x, 70, 4, 5) }
        return d
    }()

    public static func build() -> WorldMap {
        let b = MapBuilder(width: width, height: height)
        buildPerimeter(b)
        buildYard(b)
        buildVocRehab(b)
        buildKitchen(b)
        buildCorridors(b)
        buildFPod(b)
        buildControl(b)
        buildSupport(b)
        buildAdmin(b)
        buildObservation(b)
        buildTunnels(b)
        return b.finalize()
    }

    // MARK: Perimeter & grounds

    static func buildPerimeter(_ b: MapBuilder) {
        // Woods everywhere in the campus half; buildings carve over it.
        b.zone("perimeter.woods", "Wooded buffer", TileRect(0, 0, 160, 140), .perimeter, .perimeter, ground: .woods, label: false)
        b.labels.append(("Wooded buffer", Vec2(80, 126), .perimeter))
        // Patrol road ring between fences.
        b.zone("perimeter.road", "Patrol road", TileRect(5, 5, 150, 107), .perimeter, .perimeter, ground: .road)
        // Grounds inside the inner fence.
        b.zone("grounds", "Grounds", TileRect(9, 9, 142, 99), .grounds, .perimeter, ground: .grass, label: false)
        // Fences.
        b.fenceLine(TileRect(4, 4, 152, 1)); b.fenceLine(TileRect(4, 112, 152, 1))
        b.fenceLine(TileRect(4, 4, 1, 109)); b.fenceLine(TileRect(155, 4, 1, 109))
        b.fenceLine(TileRect(8, 8, 144, 1)); b.fenceLine(TileRect(8, 108, 144, 1))
        b.fenceLine(TileRect(8, 8, 1, 101)); b.fenceLine(TileRect(151, 8, 1, 101))
        // Towers at the corners of the road ring and mid-south.
        b.obj(.tower, 5, 5, w: 2, h: 2, id: "tower.nw")
        b.obj(.tower, 153, 5, w: 2, h: 2, id: "tower.ne")
        b.obj(.tower, 5, 109, w: 2, h: 2, id: "tower.sw")
        b.obj(.tower, 153, 109, w: 2, h: 2, id: "tower.se")
        b.obj(.tower, 60, 109, w: 2, h: 2, id: "tower.s")
        b.obj(.kennel, 140, 109, w: 2, h: 2, id: "kennel")
        // Gates from grounds to the road (staff only).
        b.door("gate.inner.s", 120, 108, vertical: false, kind: .gate, rule: .staff, name: "Inner fence gate")
        // Fictional escape geometry: the culvert outlet sits in the south road ditch;
        // a loose outer-fence panel exists only once the story reveals it.
        b.obj(.culvert, 80, 110, id: "culvert.out")
        b.door("fence.gap", 86, 112, vertical: false, kind: .gate, rule: .all([.flag(.escapeStarted), .key(.fenceTool)]), name: "Loose fence panel")
        b.spot("escape.exit", 86.5, 134.5, .down)
        b.spot("k9.a", 20.5, 110.5, .right)
        b.spot("k9.b", 137.5, 110.5, .left)
        b.spot("k9.c", 154.0, 60.5, .up)
        b.spot("tower.s.look", 61.0, 111.0, .up)
        // Grounds lawn (grounds job).
        b.zone("grounds.lawn", "East lawn", TileRect(124, 86, 26, 20), .grounds, .work, ground: .grass)
        for (x, y) in [(127, 89), (133, 95), (143, 90), (139, 101), (128, 101)] { b.obj(.tree, x, y) }
        b.obj(.lawn, 126, 88, w: 22, h: 16, id: "lawn.patch")
        b.spot("grounds.shed", 146.5, 103.5, .left)
        b.obj(.crate, 147, 104, id: "grounds.toolbox")
        for x in stride(from: 12, through: 148, by: 9) { b.obj(.tree, x, 106) }
        b.obj(.van, 143, 99, w: 3, h: 2, id: "transport.van")
    }

    // MARK: Rec yard

    static func buildYard(_ b: MapBuilder) {
        b.zone("yard", "Rec yard", TileRect(12, 12, 47, 28), .yard, .yard, ground: .concrete)
        b.fenceLine(TileRect(11, 11, 49, 1)); b.fenceLine(TileRect(11, 11, 1, 29)); b.fenceLine(TileRect(59, 11, 1, 29))
        // Basketball half court.
        b.paint(TileRect(14, 14, 12, 10), .court)
        b.obj(.hoop, 19, 14, w: 2, h: 1, id: "yard.hoop")
        b.spot("yard.hoop.shoot", 20.0, 19.5, .up)
        // Weights.
        b.obj(.weights, 29, 15, w: 2, h: 1, id: "yard.weights1")
        b.obj(.weights, 33, 15, w: 2, h: 1, id: "yard.weights2")
        b.spot("yard.weights.a", 30.0, 16.8, .up)
        b.spot("yard.weights.b", 34.0, 16.8, .up)
        // Horseshoes.
        b.obj(.horseshoes, 41, 14, w: 1, h: 1, id: "yard.shoes1")
        b.obj(.horseshoes, 49, 14, w: 1, h: 1, id: "yard.shoes2")
        b.spot("yard.shoes.throw", 43.5, 14.5, .right)
        // Track ring.
        b.paint(TileRect(28, 22, 29, 2), .track); b.paint(TileRect(28, 36, 29, 2), .track)
        b.paint(TileRect(28, 22, 2, 16), .track); b.paint(TileRect(55, 22, 2, 16), .track)
        b.paint(TileRect(30, 24, 25, 12), .grass)
        // Garden beds (grounds job + side quest).
        b.paint(TileRect(13, 29, 13, 10), .grass)
        b.obj(.garden, 14, 31, w: 3, h: 2, id: "garden.1")
        b.obj(.garden, 18, 31, w: 3, h: 2, id: "garden.2")
        b.obj(.garden, 22, 31, w: 3, h: 2, id: "garden.3")
        b.obj(.garden, 14, 35, w: 3, h: 2, id: "garden.4")
        b.obj(.garden, 18, 35, w: 3, h: 2, id: "garden.5")
        b.obj(.garden, 22, 35, w: 3, h: 2, id: "garden.6")
        b.spot("garden.tend", 20.5, 34.0, .up)
        b.obj(.bleacher, 14, 25, w: 10, h: 2, id: "yard.bleacher")
        b.obj(.bench, 40, 20, w: 3, h: 1)
        b.obj(.bench, 46, 20, w: 3, h: 1)
        b.spot("yard.bleacher.1", 15.5, 27.6, .up)
        b.spot("yard.bleacher.2", 18.5, 27.6, .up)
        b.spot("yard.bleacher.3", 21.5, 27.6, .up)
        b.spot("yard.bench.1", 41.5, 21.5, .up)
        b.spot("yard.bench.2", 47.5, 21.5, .up)
        b.spot("yard.track.1", 29.0, 23.0, .right)
        b.spot("yard.track.2", 56.0, 23.0, .down)
        b.spot("yard.track.3", 56.0, 37.0, .left)
        b.spot("yard.track.4", 29.0, 37.0, .up)
        b.spot("yard.post", 36.5, 38.5, .up)
        b.spot("yard.corner", 52.5, 31.5, .left)
        b.obj(.dumpster, 56, 13, w: 2, h: 1, id: "yard.dumpster")
        b.door("yard.gate", 36, 40, vertical: false, kind: .gate, rule: .any([.staff, .schedule([.rec]), .job(.grounds), .all([.trust(4), .schedule([.freeTime])])]), name: "Yard gate")
        b.camera("cam.yard", 13.0, 39.0, heading: -0.8, sweep: 0.6, period: 10, range: 9)
    }

    // MARK: Vocational rehab

    static func buildVocRehab(_ b: MapBuilder) {
        let vocJobs: AccessRule = .any([.staff, .schedule([.work, .afternoon]), .job(.laundry), .job(.workshop)])
        b.zone("voc.laundry", "Laundry", TileRect(62, 12, 16, 13), .vocrehab, .work)
        b.zone("voc.workshop", "Workshop", TileRect(79, 12, 22, 13), .vocrehab, .work)
        b.zone("voc.sewing", "Sewing & assembly", TileRect(62, 26, 16, 14), .vocrehab, .work)
        b.zone("voc.hall", "Voc hall", TileRect(79, 26, 3, 14), .vocrehab, .transit, label: false)
        b.zone("voc.cold", "Cold storage", TileRect(83, 26, 8, 14), .vocrehab, .service)
        b.zone("voc.cartbay", "Cart bay", TileRect(92, 26, 9, 14), .vocrehab, .service)
        b.door("voc.entry", 80, 40, vertical: false, kind: .secure, rule: vocJobs, name: "Voc rehab entry")
        b.door("voc.workshop.door", 80, 25, vertical: false, rule: .any([.staff, .job(.workshop), .schedule([.work, .afternoon])]), name: "Workshop")
        b.door("voc.sewing.door", 78, 32, vertical: true, rule: .open, name: "Sewing room")
        b.door("voc.laundry.door", 70, 25, vertical: false, rule: .open, name: "Laundry")
        b.door("voc.cold.door", 82, 30, vertical: true, rule: .any([.staff, .job(.kitchen), .job(.laundry)]), name: "Cold storage")
        b.door("voc.cartbay.door", 91, 34, vertical: true, rule: .any([.staff, .job(.laundry), .key(.utilityKey)]), name: "Cart bay")
        // Laundry.
        for k in 0..<5 { b.obj(.washer, 63 + k * 2, 13, id: "laundry.washer\(k + 1)") }
        for k in 0..<3 { b.obj(.dryer, 73 + k * 2, 13, id: "laundry.dryer\(k + 1)") }
        b.obj(.foldTable, 64, 17, w: 4, h: 2, id: "laundry.fold")
        b.obj(.foldTable, 70, 17, w: 4, h: 2, id: "laundry.fold2")
        b.obj(.hamper, 63, 22, id: "laundry.bin1")
        b.obj(.hamper, 65, 22, id: "laundry.bin2")
        b.obj(.hamper, 67, 22, id: "laundry.bin3")
        b.obj(.closetShelf, 75, 20, w: 2, h: 3, id: "laundry.uniforms")
        b.obj(.trayCart, 72, 22, w: 2, h: 1, id: "laundry.cart")
        b.spot("laundry.station", 68.5, 20.5, .up)
        b.spot("laundry.feld", 74.5, 18.5, .left)
        b.spot("laundry.worker.1", 65.5, 20.0, .up)
        b.spot("laundry.worker.2", 71.5, 20.0, .up)
        // Workshop.
        b.obj(.workbench, 81, 14, w: 4, h: 2, id: "workshop.bench1")
        b.obj(.workbench, 87, 14, w: 4, h: 2, id: "workshop.bench2")
        b.obj(.workbench, 81, 19, w: 4, h: 2, id: "workshop.bench3")
        b.obj(.workbench, 87, 19, w: 4, h: 2, id: "workshop.bench4")
        b.obj(.toolBoard, 99, 13, w: 1, h: 4, id: "workshop.tools")
        b.obj(.crate, 96, 21, id: "workshop.scrap")
        b.obj(.crate, 98, 21, id: "workshop.parts")
        b.obj(.desk, 94, 14, w: 2, h: 1, id: "workshop.desk")
        b.spot("workshop.station", 83.0, 17.0, .up)
        b.spot("workshop.feld", 95.0, 15.5, .left)
        b.spot("workshop.worker.1", 89.0, 17.0, .up)
        b.spot("workshop.worker.2", 83.0, 22.0, .up)
        b.spot("workshop.worker.3", 89.0, 22.0, .up)
        // Sewing.
        for k in 0..<4 { b.obj(.sewing, 63 + k * 3, 28, w: 2, h: 1, id: "sewing.machine\(k + 1)") }
        for k in 0..<4 { b.obj(.sewing, 63 + k * 3, 33, w: 2, h: 1, id: "sewing.machine\(k + 5)") }
        b.obj(.closetShelf, 76, 36, w: 1, h: 3, id: "sewing.shelf")
        b.obj(.donationBox, 63, 38, w: 2, h: 1, id: "donation.box")
        b.spot("sewing.station", 64.0, 29.6, .up)
        b.spot("sewing.worker.1", 67.0, 29.6, .up)
        b.spot("sewing.worker.2", 70.0, 34.6, .up)
        // Cold storage & cart bay.
        b.obj(.fridge, 84, 27, w: 2, h: 1); b.obj(.fridge, 87, 27, w: 2, h: 1)
        b.obj(.pantry, 84, 32, w: 1, h: 4, id: "cold.shelf1"); b.obj(.pantry, 89, 32, w: 1, h: 4, id: "cold.shelf2")
        b.obj(.crate, 86, 38, id: "cold.crate")
        b.obj(.vent, 90, 27, id: "ceiling.voc", variant: 1)
        b.obj(.cartBay, 93, 27, w: 3, h: 2, id: "cartbay.laundrycart")
        b.obj(.cartBay, 97, 27, w: 3, h: 2, id: "cartbay.janitorcart")
        b.obj(.dumpster, 98, 37, w: 2, h: 2, id: "cartbay.dumpster")
        b.obj(.hatch, 94, 37, id: "hatch.cartbay")
        b.spot("cartbay.drive", 95.5, 31.5, .down)
        b.spot("voc.hall.post", 80.5, 33.5, .down)
        b.camera("cam.voc", 81.0, 26.5, heading: .pi / 2, sweep: 0.4, period: 9, range: 8)
    }

    // MARK: Kitchen

    static func buildKitchen(_ b: MapBuilder) {
        let mealsRule: AccessRule = .any([.staff, .schedule(meals), .job(.kitchen)])
        let kitchenRule: AccessRule = .any([.staff, .job(.kitchen)])
        b.zone("kitchen.dining", "Dining hall", TileRect(104, 12, 24, 28), .kitchen, .dining)
        b.zone("kitchen.serving", "Serving line", TileRect(129, 12, 4, 28), .kitchen, .work)
        b.zone("kitchen.prep", "Prep kitchen", TileRect(134, 12, 15, 11), .kitchen, .work)
        b.zone("kitchen.dish", "Dish pit", TileRect(134, 24, 15, 6), .kitchen, .work)
        b.zone("kitchen.storage", "Food storage", TileRect(134, 31, 15, 9), .kitchen, .work)
        b.door("dining.door.w", 110, 40, vertical: false, kind: .secure, rule: mealsRule, name: "Dining hall")
        b.door("dining.door.e", 121, 40, vertical: false, kind: .secure, rule: mealsRule, name: "Dining hall")
        b.door("kitchen.staffdoor", 130, 40, vertical: false, kind: .secure, rule: kitchenRule, name: "Kitchen entry")
        b.door("kitchen.serving.door", 128, 15, vertical: true, rule: kitchenRule, name: "Serving line")
        b.door("kitchen.prep.door", 133, 17, vertical: true, rule: kitchenRule, name: "Prep")
        b.door("kitchen.dish.door", 133, 26, vertical: true, rule: kitchenRule, name: "Dish pit")
        b.door("kitchen.storage.door", 133, 35, vertical: true, rule: .any([.staff, .job(.kitchen)]), name: "Storage")
        b.door("kitchen.prepdish.door", 141, 23, vertical: false, rule: kitchenRule, name: "Prep to dish")
        // Serving windows (solid, transparent).
        for y in 20...34 where y % 2 == 0 { b.window(128, y) }
        // Dining tables.
        var t = 0
        for row in 0..<4 {
            for col in 0..<3 {
                t += 1
                let x = 107 + col * 7, y = 15 + row * 6
                b.obj(.table, x, y, w: 3, h: 2, id: "dining.table\(t)")
                b.obj(.bench, x, y - 1, w: 3, h: 1)
                b.obj(.bench, x, y + 2, w: 3, h: 1)
                b.spot("dining.t\(t).a", Double(x) + 0.5, Double(y) - 1.5, .down)
                b.spot("dining.t\(t).b", Double(x) + 2.5, Double(y) - 1.5, .down)
                b.spot("dining.t\(t).c", Double(x) + 0.5, Double(y) + 3.5, .up)
                b.spot("dining.t\(t).d", Double(x) + 2.5, Double(y) + 3.5, .up)
            }
        }
        b.spot("dining.line.1", 126.5, 22.5, .right)
        b.spot("dining.line.2", 126.5, 25.5, .right)
        b.spot("dining.line.3", 126.5, 28.5, .right)
        b.spot("dining.post", 105.5, 38.0, .up)
        b.spot("dining.post2", 124.5, 13.5, .down)
        b.obj(.trayCart, 105, 13, w: 2, h: 1, id: "dining.traycart")
        // Serving line.
        b.obj(.counter, 131, 18, w: 1, h: 18, id: "serving.counter")
        b.spot("serving.station", 129.5, 27.0, .left)
        b.spot("serving.worker.1", 129.5, 22.0, .left)
        b.spot("serving.worker.2", 130.5, 31.0, .left)
        // Prep.
        b.obj(.stove, 136, 13, w: 3, h: 1, id: "prep.stove1"); b.obj(.stove, 140, 13, w: 3, h: 1, id: "prep.stove2")
        b.obj(.prepTable, 136, 17, w: 4, h: 2, id: "prep.table1"); b.obj(.prepTable, 142, 17, w: 4, h: 2, id: "prep.table2")
        b.obj(.pantry, 147, 13, w: 1, h: 4, id: "prep.spices")
        b.spot("prep.station", 138.0, 20.0, .up)
        b.spot("prep.odell", 144.0, 20.5, .up)
        b.spot("prep.worker.1", 143.0, 15.0, .down)
        // Dish pit.
        b.obj(.dishRack, 136, 25, w: 4, h: 1, id: "dish.rack"); b.obj(.sink, 141, 25, w: 3, h: 1, id: "dish.sink")
        b.spot("dish.station", 142.0, 27.5, .up)
        // Storage.
        for k in 0..<3 { b.obj(.pantry, 136 + k * 4, 32, w: 2, h: 1, id: "storage.shelf\(k + 1)") }
        for k in 0..<3 { b.obj(.pantry, 136 + k * 4, 36, w: 2, h: 1, id: "storage.shelfb\(k + 1)") }
        b.obj(.crate, 147, 38, id: "storage.crate")
        b.obj(.hatch, 146, 33, id: "hatch.kitchen")
        b.spot("storage.station", 141.5, 34.5, .up)
        b.camera("cam.dining", 104.5, 12.5, heading: 0.8, sweep: 0.5, period: 12, range: 10)
    }

    // MARK: Corridors

    static func buildCorridors(_ b: MapBuilder) {
        b.zone("corridor.main", "Main corridor", TileRect(12, 41, 137, 4), .corridor, .transit)
        b.zone("corridor.lower", "Lower corridor", TileRect(56, 82, 74, 3), .corridor, .staffOnly)
        b.zone("corridor.staff", "Staff corridor", TileRect(58, 62, 3, 19), .corridor, .staffOnly)
        b.spot("corridor.post.w", 30.5, 43.5, .right)
        b.spot("corridor.post.c", 75.5, 43.5, .down)
        b.spot("corridor.post.e", 125.5, 43.5, .left)
        b.spot("corridor.w", 14.5, 42.5, .right)
        b.spot("corridor.e", 147.5, 42.5, .left)
        b.spot("corridor.mid", 95.5, 42.5, .left)
        b.spot("lower.w", 57.5, 83.5, .right)
        b.spot("lower.e", 128.5, 83.5, .left)
        b.obj(.waterCooler, 48, 41)
        b.obj(.noticeBoard, 60, 41, w: 2, h: 1, id: "corridor.board")
        b.obj(.sign, 33, 41)
        b.obj(.plant, 100, 41)
        b.obj(.mailbox, 90, 41, id: "corridor.mailbox")
        b.camera("cam.corridor.w", 13.0, 41.2, heading: 0.15, range: 10)
        b.camera("cam.corridor.e", 148.0, 41.2, heading: .pi - 0.15, range: 10)
        b.camera("cam.corridor.c", 66.0, 41.2, heading: .pi / 2, sweep: 1.2, period: 10, range: 8)
        b.door("lower.lawn.door", 125, 85, vertical: false, kind: .secure, rule: .any([.staff, .job(.grounds)]), name: "Lawn door")
    }

    // MARK: F-Pod

    static func buildFPod(_ b: MapBuilder) {
        b.zone("fpod.station", "Officer station", TileRect(12, 46, 9, 7), .fpod, .staffOnly)
        b.zone("fpod.entry", "Pod entry", TileRect(22, 46, 5, 5), .fpod, .home)
        b.zone("fpod.dayroom", "Dayroom", TileRect(22, 52, 29, 17), .fpod, .home)
        b.zone("fpod.dayroom", "Dayroom", TileRect(12, 54, 10, 15), .fpod, .home)
        for (n, r) in cellRects.sorted(by: { $0.key < $1.key }) {
            b.zone("fpod.cell\(n)", "Cell F-\(n)", r, .fpod, .cell, cell: n)
        }
        b.zone("fpod.showers", "Showers", TileRect(42, 70, 5, 5), .fpod, .home)
        b.zone("fpod.laundry", "Laundry alcove", TileRect(48, 70, 3, 5), .fpod, .home)
        b.zone("fpod.closet", "Janitor closet", TileRect(48, 46, 3, 5), .fpod, .closet)

        b.door("fpod.main", 24, 45, vertical: false, kind: .secure, rule: .any([.staff, .schedule(movement)]), name: "F-Pod door")
        b.door("fpod.station.door", 16, 45, vertical: false, kind: .secure, rule: .staff, name: "Station door")
        b.door("fpod.station.inner", 16, 53, vertical: false, kind: .interior, rule: .staff, name: "Station")
        b.door("fpod.entry.inner", 24, 51, vertical: false, rule: .open, name: "Pod entry")
        b.window(21, 47); b.window(21, 48); b.window(21, 49)
        for x in [13, 14, 15, 17, 18, 19, 20] { b.window(x, 53) }
        b.door("fpod.closet.door", 49, 51, vertical: false, rule: .any([.staff, .key(.janitorKey), .job(.janitorial)]), name: "Janitor closet")
        b.door("fpod.showers.door", 44, 69, vertical: false, rule: .schedule(cellsOpen), name: "Showers")
        b.door("fpod.laundry.door", 49, 69, vertical: false, rule: .schedule(cellsOpen), name: "Laundry alcove")
        for n in 1...10 {
            let r = cellRects[n]!
            let top = n <= 4
            b.door("fpod.cell\(n).door", r.x + 1, top ? r.maxY + 1 : r.y - 1, vertical: false, kind: .cell,
                   rule: .any([.staff, .schedule(cellsOpen)]), name: "Cell F-\(n)")
            // Furniture: bunk along the far wall, toilet + sink, locker, desk.
            let bunkY = top ? r.y : r.y + 3
            b.obj(.bunk, r.x, bunkY, w: 1, h: 2, facing: top ? .down : .up, id: "fpod.cell\(n).bunk")
            b.obj(.toilet, r.maxX, top ? r.y : r.maxY, id: "fpod.cell\(n).toilet")
            b.obj(.sink, r.maxX, top ? r.y + 1 : r.maxY - 1, id: "fpod.cell\(n).sink")
            b.obj(.locker, r.maxX - 1, top ? r.y : r.maxY, id: "fpod.cell\(n).locker")
            b.obj(.vent, r.x + 1, top ? r.y : r.maxY, id: "fpod.cell\(n).vent")
            let doorX = Double(r.x + 1) + 0.5
            b.spot("fpod.cell\(n).count", doorX + 1.0, top ? Double(r.maxY) + 0.4 : Double(r.y) + 0.6, top ? .down : .up)
            b.spot("fpod.cell\(n).bunkA", Double(r.x) + 1.5, top ? Double(r.y) + 0.8 : Double(r.maxY) + 0.2, top ? .left : .left)
            b.spot("fpod.cell\(n).bunkB", Double(r.x) + 1.5, top ? Double(r.y) + 2.0 : Double(r.maxY) - 1.0, .left)
            b.spot("fpod.cell\(n).door.out", doorX, top ? Double(r.maxY) + 2.5 : Double(r.y) - 1.5, top ? .up : .down)
        }
        // Officer station.
        b.obj(.desk, 13, 47, w: 3, h: 1, id: "fpod.station.desk")
        b.obj(.console, 17, 47, w: 2, h: 1, id: "fpod.station.console")
        b.obj(.chartRack, 20, 50, id: "fpod.chartrack")
        b.obj(.filing, 12, 50, id: "fpod.station.files")
        b.spot("fpod.station.seat", 14.5, 48.6, .down)
        b.spot("fpod.station.window", 18.5, 52.0, .down)
        // Dayroom.
        b.obj(.tv, 50, 58, w: 1, h: 3, facing: .left, id: "fpod.tv")
        b.obj(.medWindow, 18, 54, w: 2, h: 1, id: "fpod.medwindow")
        b.obj(.phone, 12, 58, id: "fpod.phone")
        b.obj(.noticeBoard, 12, 62, w: 1, h: 2, id: "fpod.board")
        b.obj(.waterCooler, 50, 54, id: "fpod.cooler")
        var tn = 0
        for (x, y) in [(25, 57), (32, 57), (39, 57), (25, 63), (32, 63), (39, 63)] {
            tn += 1
            b.obj(.table, x, y, w: 3, h: 2, id: "fpod.table\(tn)")
            b.spot("fpod.t\(tn).a", Double(x) + 0.5, Double(y) - 0.5, .down)
            b.spot("fpod.t\(tn).b", Double(x) + 2.5, Double(y) - 0.5, .down)
            b.spot("fpod.t\(tn).c", Double(x) + 0.5, Double(y) + 2.6, .up)
            b.spot("fpod.t\(tn).d", Double(x) + 2.5, Double(y) + 2.6, .up)
        }
        b.obj(.chair, 46, 58); b.obj(.chair, 46, 60)
        b.spot("fpod.tv.1", 47.5, 58.5, .right)
        b.spot("fpod.tv.2", 47.5, 59.5, .right)
        b.spot("fpod.tv.3", 47.5, 60.5, .right)
        b.obj(.stack, 22, 60, w: 1, h: 3, id: "fpod.bookcart")
        b.obj(.plant, 22, 67)
        b.obj(.rug, 44, 62, w: 4, h: 3)
        b.obj(.piano, 47, 65, w: 2, h: 1, id: "fpod.piano")
        b.spot("fpod.medline.1", 18.5, 55.7, .up)
        b.spot("fpod.medline.2", 20.5, 56.3, .left)
        b.spot("fpod.medline.3", 22.5, 56.3, .left)
        b.spot("fpod.nurse", 18.5, 52.6, .down)
        b.spot("fpod.patrol.1", 23.5, 53.5, .right)
        b.spot("fpod.patrol.2", 49.5, 53.5, .down)
        b.spot("fpod.patrol.3", 49.5, 67.5, .left)
        b.spot("fpod.patrol.4", 14.5, 67.5, .up)
        b.spot("fpod.patrol.5", 14.5, 55.5, .right)
        b.spot("fpod.center", 36.0, 61.0, .down)
        b.spot("fpod.phone.use", 13.5, 58.5, .left)
        b.spot("fpod.entry.in", 24.5, 48.5, .down)
        b.spot("fpod.piano.sit", 48.0, 66.5, .up)
        // Showers.
        for k in 0..<3 { b.obj(.shower, 42 + k * 2, 73, w: 1, h: 2, id: "fpod.shower\(k + 1)") }
        b.obj(.divider, 43, 73, w: 1, h: 2); b.obj(.divider, 45, 73, w: 1, h: 2)
        b.obj(.sink, 46, 70, id: "fpod.showersink")
        // Laundry alcove.
        b.obj(.washer, 50, 70, id: "fpod.washer")
        b.obj(.hamper, 48, 73, id: "fpod.hamper")
        b.obj(.hamper, 50, 73, id: "fpod.hamper2")
        // Janitor closet.
        b.obj(.closetShelf, 48, 46, w: 1, h: 2, id: "fpod.closet.shelf")
        b.obj(.mopBucket, 50, 46, id: "fpod.closet.mop")
        b.obj(.hatch, 50, 49, id: "hatch.fpod")
        b.camera("cam.fpod", 50.5, 52.5, heading: .pi * 0.8, sweep: 0.5, period: 11, range: 8)
    }

    // MARK: Control

    static func buildControl(_ b: MapBuilder) {
        b.zone("control.booth", "Control booth", TileRect(52, 46, 15, 6), .control, .secure)
        b.zone("control.keys", "Key storage", TileRect(52, 53, 5, 8), .control, .secure)
        b.zone("control.passage", "Control passage", TileRect(58, 53, 3, 8), .control, .staffOnly, label: false)
        b.zone("control.monitor", "Monitoring room", TileRect(62, 53, 5, 8), .control, .secure)
        b.door("control.door", 59, 45, vertical: false, kind: .secure, rule: .staff, name: "Control")
        for x in [53, 54, 55, 56, 57, 61, 62, 63, 64, 65] { b.window(x, 45) }
        b.door("control.keys.door", 54, 52, vertical: false, kind: .secure, rule: .staff, name: "Key storage")
        b.door("control.monitor.door", 64, 52, vertical: false, kind: .secure, rule: .staff, name: "Monitoring")
        b.door("control.passage.door", 59, 52, vertical: false, kind: .secure, rule: .staff, name: "Control passage")
        b.door("control.staffcorridor", 59, 61, vertical: false, kind: .secure, rule: .staff, name: "Staff corridor")
        b.door("staffcorridor.lower", 59, 81, vertical: false, rule: .staff, name: "Staff corridor")
        b.obj(.console, 53, 47, w: 4, h: 1, id: "control.console1")
        b.obj(.console, 61, 47, w: 4, h: 1, id: "control.console2")
        b.obj(.desk, 57, 49, w: 2, h: 1, id: "control.desk")
        b.spot("control.seat", 58.0, 48.5, .up)
        b.spot("control.seat2", 63.0, 48.5, .up)
        b.obj(.keyCabinet, 52, 54, w: 1, h: 4, id: "control.keycabinet")
        b.obj(.locker, 56, 59, id: "control.evidence")
        b.obj(.console, 62, 54, w: 4, h: 1, id: "control.monitors")
        b.obj(.filing, 66, 59, id: "control.logs")
        b.obj(.desk, 62, 57, w: 2, h: 1)
        b.spot("control.monitor.seat", 63.5, 55.6, .up)
    }

    // MARK: Support wing

    static func buildSupport(_ b: MapBuilder) {
        let program: AccessRule = .any([.staff, .schedule([.therapy, .afternoon, .freeTime, .chapel, .work, .review])])
        b.zone("support.hall", "Support hall", TileRect(80, 46, 3, 35), .support, .transit, label: false)
        b.zone("support.group", "Group room", TileRect(68, 46, 11, 11), .support, .program)
        b.zone("support.office", "Dr. Sato's office", TileRect(68, 58, 11, 7), .support, .staffOnly)
        b.zone("support.infirmary", "Infirmary", TileRect(68, 66, 11, 15), .support, .medical)
        b.zone("support.library", "Library", TileRect(84, 46, 13, 15), .support, .program)
        b.zone("support.lawlib", "Law library", TileRect(98, 46, 7, 15), .support, .program)
        b.zone("support.chapel", "Chapel", TileRect(84, 62, 13, 11), .support, .program)
        b.zone("support.quiet", "Quiet room", TileRect(98, 62, 7, 6), .support, .program)
        b.zone("support.ante", "PPE anteroom", TileRect(84, 74, 13, 7), .support, .isolation)
        b.zone("support.isolation", "Isolation room", TileRect(98, 69, 7, 12), .support, .isolation)
        b.door("support.entry", 81, 45, vertical: false, kind: .secure, rule: program, name: "Support wing")
        b.door("support.group.door", 79, 51, vertical: true, rule: .open, name: "Group room")
        b.door("support.office.door", 79, 61, vertical: true, rule: .any([.staff, .flag(.lawyerVisitScheduled), .schedule([.review])]), name: "Dr. Sato")
        b.door("support.infirmary.door", 79, 70, vertical: true, kind: .secure, rule: .any([.staff, .job(.infirmary), .schedule([.medPass, .afternoon, .work])]), name: "Infirmary")
        b.door("support.library.door", 83, 52, vertical: true, rule: .any([.staff, .job(.library), .schedule([.afternoon, .freeTime, .work])]), name: "Library")
        b.door("support.lawlib.door", 97, 56, vertical: true, rule: .any([.staff, .job(.library), .flag(.libraryCardIssued)]), name: "Law library")
        b.door("support.chapel.door", 83, 66, vertical: true, rule: .any([.staff, .schedule([.chapel, .freeTime, .afternoon])]), name: "Chapel")
        b.door("support.quiet.door", 97, 64, vertical: true, rule: .open, name: "Quiet room")
        b.door("support.ante.door", 83, 77, vertical: true, rule: .any([.staff, .job(.infirmary), .flag(.ppeRouteKnown)]), name: "PPE anteroom")
        b.door("support.isolation.door", 97, 75, vertical: true, kind: .secure, rule: .any([.staff, .flag(.ppeRouteKnown)]), name: "Isolation")
        b.door("support.lower", 81, 81, vertical: false, kind: .secure, rule: .staff, name: "Lower corridor")
        // Group room.
        for (x, y) in [(70, 48), (75, 48), (70, 53), (75, 53), (72, 50)] { b.obj(.chair, x, y) }
        b.obj(.rug, 71, 49, w: 4, h: 3)
        b.obj(.easel, 77, 47, id: "group.easel")
        b.obj(.table, 68, 55, w: 3, h: 1, id: "group.arttable")
        b.spot("group.lead", 73.0, 48.0, .down)
        for (k, (x, y)) in [(70.5, 49.5), (75.5, 49.5), (70.5, 54.5), (75.5, 54.5), (72.5, 51.5), (74.5, 53.0)].enumerated() {
            b.spot("group.seat\(k + 1)", x, y, .down)
        }
        b.spot("group.art", 69.5, 54.3, .down)
        // Sato's office.
        b.obj(.desk, 72, 59, w: 3, h: 1, id: "sato.desk")
        b.obj(.filing, 68, 58, id: "sato.files")
        b.obj(.chair, 73, 62)
        b.obj(.plant, 78, 58)
        b.spot("sato.seat", 73.5, 58.7, .down)
        b.spot("sato.client", 73.5, 61.2, .up)
        // Infirmary.
        for k in 0..<3 { b.obj(.bed, 69 + k * 3, 67, w: 2, h: 3, id: "infirmary.bed\(k + 1)") }
        b.obj(.desk, 75, 73, w: 3, h: 1, id: "infirmary.desk")
        b.obj(.closetShelf, 68, 74, w: 1, h: 3, id: "infirmary.supplies")
        b.obj(.closetShelf, 68, 78, w: 1, h: 3, id: "infirmary.medstore")
        b.obj(.trayCart, 72, 77, w: 2, h: 1, id: "infirmary.medcart")
        b.obj(.ramp, 76, 77, w: 2, h: 3, id: "infirmary.ramp")
        b.obj(.hatch, 70, 80, id: "hatch.infirmary")
        b.spot("infirmary.station", 76.0, 74.6, .up)
        b.spot("infirmary.nurse", 76.5, 72.5, .down)
        b.spot("infirmary.orderly", 71.0, 75.5, .left)
        b.spot("infirmary.bed1", 70.0, 70.5, .up)
        // Library.
        for k in 0..<4 { b.obj(.shelf, 85 + k * 3, 47, w: 1, h: 5, id: "library.shelf\(k + 1)") }
        b.obj(.stack, 95, 47, w: 1, h: 5, id: "library.stacks")
        b.obj(.table, 86, 55, w: 3, h: 2, id: "library.table1")
        b.obj(.table, 91, 55, w: 3, h: 2, id: "library.table2")
        b.obj(.desk, 92, 59, w: 3, h: 1, id: "library.desk")
        b.obj(.stack, 84, 59, w: 2, h: 1, id: "library.returns")
        b.spot("library.station", 93.5, 58.4, .down)
        b.spot("library.abernathy", 93.5, 60.4, .up)
        b.spot("library.seat1", 86.5, 54.5, .down)
        b.spot("library.seat2", 92.5, 54.5, .down)
        b.spot("library.seat3", 87.5, 57.5, .up)
        // Law library.
        b.obj(.shelf, 98, 47, w: 1, h: 6, id: "lawlib.shelf1")
        b.obj(.shelf, 104, 47, w: 1, h: 6, id: "lawlib.shelf2")
        b.obj(.typewriter, 100, 55, w: 2, h: 1, id: "lawlib.typewriter")
        b.obj(.table, 100, 58, w: 3, h: 1, id: "lawlib.table")
        b.spot("lawlib.seat", 101.0, 57.5, .down)
        b.spot("lawlib.type", 101.0, 56.5, .up)
        // Chapel.
        for k in 0..<4 { b.obj(.pew, 86, 64 + k * 2, w: 4, h: 1, id: "chapel.pew\(k + 1)"); b.obj(.pew, 92, 64 + k * 2, w: 4, h: 1, id: "chapel.pewb\(k + 1)") }
        b.obj(.altar, 89, 72, w: 3, h: 1, id: "chapel.altar")
        b.obj(.closetShelf, 84, 71, w: 1, h: 2, id: "chapel.hymnals")
        b.spot("chapel.lead", 90.5, 71.4, .up)
        b.spot("chapel.seat1", 87.5, 65.0, .down)
        b.spot("chapel.seat2", 93.5, 67.0, .down)
        // Quiet room.
        b.obj(.chair, 100, 63); b.obj(.rug, 99, 64, w: 4, h: 2); b.obj(.plant, 104, 62)
        b.spot("quiet.seat", 101.5, 64.5, .down)
        // Ante + isolation.
        b.obj(.closetShelf, 85, 75, w: 1, h: 3, id: "ante.ppe")
        b.obj(.sink, 90, 75, id: "ante.sink")
        b.obj(.hamper, 95, 79, id: "ante.bin")
        b.obj(.bed, 101, 72, w: 2, h: 3, id: "isolation.bed")
        b.obj(.chair, 103, 77)
        b.spot("isolation.patient", 102.0, 76.0, .left)
        b.spot("ante.station", 88.5, 77.5, .right)
        b.spot("support.hall.post", 81.5, 56.5, .down)
        b.camera("cam.support", 81.5, 46.5, heading: .pi / 2, range: 10)
    }

    // MARK: Administration

    static func buildAdmin(_ b: MapBuilder) {
        let adminRule: AccessRule = .any([.staff, .schedule([.afternoon, .freeTime, .visiting, .review])])
        b.zone("admin.hall", "Admin hall", TileRect(116, 46, 3, 35), .admin, .adminPublic, label: false)
        b.zone("admin.commissary", "Commissary", TileRect(106, 46, 9, 7), .admin, .staffOnly)
        b.zone("admin.trust", "Trust fund office", TileRect(106, 54, 9, 7), .admin, .adminPublic)
        b.zone("admin.records", "Records room", TileRect(106, 62, 9, 11), .admin, .secure)
        b.zone("admin.lobby", "Lobby", TileRect(106, 74, 9, 7), .admin, .adminPublic)
        b.zone("admin.visiting", "Visiting room", TileRect(120, 46, 29, 15), .admin, .adminPublic)
        b.zone("admin.clerk", "Records desk", TileRect(120, 62, 29, 5), .admin, .records)
        b.zone("admin.office", "Administrator", TileRect(120, 68, 13, 13), .admin, .staffOnly)
        b.zone("admin.hearing", "Hearing room", TileRect(134, 68, 15, 13), .admin, .program)
        b.door("admin.entry", 117, 45, vertical: false, kind: .secure, rule: adminRule, name: "Administration")
        b.door("admin.commissary.door", 115, 49, vertical: true, rule: .staff, name: "Commissary")
        b.window(110, 45); b.window(111, 45)
        b.door("admin.trust.door", 115, 57, vertical: true, rule: .open, name: "Trust fund office")
        b.door("admin.records.door", 115, 67, vertical: true, kind: .secure, rule: .any([.staff, .key(.recordsKey)]), name: "Records")
        b.door("admin.lobby.door", 115, 77, vertical: true, rule: .open, name: "Lobby")
        b.door("admin.visiting.door", 119, 53, vertical: true, rule: .any([.staff, .schedule([.visiting, .freeTime, .afternoon])]), name: "Visiting room")
        b.door("admin.clerk.door", 119, 64, vertical: true, rule: .open, name: "Records desk")
        b.door("admin.office.door", 119, 74, vertical: true, rule: .staff, name: "Administrator")
        b.door("admin.hearing.door", 141, 67, vertical: false, rule: .any([.staff, .schedule([.review]), .flag(.advocacyMeeting)]), name: "Hearing room")
        b.door("admin.lower", 117, 81, vertical: false, kind: .secure, rule: .staff, name: "Lower corridor")
        b.door("admin.lobby.out", 110, 81, vertical: false, kind: .secure, rule: .staff, name: "Visitor entrance")
        // Commissary.
        b.obj(.commissary, 110, 44, w: 2, h: 1, id: "commissary.window")
        b.obj(.pantry, 107, 47, w: 1, h: 5, id: "commissary.stock")
        b.obj(.desk, 109, 47, w: 3, h: 1)
        b.spot("commissary.clerk", 110.5, 46.6, .up)
        b.spot("commissary.line.1", 110.5, 43.0, .up)
        b.spot("commissary.line.2", 112.5, 43.2, .left)
        // Trust fund office.
        b.obj(.desk, 108, 56, w: 3, h: 1, id: "trust.desk")
        b.obj(.filing, 106, 54, id: "trust.files")
        b.spot("trust.clerk", 109.5, 55.5, .down)
        b.spot("trust.client", 109.5, 58.0, .up)
        // Records.
        for k in 0..<3 { b.obj(.filing, 107 + k * 2, 63, id: "records.cab\(k + 1)") }
        for k in 0..<3 { b.obj(.filing, 107 + k * 2, 67, id: "records.cabb\(k + 1)") }
        b.obj(.desk, 110, 70, w: 3, h: 1, id: "records.desk")
        b.obj(.hatch, 113, 71, id: "hatch.records")
        b.obj(.vent, 113, 63, id: "ceiling.records", variant: 1)
        b.spot("records.inside", 111.0, 65.5, .up)
        // Lobby.
        b.obj(.bench, 107, 75, w: 3, h: 1); b.obj(.bench, 107, 78, w: 3, h: 1); b.obj(.plant, 113, 74)
        b.spot("lobby.seat", 108.5, 76.5, .up)
        // Visiting.
        var vt = 0
        for (x, y) in [(123, 49), (130, 49), (137, 49), (123, 55), (130, 55), (137, 55)] {
            vt += 1
            b.obj(.table, x, y, w: 2, h: 2, id: "visit.table\(vt)")
            b.spot("visit.t\(vt).in", Double(x) - 0.6, Double(y) + 1.0, .right)
            b.spot("visit.t\(vt).out", Double(x) + 2.6, Double(y) + 1.0, .left)
        }
        b.obj(.waterCooler, 147, 47, id: "visit.cooler")
        b.obj(.desk, 144, 58, w: 3, h: 1, id: "visit.desk")
        b.spot("visit.officer", 145.5, 59.5, .left)
        b.obj(.plant, 120, 46)
        // Records desk / clerk.
        b.obj(.counter, 124, 64, w: 10, h: 1, id: "clerk.counter")
        b.obj(.filing, 136, 62, id: "clerk.files1"); b.obj(.filing, 138, 62, id: "clerk.files2")
        b.obj(.desk, 142, 63, w: 3, h: 1, id: "clerk.desk")
        b.spot("clerk.pruitt", 128.5, 63.3, .down)
        b.spot("clerk.client", 128.5, 65.6, .up)
        b.spot("clerk.filing", 137.5, 64.5, .up)
        // Administrator office.
        b.obj(.desk, 124, 71, w: 4, h: 1, id: "admin.desk"); b.obj(.filing, 131, 69); b.obj(.plant, 121, 79)
        b.spot("admin.chair", 126.0, 70.6, .down)
        // Hearing room.
        b.obj(.table, 137, 72, w: 8, h: 2, id: "hearing.table")
        b.spot("hearing.panel.1", 139.0, 71.4, .down)
        b.spot("hearing.panel.2", 142.0, 71.4, .down)
        b.spot("hearing.self", 140.5, 75.0, .up)
        b.spot("hearing.lawyer", 142.5, 75.0, .up)
        b.spot("hearing.peer.1", 136.5, 78.5, .up)
        b.spot("hearing.peer.2", 139.5, 78.5, .up)
        b.spot("hearing.peer.3", 142.5, 78.5, .up)
        b.camera("cam.admin", 117.5, 46.5, heading: .pi / 2, range: 10)
        b.camera("cam.records", 114.5, 62.5, heading: .pi * 0.75, range: 7)
    }

    // MARK: Observation wing

    static func buildObservation(_ b: MapBuilder) {
        let staffOnly: AccessRule = .staff
        b.zone("obs.hall", "Observation hall", TileRect(40, 86, 81, 3), .restricted, .restricted, label: false)
        b.zone("obs.nurse", "Nurse station", TileRect(72, 90, 17, 7), .restricted, .staffOnly)
        b.door("obs.entry", 80, 85, vertical: false, kind: .secure, rule: staffOnly, name: "Observation wing")
        b.door("obs.nurse.door", 80, 89, vertical: false, rule: staffOnly, name: "Nurse station")
        for k in 0..<4 {
            let x = 40 + k * 8
            b.zone("obs.room\(k + 1)", "Observation \(k + 1)", TileRect(x, 90, 7, 7), .restricted, .restricted)
            b.door("obs.room\(k + 1).door", x + 3, 89, vertical: false, kind: .cell, rule: staffOnly, name: "Observation \(k + 1)")
            b.obj(.mattress, x + 1, 93, w: 2, h: 3, id: "obs.room\(k + 1).mattress")
            b.window(x + 1, 89)
            b.spot("obs.room\(k + 1).in", Double(x) + 3.5, 92.0, .down)
            b.spot("obs.room\(k + 1).observer", Double(x) + 2.5, 87.5, .down)
        }
        for k in 0..<4 {
            let x = 90 + k * 8
            b.zone("obs.shu\(k + 1)", "SHU \(k + 1)", TileRect(x, 90, 7, 7), .restricted, .restricted)
            b.door("obs.shu\(k + 1).door", x + 3, 89, vertical: false, kind: .cell, rule: staffOnly, name: "SHU \(k + 1)")
            b.obj(.bunk, x, 94, w: 1, h: 2, id: "obs.shu\(k + 1).bunk")
            b.obj(.toilet, x + 6, 96)
            b.spot("obs.shu\(k + 1).in", Double(x) + 3.5, 92.5, .down)
        }
        b.zone("obs.seclusion", "Seclusion room", TileRect(72, 98, 5, 7), .restricted, .restricted)
        b.zone("obs.chair", "Restraint room", TileRect(78, 98, 5, 7), .restricted, .restricted)
        b.zone("obs.review", "Review room", TileRect(84, 98, 5, 7), .restricted, .restricted)
        b.door("obs.seclusion.door", 74, 97, vertical: false, kind: .cell, rule: staffOnly, name: "Seclusion")
        b.door("obs.chair.door", 80, 97, vertical: false, kind: .cell, rule: staffOnly, name: "Restraint room")
        b.door("obs.review.door", 86, 97, vertical: false, rule: staffOnly, name: "Review room")
        b.obj(.mattress, 73, 100, w: 3, h: 2, id: "seclusion.mattress")
        b.obj(.restraintChair, 80, 101, id: "obs.restraintchair")
        b.obj(.table, 85, 100, w: 3, h: 2, id: "review.table")
        b.obj(.chair, 84, 103); b.obj(.chair, 88, 103)
        b.spot("seclusion.in", 74.5, 102.5, .down)
        b.spot("chair.in", 80.5, 100.4, .down)
        b.spot("review.self", 86.5, 103.0, .up)
        b.spot("review.staff", 86.5, 99.3, .down)
        b.obj(.desk, 76, 92, w: 4, h: 1, id: "obs.nursedesk")
        b.obj(.console, 81, 91, w: 3, h: 1, id: "obs.console")
        b.spot("obs.nurse.seat", 78.0, 93.6, .up)
        b.spot("obs.hall.w", 41.5, 87.5, .right)
        b.spot("obs.hall.e", 119.5, 87.5, .left)
        b.camera("cam.obs", 80.5, 86.5, heading: .pi, sweep: 1.4, period: 12, range: 10)
        // Lower corridor to obs hall door is at (80,85); obs hall continues.
    }

    // MARK: Service tunnels (separate region linked by hatches)

    static func buildTunnels(_ b: MapBuilder) {
        let tunnelRule: AccessRule = .any([.staff, .key(.utilityKey)])
        func t(_ id: String, _ r: TileRect, label: Bool = false) { b.zone(id, "Service tunnel", r, .service, .service, ground: .tunnel, label: label) }
        t("tunnels.trunk", TileRect(180, 12, 2, 117), label: true)
        t("tunnels.a", TileRect(168, 59, 12, 2))   // F-Pod branch
        t("tunnels.b", TileRect(168, 29, 12, 2))   // Voc rehab branch
        t("tunnels.c", TileRect(182, 29, 12, 2))   // Kitchen branch
        t("tunnels.d", TileRect(182, 69, 12, 2))   // Admin branch
        t("tunnels.e", TileRect(168, 89, 12, 2))   // Infirmary branch
        t("tunnels.f", TileRect(182, 119, 8, 2))   // Culvert approach
        t("tunnels.loop", TileRect(186, 40, 2, 29))
        t("tunnels.loop2", TileRect(182, 40, 4, 2))
        b.zone("tunnels.pump", "Pump room", TileRect(170, 100, 8, 6), .service, .service, ground: .tunnel)
        t("tunnels.pumplink", TileRect(178, 102, 2, 2))
        // Landings.
        b.zone("tunnels.landing.a", "Landing A", TileRect(166, 58, 2, 4), .service, .service, ground: .tunnel, label: false)
        b.zone("tunnels.landing.b", "Landing B", TileRect(166, 28, 2, 4), .service, .service, ground: .tunnel, label: false)
        b.zone("tunnels.landing.c", "Landing C", TileRect(194, 28, 2, 4), .service, .service, ground: .tunnel, label: false)
        b.zone("tunnels.landing.d", "Landing D", TileRect(194, 68, 2, 4), .service, .service, ground: .tunnel, label: false)
        b.zone("tunnels.landing.e", "Landing E", TileRect(166, 88, 2, 4), .service, .service, ground: .tunnel, label: false)
        b.zone("tunnels.culvert", "Culvert", TileRect(190, 118, 4, 4), .service, .service, ground: .tunnel, label: false)
        b.obj(.hatch, 166, 59, id: "hatch.t.a")
        b.obj(.hatch, 166, 29, id: "hatch.t.b")
        b.obj(.hatch, 195, 29, id: "hatch.t.c")
        b.obj(.hatch, 195, 69, id: "hatch.t.d")
        b.obj(.hatch, 166, 89, id: "hatch.t.e")
        b.obj(.culvert, 192, 120, id: "culvert.in")
        // Alcoves (hiding).
        b.zone("tunnels.alcove1", "Alcove", TileRect(178, 44, 2, 2), .service, .service, ground: .tunnel, label: false)
        b.zone("tunnels.alcove2", "Alcove", TileRect(182, 80, 2, 2), .service, .service, ground: .tunnel, label: false)
        b.zone("tunnels.alcove3", "Alcove", TileRect(178, 112, 2, 2), .service, .service, ground: .tunnel, label: false)
        b.obj(.crate, 172, 101, id: "pump.crate")
        b.obj(.crate, 178, 44, id: "tunnel.alcove1")
        b.obj(.crate, 183, 81, id: "tunnel.alcove2")
        b.obj(.crate, 178, 112, id: "tunnel.alcove3")
        b.obj(.toolBoard, 177, 100, w: 1, h: 2, id: "pump.tools")
        b.obj(.lamp, 181, 20); b.obj(.lamp, 181, 50); b.obj(.lamp, 181, 80); b.obj(.lamp, 181, 110)
        b.spot("tunnels.alcove1.in", 179.0, 45.0, .right)
        b.spot("tunnels.alcove2.in", 182.5, 80.5, .left)
        b.spot("tunnels.alcove3.in", 179.0, 113.0, .right)
        b.spot("tunnels.patrol.1", 181.0, 14.0, .down)
        b.spot("tunnels.patrol.2", 181.0, 126.0, .up)
        b.spot("tunnels.patrol.3", 175.0, 60.0, .left)
        b.spot("tunnels.patrol.4", 187.0, 55.0, .down)
        b.spot("pump.work", 174.0, 103.0, .up)
        // Hatches link building tiles (a) with landing tiles (b).
        b.hatch("hatch.fpod", a: TilePos(49, 49), b: TilePos(167, 60), rule: tunnelRule, discoveredBy: .tunnelHatchKnown)
        b.hatch("hatch.cartbay", a: TilePos(94, 36), b: TilePos(167, 30), rule: .any([tunnelRule, .job(.laundry)]), discoveredBy: .tunnelHatchKnown)
        b.hatch("hatch.kitchen", a: TilePos(145, 33), b: TilePos(194, 30), rule: tunnelRule, discoveredBy: .tunnelHatchKnown)
        b.hatch("hatch.records", a: TilePos(112, 71), b: TilePos(194, 70), rule: tunnelRule, discoveredBy: .tunnelHatchKnown)
        b.hatch("hatch.infirmary", a: TilePos(71, 80), b: TilePos(167, 90), rule: tunnelRule, discoveredBy: .tunnelHatchKnown)
        b.hatch("culvert", a: TilePos(191, 120), b: TilePos(81, 110), rule: .flag(.escapeStarted), discoveredBy: .culvertKnown)
        b.camera("cam.tunnel", 181.0, 64.0, heading: .pi / 2, sweep: 0.3, period: 8, range: 8)
    }
}
