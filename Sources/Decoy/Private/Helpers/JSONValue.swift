import Foundation

public enum JSONValue: Codable, Hashable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case array([JSONValue])
  case object([String: JSONValue])
  case null

  // Decode using standard Codable.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown JSON type")
    }
  }

  // Encode using standard Codable.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()
    case .bool(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }

  // Helper to create a JSONValue from an arbitrary value.
  public static func from(any: Any) -> JSONValue? {
    switch any {
    case let value as String: return .string(value)
    case let value as Int: return .number(Double(value))
    case let value as Double: return .number(value)
    case let value as Bool: return .bool(value)
    case let value as [Any]: return .array(value.compactMap { JSONValue.from(any: $0) })
    case let value as [String: Any]:
      var dict = [String: JSONValue]()
      for (k, v) in value {
        if let jsonValue = JSONValue.from(any: v) {
          dict[k] = jsonValue
        }
      }
      return .object(dict)
    default: return nil
    }
  }
}
