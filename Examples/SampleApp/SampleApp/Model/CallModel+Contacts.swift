import Foundation

/// The contacts the user saved on the keypad.
extension CallModel {
    func save(_ contact: Contact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
        } else {
            contacts.append(contact)
        }
    }

    func remove(_ contact: Contact) {
        contacts.removeAll { $0.id == contact.id }
    }

    func call(_ contact: Contact, video: Bool) async {
        destination = contact.address.trimmed
        await call(video: video)
    }
}
