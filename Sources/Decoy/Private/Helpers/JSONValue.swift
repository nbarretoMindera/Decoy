import Foundation

public enum JSONValue: Codable, Hashable, CustomStringConvertible {
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

  // A human-friendly description of the JSON value, used when generating a GraphQLSignature.
  public var description: String {
    switch self {
    case .string(let value):
      return value
    case .number(let value):
      if value.truncatingRemainder(dividingBy: 1) == 0 {
        return String(format: "%.0f", value)
      } else {
        return String(value)
      }
    case .bool(let value):
      return String(value)
    case .array(let array):
      let items = array.map { $0.description }
      return "[" + items.joined(separator: ", ") + "]"
    case .object(let dict):
      let items = dict
        .sorted(by: { $0.key < $1.key })
        .map { "\($0.key): \($0.value)" }
      return "{" + items.joined(separator: ", ") + "}"
    case .null:
      return "null"
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
  public init?(json: Any) {
    switch json {
    case let value as String:
      self = .string(value)
    case let value as Bool:
      self = .bool(value)
    case let value as Int:
      self = .number(Double(value))
    case let value as Double:
      self = .number(value)
    case let value as [String: Any]:
      var obj = [String: JSONValue]()
      for (k, v) in value {
        guard let vParsed = JSONValue(json: v) else { continue }
        obj[k] = vParsed
      }
      self = .object(obj)
    case let value as [Any]:
      self = .array(value.compactMap { JSONValue(json: $0) })
    case _ as NSNull:
      self = .null
    case let value as NSNumber:
      // NSNumber might be a Bool masquerading as a number.
      let boolType = CFGetTypeID(value) == CFBooleanGetTypeID()
      if boolType {
        self = .bool(value.boolValue)
      } else {
        self = .number(value.doubleValue)
      }
    default:
      return nil
    }
  }
}
