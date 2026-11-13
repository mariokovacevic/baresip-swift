#if os(iOS)
    import Intents
    import XCTest
    @testable import BaresipKit

    final class RedialRequestTests: XCTestCase {
        private func startCall(to value: String?, capability: INCallCapability) -> INStartCallIntent {
            let contacts = value.map { value in
                [
                    INPerson(personHandle: INPersonHandle(value: value, type: .unknown), nameComponents: nil,
                             displayName: nil, image: nil, contactIdentifier: nil, customIdentifier: nil),
                ]
            }
            return INStartCallIntent(callRecordFilter: nil, callRecordToCallBack: nil, audioRoute: .unknown,
                                     destinationType: .normal, contacts: contacts, callCapability: capability)
        }

        func testAStartCallIntentNamesTheDestination() {
            let audio = BaresipRedialRequest(intent: startCall(to: "sip:door1@pbx.example.com",
                                                               capability: .audioCall))
            let video = BaresipRedialRequest(intent: startCall(to: "100", capability: .videoCall))

            XCTAssertEqual(audio, BaresipRedialRequest(destination: "sip:door1@pbx.example.com", video: false))
            XCTAssertEqual(video, BaresipRedialRequest(destination: "100", video: true))
        }

        func testARequestNeedsSomeoneToCall() {
            XCTAssertNil(BaresipRedialRequest(intent: startCall(to: nil, capability: .audioCall)))
            XCTAssertNil(BaresipRedialRequest(intent: startCall(to: "", capability: .audioCall)))
            XCTAssertNil(BaresipRedialRequest(intent: INIntent()))
        }

        func testAnActivityWithoutAnIntentIsNoRequest() {
            let activity = NSUserActivity(activityType: BaresipRedialRequest.activityType)

            XCTAssertNil(BaresipRedialRequest(activity: activity))
        }
    }
#endif
