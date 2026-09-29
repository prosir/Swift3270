import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [TerminalSession]
    @Published var selectedSessionID: TerminalSession.ID {
        didSet { saveProfiles() }
    }
    private let storageKey = "swift3270.sessionProfiles.v1"
    private let selectedKey = "swift3270.selectedProfileID.v1"

    init() {
        let profiles = Self.loadProfiles(storageKey: storageKey)
        var initialSessions = profiles.map { TerminalSession(profile: $0) }
        if initialSessions.isEmpty {
            initialSessions = [TerminalSession(profile: .defaultProfile)]
        }

        let savedSelected = UserDefaults.standard.string(forKey: selectedKey)
        let initialSelectedID = initialSessions.first(where: { $0.profile.id == savedSelected })?.id ?? initialSessions[0].id
        sessions = initialSessions
        selectedSessionID = initialSelectedID
        attachProfileCallbacks()
    }

    var selectedSession: TerminalSession {
        if let session = sessions.first(where: { $0.id == selectedSessionID }) {
            return session
        }

        selectedSessionID = sessions[0].id
        return sessions[0]
    }

    func addSession(profile: SessionProfile = .blank()) {
        let session = TerminalSession(profile: profile)
        session.onProfileChanged = { [weak self] in self?.saveProfiles() }
        sessions.append(session)
        selectedSessionID = session.id
        saveProfiles()
    }

    func addSession(
        name: String,
        connectionSpec: String,
        codePage: String,
        applicationCode: String = "",
        userID: String = "",
        autoFillPassphrase: Bool = false
    ) {
        addSession(
            profile: SessionProfile(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nieuwe sessie" : name,
                connectionSpec: connectionSpec.trimmingCharacters(in: .whitespacesAndNewlines),
                codePage: codePage,
                applicationCode: applicationCode,
                userID: userID,
                autoFillPassphrase: autoFillPassphrase
            )
        )
    }

    func duplicateSelectedSession() {
        let sourceProfileID = selectedSession.profile.id
        var profile = selectedSession.profile
        profile.id = UUID().uuidString
        profile.name += " kopie"
        if let passphrase = try? PassphraseKeychain.load(for: sourceProfileID) {
            try? PassphraseKeychain.save(passphrase, for: profile.id)
        }
        addSession(profile: profile)
    }

    func closeSelectedSession() async {
        guard sessions.count > 1,
              let index = sessions.firstIndex(where: { $0.id == selectedSessionID }) else {
            return
        }

        let profileID = sessions[index].profile.id
        await sessions[index].disconnect()
        sessions.remove(at: index)
        try? PassphraseKeychain.delete(for: profileID)
        selectedSessionID = sessions[min(index, sessions.count - 1)].id
        saveProfiles()
    }

    func renameSelectedSession(_ name: String) {
        selectedSession.rename(to: name)
        saveProfiles()
    }

    func updateSelectedSession(
        name: String,
        connectionSpec: String,
        codePage: String,
        applicationCode: String,
        userID: String,
        autoFillPassphrase: Bool
    ) {
        selectedSession.updateProfile(
            name: name,
            connectionSpec: connectionSpec,
            codePage: codePage,
            applicationCode: applicationCode,
            userID: userID,
            autoFillPassphrase: autoFillPassphrase
        )
        saveProfiles()
    }

    private func attachProfileCallbacks() {
        sessions.forEach { session in
            session.onProfileChanged = { [weak self] in self?.saveProfiles() }
        }
    }

    private func saveProfiles() {
        let profiles = sessions.map(\.profile)
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        UserDefaults.standard.set(selectedSession.profile.id, forKey: selectedKey)
    }

    private static func loadProfiles(storageKey: String) -> [SessionProfile] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let profiles = try? JSONDecoder().decode([SessionProfile].self, from: data) else {
            return []
        }
        return profiles.isEmpty ? [] : profiles
    }
}

struct SessionProfile: Identifiable, Equatable, Codable {
    var id: String
    var name: String
    var connectionSpec: String
    var host: String
    var port: Int
    var useTLS: Bool
    var codePage: String
    var applicationCode: String
    var userID: String
    var autoFillPassphrase: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        connectionSpec: String = "",
        host: String = "",
        port: Int = 23,
        useTLS: Bool = false,
        codePage: String = "cp037",
        applicationCode: String = "",
        userID: String = "",
        autoFillPassphrase: Bool = false
    ) {
        self.id = id
        self.name = name
        self.connectionSpec = connectionSpec
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.codePage = codePage
        self.applicationCode = applicationCode
        self.userID = userID
        self.autoFillPassphrase = autoFillPassphrase
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, connectionSpec, host, port, useTLS, codePage
        case applicationCode, userID, autoFillPassphrase
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        connectionSpec = try values.decodeIfPresent(String.self, forKey: .connectionSpec) ?? ""
        host = try values.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try values.decodeIfPresent(Int.self, forKey: .port) ?? 23
        useTLS = try values.decodeIfPresent(Bool.self, forKey: .useTLS) ?? false
        codePage = try values.decodeIfPresent(String.self, forKey: .codePage) ?? "cp037"
        applicationCode = try values.decodeIfPresent(String.self, forKey: .applicationCode) ?? ""
        userID = try values.decodeIfPresent(String.self, forKey: .userID) ?? ""
        autoFillPassphrase = try values.decodeIfPresent(Bool.self, forKey: .autoFillPassphrase) ?? false
    }

    static let defaultProfile = SessionProfile(
        id: "default-mainframe",
        name: "Mainframe",
        connectionSpec: "",
        host: "",
        port: 23,
        useTLS: false,
        codePage: "cp037"
    )

    static func blank() -> SessionProfile {
        SessionProfile(name: "Nieuwe sessie")
    }
}
