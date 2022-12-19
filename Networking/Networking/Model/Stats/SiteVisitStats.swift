import Foundation
import Codegen

/// Represents site visit stats over a specific period.
///
public struct SiteVisitStats: Decodable, GeneratedCopiable, GeneratedFakeable {
    public let siteID: Int64
    public let date: String
    public let granularity: StatGranularity
    public let items: [SiteVisitStatsItem]?

    /// The public initializer for order stats.
    ///
    public init(from decoder: Decoder) throws {
        guard let siteID = decoder.userInfo[.siteID] as? Int64 else {
            throw SiteVisitStatsError.missingSiteID
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        let date = try container.decode(String.self, forKey: .date)
        let granularity = try container.decode(StatGranularity.self, forKey: .unit)

        let fieldNames = try container.decode([String].self, forKey: .fields)
        let rawData: [[AnyCodable]] = try container.decode([[AnyCodable]].self, forKey: .data)
        let rawDataContainers = rawData.map({ MIContainer(data: $0.map({ $0.value }), fieldNames: fieldNames) })
        let items = rawDataContainers.map({ SiteVisitStatsItem(period: $0.fetchStringValue(for: ItemFieldNames.period),
                                                               visitors: $0.fetchIntValue(for: ItemFieldNames.visitors),
                                                               views: $0.fetchIntValue(for: ItemFieldNames.views)) })

        self.init(siteID: siteID, date: date, granularity: granularity, items: items)
    }


    /// SiteVisitStats struct initializer.
    ///
    public init(siteID: Int64, date: String, granularity: StatGranularity, items: [SiteVisitStatsItem]?) {
        self.siteID = siteID
        self.date = date
        self.granularity = granularity
        self.items = items
    }

    // MARK: Computed Properties

    public var totalVisitors: Int {
        return items?.map({ $0.visitors }).reduce(0, +) ?? 0
    }
}


/// Defines all of the SiteVisitStats CodingKeys.
///
private extension SiteVisitStats {

    enum CodingKeys: String, CodingKey {
        case date = "date"
        case unit = "unit"
        case fields = "fields"
        case data = "data"
    }
}


// MARK: - Equatable Conformance
//
extension SiteVisitStats: Equatable {
    // custom implementation to ignore order for items
    public static func == (lhs: SiteVisitStats, rhs: SiteVisitStats) -> Bool {
        return lhs.siteID == rhs.siteID &&
            lhs.date == rhs.date &&
            lhs.granularity == rhs.granularity &&
            lhs.items?.count == rhs.items?.count &&
            lhs.items?.sorted() == rhs.items?.sorted()
    }
}


// MARK: - Constants!
//
private extension SiteVisitStats {

    /// Defines all of the possible fields for a SiteVisitStatsItem.
    ///
    enum ItemFieldNames: String {
        case period
        case visitors
        case views
    }
}

// MARK: - Decoding Errors
//
enum SiteVisitStatsError: Error {
    case missingSiteID
}
