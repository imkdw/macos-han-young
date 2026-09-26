import Darwin

/// 이벤트를 주입한 프로세스가 CRD 호스트(remoting_me2me_host)인지 판별한다
public final class CRDSourceDetector {
    private var cache: [pid_t: Bool] = [:]

    public init() {}

    public func isCRDHost(pid: pid_t) -> Bool {
        guard pid > 0 else { return false }
        if let hit = cache[pid] { return hit }
        let result = Self.executablePath(of: pid)?.hasSuffix("/remoting_me2me_host") ?? false
        cache[pid] = result
        return result
    }

    public static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }
}
