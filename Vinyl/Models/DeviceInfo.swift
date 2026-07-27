import Foundation
import SystemConfiguration

enum DeviceInfo {
    static var computerName: String {
        if let dynamicName = SCDynamicStoreCopyComputerName(nil, nil) as String?,
           !dynamicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return dynamicName
        }
        if let hostName = Host.current().localizedName,
           !hostName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return hostName
        }
        return "Mac"
    }
}
