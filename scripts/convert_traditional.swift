import Foundation

let data = FileHandle.standardInput.readDataToEndOfFile()
let object = try JSONSerialization.jsonObject(with: data) as? [String: String] ?? [:]
var converted: [String: String] = [:]
for (key, value) in object {
    let text = NSMutableString(string: value)
    CFStringTransform(text, nil, "Simplified-Traditional" as CFString, false)
    converted[key] = text as String
}
let output = try JSONSerialization.data(withJSONObject: converted, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(output)
