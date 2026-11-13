#if DEBUG
    import Foundation
    import BaresipKit

    /// Doors, activity and messages for the screenshots CI takes of the app. Only in debug
    /// builds, and only with `BSK_DEMO=1` in the launch environment.
    ///
    /// With `BSK_DEMO_USER`, `BSK_DEMO_PASSWORD` and `BSK_DEMO_DOOR` (a SIP URI) it signs in to a
    /// real PBX instead, with that one door, `BSK_DEMO_CONTACT` as a contact, and no made-up activity:
    /// `Tools/DoorStack/simulators.sh` starts simulators this way against the door stack.
    extension CallModel {
        func seedDemo() {
            let environment = ProcessInfo.processInfo.environment
            guard environment["BSK_DEMO"] == "1", let host = environment["BSK_DEMO_HOST"] else { return }
            var demo = SIPSettings()
            demo.domain = host
            demo.port = environment["BSK_DEMO_PORT"] ?? ""
            demo.username = environment["BSK_DEMO_USER"] ?? "alice"
            demo.reachableInBackground = true
            settings = demo
            password = environment["BSK_DEMO_PASSWORD"] ?? "secret"
            if let door = environment["BSK_DEMO_DOOR"] {
                doors = [Door(name: "Front door", address: door, code: environment["BSK_DEMO_DOOR_CODE"] ?? "1234")]
                if let contact = environment["BSK_DEMO_CONTACT"] {
                    contacts = [Contact(name: environment["BSK_DEMO_CONTACT_NAME"] ?? "", address: contact)]
                }
                return
            }
            doors = [
                Door(name: "Front door", address: "sip:bob@\(host):5070", code: "1234"),
                Door(name: "Garage gate", address: "sip:gate@\(host)", code: "4711", hasCamera: false),
            ]
            contacts = [
                Contact(name: "Reception", address: "reception"),
                Contact(name: "Caretaker", address: "caretaker"),
            ]
            let now = Date()
            let front = "sip:bob@\(host):5070"
            history = [
                CallRecord(demoURI: front, name: "Front door", outgoing: false,
                           startedAt: now.addingTimeInterval(-600)),
                CallRecord(demoURI: "sip:gate@\(host)", name: "gate", outgoing: true,
                           startedAt: now.addingTimeInterval(-2400), duration: 6, dtmf: "4711", dtmfResult: "sent"),
                CallRecord(demoURI: front, name: "Front door", outgoing: false,
                           startedAt: now.addingTimeInterval(-3600), duration: 18, dtmf: "1234", dtmfResult: "sent"),
                CallRecord(demoURI: "sip:reception@\(host)", name: "Reception", outgoing: true, video: true,
                           startedAt: now.addingTimeInterval(-90000), duration: 130),
            ]
            let reception = "sip:reception@\(host)"
            messages = [
                ChatMessage(id: UUID(), messageID: nil, peer: reception,
                            text: "Good morning. A parcel is waiting for you at the desk.", outgoing: false,
                            status: .received, date: now.addingTimeInterval(-1500)),
                ChatMessage(id: UUID(), messageID: nil, peer: reception,
                            text: "Thank you. I will pick it up after six.", outgoing: true, status: .delivered,
                            date: now.addingTimeInterval(-1400)),
                ChatMessage(id: UUID(), messageID: nil, peer: reception, text: "The desk closes at eight today.",
                            outgoing: false, status: .received, date: now.addingTimeInterval(-1300)),
                ChatMessage(id: UUID(), messageID: nil, peer: reception, text: "He should be there in ten minutes.",
                            outgoing: true, status: .failed("408 Request Timeout"),
                            date: now.addingTimeInterval(-1200)),
            ]
        }
    }

    extension CallRecord {
        init(demoURI uri: String, name: String, outgoing: Bool, video: Bool = false, startedAt: Date,
             duration: TimeInterval? = nil, dtmf: String = "", dtmfResult: String? = nil) {
            self.uri = uri
            self.name = name
            self.outgoing = outgoing
            self.video = video
            self.startedAt = startedAt
            self.duration = duration
            self.dtmf = dtmf
            self.dtmfResult = dtmfResult
            dtmfHangUp = true
        }
    }
#endif
