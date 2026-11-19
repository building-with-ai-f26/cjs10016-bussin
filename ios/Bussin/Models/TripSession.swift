import Foundation
import CoreLocation

/// Go mode. Follows one planned shuttle trip step by step, from the walk to the stop to the
/// destination. Pure logic with no UI: every few seconds the app hands it your location and the
/// live buses, and it says which step you're on and when something deserves a buzz.
struct TripSession {
    enum Step: Equatable { case toStop, atStop, riding, getOffNext, toDestination, arrived, timedOut }
    enum Event: Equatable { case switchedBus(from: Int, to: Int), getOffNext, gotOff, arrived, timedOut }

    /// A stop the ride passes, measured in meters past the boarding point. The last one is yours.
    struct RideStop: Equatable {
        let stopId: String
        let offset: Double
    }

    static let besideBus = 50.0      // you and the bus are both GPS fixes, each a little off
    static let pulledAway = 25.0     // the bus must leave the stop by this much with you still beside it
    static let atStopRadius = 40.0
    static let arrivedWithin = 50.0
    static let passedBy = 10.0       // a stop counts as passed once the bus is this far beyond it
    static let busWentBy = 200.0     // the bus you were waiting for jumped this far away: it went past
    static let onRoute = 60.0        // your own location can stand in for a missing bus this close to the line
    static let maxDuration: TimeInterval = 2 * 3600

    let option: TripPlanner.Option
    let destination: CLLocationCoordinate2D
    let boardStop: CLLocationCoordinate2D
    let alightStop: CLLocationCoordinate2D
    let rideStops: [RideStop]
    let startedAt: Date
    private let g: RouteGeometry

    private(set) var step: Step = .toStop
    /// The bus the trip is counting on. It changes if that bus leaves without you.
    private(set) var busId: Int?
    /// Until you board: how long until that bus reaches your stop.
    private(set) var busSecondsAway: Double?
    /// Once aboard: meters ridden past the boarding point, and the time left until your stop.
    private(set) var progress = 0.0
    private(set) var rideSecondsLeft: Double?

    private var besideBusId: Int?
    private var besideCount = 0
    private var lastGap: Double?

    init?(option: TripPlanner.Option, destination: CLLocationCoordinate2D,
          geometry g: RouteGeometry, stops: [String: ShuttleStop], now: Date) {
        guard g.routeId == option.routeId,
              let board = stops[option.boardStopId], let alight = stops[option.alightStopId] else { return nil }
        self.option = option
        self.destination = destination
        self.boardStop = board.coordinate
        self.alightStop = alight.coordinate
        self.startedAt = now
        self.g = g
        self.busId = option.busId

        // Every stop between boarding and getting off, in riding order. A loop lists its first
        // stop again at the end, so drop the repeat; a ride through the loop's start wraps around.
        let entries = g.isLoop ? Array(g.stopDistances.dropLast()) : g.stopDistances
        var passes: [RideStop] = []
        for e in entries {
            var offset = e.distance - option.boardDistance
            if offset < 0 {
                guard g.isLoop else { continue }
                offset += g.length
            }
            if offset > 1 && offset <= option.rideMeters + 1 { passes.append(RideStop(stopId: e.stopId, offset: offset)) }
        }
        passes.sort { $0.offset < $1.offset }
        if passes.last?.stopId != option.alightStopId {
            passes.append(RideStop(stopId: option.alightStopId, offset: option.rideMeters))
        }
        rideStops = passes
    }

    var isOver: Bool { step == .arrived || step == .timedOut }
    var isAboard: Bool { step == .riding || step == .getOffNext }
    var stopsLeft: Int { rideStops.filter { $0.offset > progress + Self.passedBy }.count }
    var nextStopId: String? { rideStops.first { $0.offset > progress + Self.passedBy }?.stopId }

    /// Feed in the latest location and buses. Returns what just happened, if anything.
    mutating func update(me: CLLocationCoordinate2D?, buses: [TrackedBus], now: Date) -> [Event] {
        guard !isOver else { return [] }
        if now.timeIntervalSince(startedAt) > Self.maxDuration {
            step = .timedOut
            return [.timedOut]
        }
        let mine = buses.filter { $0.bus.routeId == option.routeId }
        switch step {
        case .toStop, .atStop:
            return beforeBoarding(me: me, buses: mine)
        case .riding, .getOffNext:
            return whileRiding(me: me, buses: mine)
        case .toDestination:
            if let me, Self.meters(me, destination) <= Self.arrivedWithin {
                step = .arrived
                return [.arrived]
            }
            return []
        case .arrived, .timedOut:
            return []
        }
    }

    // MARK: - Before boarding

