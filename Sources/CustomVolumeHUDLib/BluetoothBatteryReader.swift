import Foundation
import IOKit

/// Best-effort battery lookup for Bluetooth audio devices that publish battery data in IOKit.
/// Headsets that do not expose a battery property simply omit the gauge.
enum BluetoothBatteryReader {
    private static let serviceClasses = [
        "AppleDeviceManagementHIDEventService",
        "IOHIDEventService"
    ]

    private static let batteryKeys = Set([
        "BATTERYPERCENT",
        "BATTERYPERCENTSINGLE",
        "BATTERYPERCENTCOMBINED",
        "BATTERYLEVEL",
        "BATTERYPERCENTLEFT",
        "BATTERYPERCENTRIGHT"
    ])

    private static let nameKeys = Set([
        "PRODUCT", "PRODUCTNAME", "DEVICENAME", "NAME"
    ])

    static func percentage(forDeviceNamed deviceName: String) -> Int? {
        guard BluetoothOutputDevice.normalized(deviceName) != "BLUETOOTH AUDIO" else { return nil }

        for serviceClass in serviceClasses {
            guard let matching = IOServiceMatching(serviceClass) else { continue }
            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
                continue
            }
            defer { IOObjectRelease(iterator) }

            var service = IOIteratorNext(iterator)
            while service != 0 {
                defer {
                    IOObjectRelease(service)
                    service = IOIteratorNext(iterator)
                }

                var properties: Unmanaged<CFMutableDictionary>?
                guard IORegistryEntryCreateCFProperties(
                    service,
                    &properties,
                    kCFAllocatorDefault,
                    0
                ) == KERN_SUCCESS,
                let propertyDictionary = properties?.takeRetainedValue() as? [String: Any],
                propertyNames(in: propertyDictionary).contains(where: {
                    namesReferToSameDevice($0, deviceName)
                }),
                let percentage = percentage(in: propertyDictionary) else {
                    continue
                }

                return percentage
            }
        }

        return nil
    }

    static func percentage(in properties: [String: Any]) -> Int? {
        var values: [Int] = []
        collectBatteryValues(in: properties, into: &values)
        // For split earbuds, the lower side is the useful early-warning value.
        return values.min()
    }

    private static func collectBatteryValues(in value: Any, key: String? = nil, into values: inout [Int]) {
        if let dictionary = value as? [String: Any] {
            for (nestedKey, nestedValue) in dictionary {
                collectBatteryValues(in: nestedValue, key: nestedKey, into: &values)
            }
            return
        }

        if let dictionary = value as? NSDictionary {
            for (nestedKey, nestedValue) in dictionary {
                guard let nestedKey = nestedKey as? String else { continue }
                collectBatteryValues(in: nestedValue, key: nestedKey, into: &values)
            }
            return
        }

        guard let key, batteryKeys.contains(key.uppercased()) else { return }
        if let number = value as? NSNumber {
            let rawValue = number.doubleValue
            let percentage = rawValue <= 1 && rawValue >= 0 ? rawValue * 100 : rawValue
            if percentage >= 0 && percentage <= 100 {
                values.append(Int(percentage.rounded()))
            }
        }
    }

    private static func propertyNames(in value: Any, key: String? = nil) -> [String] {
        if let dictionary = value as? [String: Any] {
            return dictionary.flatMap { propertyNames(in: $0.value, key: $0.key) }
        }
        if let dictionary = value as? NSDictionary {
            return dictionary.flatMap { pair -> [String] in
                guard let nestedKey = pair.key as? String else { return [] }
                return propertyNames(in: pair.value, key: nestedKey)
            }
        }
        guard let key, nameKeys.contains(key.uppercased()), let name = value as? String else { return [] }
        return [name]
    }

    private static func namesReferToSameDevice(_ lhs: String, _ rhs: String) -> Bool {
        let left = BluetoothOutputDevice.normalized(lhs)
        let right = BluetoothOutputDevice.normalized(rhs)
        if left.contains(right) || right.contains(left) { return true }

        let ignored = Set(["THE", "AUDIO", "HEADPHONES", "HEADSET", "SAUMYA", "S"])
        let leftTokens = Set(left.split(separator: " ").map(String.init)).subtracting(ignored)
        let rightTokens = Set(right.split(separator: " ").map(String.init)).subtracting(ignored)
        return !leftTokens.intersection(rightTokens).isEmpty
    }
}
