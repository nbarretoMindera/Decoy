import Foundation

/// An enumeration that represents a JSON value, supporting all JSON data types.
/// This enum can be used to decode, encode, and manipulate JSON data in a type-safe manner.
public enum JSONValue: Codable, Hashable, CustomStringConvertible {
  /// A JSON string value.
  case string(String)
  /// A JSON number value, represented as a Double.
  case number(Double)
  /// A JSON boolean value.
  case bool(Bool)
  /// A JSON array, represented as an array of `JSONValue` elements.
  case array([JSONValue])
  /// A JSON object, represented as a dictionary with String keys and `JSONValue` values.
  case object([String: JSONValue])
  /// A JSON null value.
  case null

  /// Creates a new instance by decoding from the given decoder.
  ///
  /// This initializer attempts to decode the JSON value in the order of:
  /// null, Bool, Double, String, Array, and Object.
  /// If none of these types match, it throws a decoding error.
  ///
  /// - Parameter decoder: The decoder to read data from.
  /// - Throws: `DecodingError` if the data does not match any JSON type.
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

  /// A human-friendly string representation of the JSON value.
  ///
  /// This property produces a concise textual description of the JSON value,
  /// useful for debugging or generating signatures. For numbers, it omits the decimal
  /// when the value is an integer. Arrays and objects are represented with their
  /// respective delimiters and elements.
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

  /// Encodes this value into the given encoder.
  ///
  /// The encoding matches the JSON type represented by this value.
  ///
  /// - Parameter encoder: The encoder to write data to.
  /// - Throws: An error if any value throws an error during encoding.
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

  /// Creates a `JSONValue` from an arbitrary Foundation object.
  ///
  /// This initializer attempts to map any given object to an appropriate JSONValue case.
  /// It supports Swift native types and Foundation types commonly used to represent JSON data:
  /// - `String` -> `.string`
  /// - `Bool` -> `.bool`
  /// - `Int` and `Double` -> `.number`
  /// - `[String: Any]` -> `.object` (recursive mapping of values)
  /// - `[Any]` -> `.array` (recursive mapping of elements)
  /// - `NSNull` -> `.null`
  /// - `NSNumber` -> `.bool` if it represents a boolean, otherwise `.number`
  ///
  /// If the input cannot be mapped, the initializer returns `nil`.
  ///
  /// - Parameter json: The object to map to a `JSONValue`.
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
      /// NSNumber might be a Bool masquerading as a number, this helps us be sure.
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