    private mutating func beforeBoarding(me: CLLocationCoordinate2D?, buses: [TrackedBus]) -> [Event] {
        var events: [Event] = []

        // Aboard? You've been beside one of this route's buses for two updates in a row, and it
        // has since pulled away from the stop. Standing next to a bus you don't get on doesn't count:
        // when it leaves, you're no longer beside it.
        if let me, let near = buses.filter({ Self.meters(me, $0.bus.coordinate) <= Self.besideBus })
            .min(by: { Self.meters(me, $0.bus.coordinate) < Self.meters(me, $1.bus.coordinate) }) {
            besideCount = near.id == besideBusId ? besideCount + 1 : 1
            besideBusId = near.id
            let ridden = riddenMeters(to: near.distanceAlong)
            if besideCount >= 2, ridden >= Self.pulledAway, ridden < option.rideMeters {
                if let old = busId, old != near.id { events.append(.switchedBus(from: old, to: near.id)) }
                busId = near.id
                busSecondsAway = nil
                step = .riding
                return events + whileRiding(me: me, buses: buses)
            }
        } else {
            besideBusId = nil
            besideCount = 0
        }

        // Still waiting. Keep counting on the same bus unless it went by or vanished from the feed.
        var current = buses.first { $0.id == busId }
        var currentGap = current.flatMap(gapToBoard)
        if current != nil, currentGap == nil { current = nil }       // a one-way line's bus already passed
        if let gap = currentGap, let last = lastGap, gap > last + Self.busWentBy {
            current = nil
            currentGap = nil
        }
        if current == nil {
            let next = buses.filter { $0.id != busId }
                .compactMap { b in gapToBoard(b).map { (bus: b, gap: $0) } }
                .min { $0.gap < $1.gap }
            if let next {
                if let old = busId, old != next.bus.id { events.append(.switchedBus(from: old, to: next.bus.id)) }
                busId = next.bus.id
                current = next.bus
                currentGap = next.gap
            }
        }
        lastGap = currentGap
        if let current, let gap = currentGap {
            busSecondsAway = gap / max(current.speed, 1)
        } else {
            busSecondsAway = nil
        }

        if let me, Self.meters(me, boardStop) <= Self.atStopRadius { step = .atStop } else { step = .toStop }
        return events
    }

    /// Meters the bus still has to drive to reach your boarding stop. Zero when it's at the stop.
    /// Nil on a one-way line once it has gone past.
    private func gapToBoard(_ b: TrackedBus) -> Double? {
        var gap = option.boardDistance - b.distanceAlong
        if g.isLoop {
            gap = gap.truncatingRemainder(dividingBy: g.length)
            if gap < 0 { gap += g.length }
            if gap >= g.length - Self.atStopRadius { return 0 }
        } else if gap < -Self.atStopRadius {
            return nil
        }
        return gap <= Self.atStopRadius ? 0 : gap
    }

    // MARK: - Riding

    private mutating func whileRiding(me: CLLocationCoordinate2D?, buses: [TrackedBus]) -> [Event] {
        var events: [Event] = []

        // How far along the ride you are: from your bus, or from your own location if the bus
        // dropped off the feed. Never backwards, and never a jump to some far part of the route.
        func accept(_ ridden: Double) {
            if ridden >= progress - 50, ridden <= option.rideMeters + Self.busWentBy { progress = max(progress, ridden) }
        }
        if let b = buses.first(where: { $0.id == busId }) {
            accept(riddenMeters(to: b.distanceAlong))
            rideSecondsLeft = max(0, option.rideMeters - progress) / max(b.speed, 1)
        } else if let me {
            let p = g.project(me)
            if p.offsetMeters <= Self.onRoute { accept(riddenMeters(to: p.distanceAlong)) }
            rideSecondsLeft = nil
        }

        // Buzz once, as the bus passes the stop before yours (right away if yours is the first).
        let beforeYours = rideStops.dropLast().last?.offset ?? 0
        if step == .riding, progress > beforeYours + Self.passedBy {
            step = .getOffNext
            events.append(.getOffNext)
        }
        if progress >= option.rideMeters - Self.pulledAway {
            step = .toDestination
            rideSecondsLeft = nil
            events.append(.gotOff)
        }
        return events
    }

    /// Meters along the route from the boarding point to `distance`, wrapping on a loop.
    private func riddenMeters(to distance: Double) -> Double {
        var r = distance - option.boardDistance
        if r < 0 { r = g.isLoop ? r + g.length : -1 }
        return r
    }

    /// Straight-line meters. Walk.meters adds a street detour, which is wrong here.
    static func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        Walk.meters(a, b) / Walk.detour
    }
}
