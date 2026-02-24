import Foundation
import CryptoKit

enum EncryptionService {
    /// Encrypts data with AES-256-GCM.
    /// Returns combined representation: nonce (12 bytes) || ciphertext || tag (16 bytes).
    /// Compatible with Python `cryptography` library's AESGCM.
    static func encrypt(data: Data, using key: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    enum EncryptionError: Error {
        case sealFailed
    }
}
