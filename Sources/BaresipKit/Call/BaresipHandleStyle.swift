/// How a system call interface adapter, for CallKit or LiveCommunicationKit, identifies the other
/// side of a call to the system.
public enum BaresipHandleStyle: Sendable, Equatable {
    /// Every caller is a generic handle with the SIP URI.
    case sipURI
    /// A caller whose user part is a phone number, such as `100` or `+15555550100`, is reported
    /// as that number, so iOS shows the name and the photo of a contact with it and Recents
    /// lists a number. Other callers stay generic handles with the SIP URI.
    case phoneNumberWhenNumeric
}
