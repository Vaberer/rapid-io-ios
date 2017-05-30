//
//  RapidDocument.swift
//  Rapid
//
//  Created by Jan Schwarz on 16/03/2017.
//  Copyright © 2017 Rapid.io. All rights reserved.
//

import Foundation

/// Document subscription callback which provides a client either with an error or with a document
public typealias RapidDocSubCallback = (_ error: Error?, _ value: RapidDocumentSnapshot) -> Void

/// Document fetch callback which provides a client either with an error or with a document
public typealias RapidDocFetchCallback = RapidDocSubCallback

/// Document mutation callback which informs a client about the operation result
public typealias RapidMutationCallback = (_ error: Error?) -> Void

/// Document mutation callback which informs a client about the operation result
public typealias RapidDeletionCallback = RapidMutationCallback

/// Document mutation callback which informs a client about the operation result
public typealias RapidMergeCallback = RapidMutationCallback

/// Block of code which is called on optimistic concurrency write
public typealias RapidConcurrencyOptimisticBlock = (_ currentValue: [AnyHashable: Any]?) -> RapidConOptResult

/// Optimistic concurrency write completion callback which informs a client about the operation result
public typealias RapidConcurrencyCompletionBlock = RapidMutationCallback

//FIXME: Better name

/// Return type for `RapidConcurrencyOptimisticBlock`
///
/// `RapidConOptResult` represents an action that should be performed based on a current value
/// that is provided as an input parameter of `RapidConcurrencyOptimisticBlock`
///
/// - write: Write new data
/// - delete: Delete document. This action is applicable only for optimistic concurrency delete
/// - abort: Abort process
public enum RapidConOptResult {
    case write(value: [AnyHashable: Any])
    case delete()
    case abort()
}

/// Compare two docuement snapshots
///
/// Compera ids, etags and dictionaries
///
/// - Parameters:
///   - lhs: Left operand
///   - rhs: Right operand
/// - Returns: `true` if operands are equal
func == (lhs: RapidDocumentSnapshot, rhs: RapidDocumentSnapshot) -> Bool {
    if lhs.id == rhs.id && lhs.collectionID == rhs.collectionID && lhs.etag == rhs.etag {
        if let lValue = lhs.value, let rValue = rhs.value {
            return NSDictionary(dictionary: lValue).isEqual(to: rValue)
        }
        else if lhs.value == nil && rhs.value == nil {
            return true
        }
    }

    return false
}

/// Class representing Rapid.io document that is returned from a subscription callback
public class RapidDocumentSnapshot: NSObject, NSCoding, RapidCachableObject {
    
    var objectID: String {
        return id
    }
    
    var groupID: String {
        return collectionID
    }
    
    /// Document ID
    public let id: String
    
    /// Collection ID
    public let collectionID: String
    
    /// Document body
    public let value: [AnyHashable: Any]?
    
    /// Etag identifier
    public let etag: String?
    
    /// Time of a document creation
    public let createdAt: Date?
    
    /// Time of a document modification
    public let modifiedAt: Date?
    
    /// Document creation sort identifier
    let sortValue: String
    
    /// Value that serves to order documents
    ///
    /// Value is computed by Rapid.io database based on sort descriptors in a subscription
    let sortKeys: [String]
    
    init?(existingDocJson json: Any?, collectionID: String) {
        guard let dict = json as? [AnyHashable: Any] else {
            return nil
        }
        
        guard let id = dict[RapidSerialization.Document.DocumentID.name] as? String else {
            return nil
        }
        
        guard let etag = dict[RapidSerialization.Document.Etag.name] as? String else {
            return nil
        }
        
        guard let sortValue = dict[RapidSerialization.Document.SortValue.name] as? String else {
            return nil
        }
        
        guard let createdAt = dict[RapidSerialization.Document.CreatedAt.name] as? TimeInterval else {
            return nil
        }
        
        guard let modifiedAt = dict[RapidSerialization.Document.ModifiedAt.name] as? TimeInterval else {
            return nil
        }
        
        let body = dict[RapidSerialization.Document.Body.name] as? [AnyHashable: Any]
        let sortKeys = dict[RapidSerialization.Document.SortKeys.name] as? [String]
        
        self.id = id
        self.collectionID = collectionID
        self.value = body
        self.etag = etag
        self.createdAt = Date(timeIntervalSince1970: createdAt)
        self.modifiedAt = Date(timeIntervalSince1970: modifiedAt)
        self.sortKeys = sortKeys ?? []
        self.sortValue = sortValue
    }
    
    init?(removedDocJson json: Any?, collectionID: String) {
        guard let dict = json as? [AnyHashable: Any] else {
            return nil
        }
        
        guard let id = dict[RapidSerialization.Document.DocumentID.name] as? String else {
            return nil
        }
        
        let body = dict[RapidSerialization.Document.Body.name] as? [AnyHashable: Any]
        let sortKeys = dict[RapidSerialization.Document.SortKeys.name] as? [String]
        
        self.id = id
        self.collectionID = collectionID
        self.value = body
        self.etag = nil
        self.createdAt = nil
        self.modifiedAt = nil
        self.sortKeys = sortKeys ?? []
        self.sortValue = ""
    }
    
    init(removedDocId id: String, collectionID: String) {
        self.id = id
        self.collectionID = collectionID
        self.value = nil
        self.etag = nil
        self.createdAt = nil
        self.modifiedAt = nil
        self.sortKeys = []
        self.sortValue = ""
    }
    
    init?(snapshot: RapidDocumentSnapshot, newValue: [AnyHashable: Any]) {
        self.id = snapshot.id
        self.collectionID = snapshot.collectionID
        self.etag = snapshot.etag
        self.createdAt = snapshot.createdAt
        self.modifiedAt = snapshot.modifiedAt
        self.sortKeys = snapshot.sortKeys
        self.sortValue = snapshot.sortValue
        self.value = newValue
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard let id = aDecoder.decodeObject(forKey: "id") as? String else {
            return nil
        }
        
        guard let collectionID = aDecoder.decodeObject(forKey: "collectionID") as? String else {
            return nil
        }
        
        guard let sortKeys = aDecoder.decodeObject(forKey: "sortKeys") as? [String] else {
            return nil
        }
        
        guard let sortValue = aDecoder.decodeObject(forKey: "sortValue") as? String else {
            return nil
        }
        
        self.id = id
        self.collectionID = collectionID
        self.sortKeys = sortKeys
        self.sortValue = sortValue
        do {
            self.value = try (aDecoder.decodeObject(forKey: "value") as? String)?.json()
        }
        catch {
            self.value = nil
        }
        
        if let etag = aDecoder.decodeObject(forKey: "etag") as? String {
            self.etag = etag
        }
        else {
            self.etag = nil
        }
        
        if let createdAt = aDecoder.decodeObject(forKey: "createdAt") as? Date {
            self.createdAt = createdAt
        }
        else {
            self.createdAt = nil
        }
        
        if let modifiedAt = aDecoder.decodeObject(forKey: "modifiedAt") as? Date {
            self.modifiedAt = modifiedAt
        }
        else {
            self.modifiedAt = nil
        }
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: "id")
        aCoder.encode(collectionID, forKey: "collectionID")
        aCoder.encode(etag, forKey: "etag")
        aCoder.encode(sortKeys, forKey: "sortKeys")
        aCoder.encode(sortValue, forKey: "sortValue")
        aCoder.encode(createdAt, forKey: "createdAt")
        aCoder.encode(modifiedAt, forKey: "modifiedAt")
        do {
            aCoder.encode(try value?.jsonString(), forKey: "value")
        }
        catch {}
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        if let snapshot = object as? RapidDocumentSnapshot {
            return self == snapshot
        }

        return false
    }
    
    override public var description: String {
        return [
            "id": id,
            "etag": String(describing: etag),
            "collectionID": collectionID,
            "value": String(describing: value)
        ]
        .description
    }
}

/// Class representing Rapid.io document
public class RapidDocument: NSObject {
    
    fileprivate weak var handler: RapidHandler?
    fileprivate var socketManager: RapidSocketManager {
        return try! getSocketManager()
    }
    
    /// ID of a collection to which the document belongs
    public let collectionID: String
    
    /// Document ID
    public let documentID: String
    
    init(id: String, inCollection collectionID: String, handler: RapidHandler!) {
        self.documentID = id
        self.collectionID = collectionID
        self.handler = handler
    }
    
    /// Mutate the document
    ///
    /// All values in the document are replaced by values in the provided dictionary
    ///
    /// - Parameters:
    ///   - value: Dictionary with new values that the document should contain
    ///   - completion: Mutation callback which provides a client either with an error or with a successfully mutated object
    public func mutate(value: [AnyHashable: Any], completion: RapidMutationCallback? = nil) {
        let mutation = RapidDocumentMutation(collectionID: collectionID, documentID: documentID, value: value, cache: handler, callback: completion)
        socketManager.mutate(mutationRequest: mutation)
    }
    
    //FIXME: Better name
    public func concurrencySafeMutate(value: [AnyHashable: Any], etag: String?, completion: RapidMutationCallback? = nil) {
        let mutation = RapidDocumentMutation(collectionID: collectionID, documentID: documentID, value: value, cache: handler, callback: completion)
        mutation.etag = etag ?? Rapid.nilValue
        socketManager.mutate(mutationRequest: mutation)
    }
    
    public func concurrencySafeMutate(concurrencyBlock: @escaping RapidConcurrencyOptimisticBlock, completion: RapidConcurrencyCompletionBlock? = nil) {
        let concurrencyMutation = RapidConOptDocumentMutation(collectionID: collectionID, documentID: documentID, type: .mutate, delegate: socketManager, concurrencyBlock: concurrencyBlock, completion: completion)
        concurrencyMutation.cacheHandler = handler
        socketManager.concurrencyOptimisticMutate(mutation: concurrencyMutation)
    }
    
    /// Merge values in the document with new ones
    ///
    /// Values that are not mentioned in the provided dictionary remains as they are.
    /// Values that are mentioned in the provided dictionary are either replaced or added to the document.
    ///
    /// - Parameters:
    ///   - value: Dictionary with new values that should be merged into the document
    ///   - completion: merge callback which provides a client either with an error or with a successfully merged values
    public func merge(value: [AnyHashable: Any], completion: RapidMergeCallback? = nil) {
        let merge = RapidDocumentMerge(collectionID: collectionID, documentID: documentID, value: value, cache: handler, callback: completion)
        socketManager.mutate(mutationRequest: merge)
    }
    
    //FIXME: Better name
    public func concurrencySafeMerge(value: [AnyHashable: Any], etag: String?, completion: RapidMergeCallback? = nil) {
        let merge = RapidDocumentMerge(collectionID: collectionID, documentID: documentID, value: value, cache: handler, callback: completion)
        merge.etag = etag ?? Rapid.nilValue
        socketManager.mutate(mutationRequest: merge)
    }
    
    public func concurrencySafeMerge(concurrencyBlock: @escaping RapidConcurrencyOptimisticBlock, completion: RapidConcurrencyCompletionBlock? = nil) {
        let concurrencyMutation = RapidConOptDocumentMutation(collectionID: collectionID, documentID: documentID, type: .merge, delegate: socketManager, concurrencyBlock: concurrencyBlock, completion: completion)
        concurrencyMutation.cacheHandler = handler
        socketManager.concurrencyOptimisticMutate(mutation: concurrencyMutation)
    }
    
    /// Delete the document
    ///
    /// `Delete` is equivalent to `Mutate` with a value equal to `nil`
    ///
    /// - Parameter completion: Delete callback which provides a client either with an error or with the document object how it looked before it was deleted
    public func delete(completion: RapidDeletionCallback? = nil) {
        let deletion = RapidDocumentDelete(collectionID: collectionID, documentID: documentID, cache: handler, callback: completion)
        socketManager.mutate(mutationRequest: deletion)
    }
    
    //FIXME: Better name
    public func concurrencySafeDelete(etag: String, completion: RapidDeletionCallback? = nil) {
        let deletion = RapidDocumentDelete(collectionID: collectionID, documentID: documentID, cache: handler, callback: completion)
        deletion.etag = etag
        socketManager.mutate(mutationRequest: deletion)
    }
    
    public func concurrencySafeDelete(concurrencyBlock: @escaping RapidConcurrencyOptimisticBlock, completion: RapidConcurrencyCompletionBlock? = nil) {
        let concurrencyMutation = RapidConOptDocumentMutation(collectionID: collectionID, documentID: documentID, type: .delete, delegate: socketManager, concurrencyBlock: concurrencyBlock, completion: completion)
        concurrencyMutation.cacheHandler = handler
        socketManager.concurrencyOptimisticMutate(mutation: concurrencyMutation)
    }
    
    /// Subscribe for listening to the document changes
    ///
    /// - Parameter completion: subscription callback which provides a client either with an error or with a document
    /// - Returns: Subscription object which can be used for unsubscribing
    @discardableResult
    public func subscribe(completion: @escaping RapidDocSubCallback) -> RapidSubscription {
        let subscription = RapidDocumentSub(collectionID: collectionID, documentID: documentID, callback: completion)
        
        socketManager.subscribe(subscription)
        
        return subscription
    }
    
    /// Fetch document
    ///
    /// - Parameter completion: Fetch callback which provides a client either with an error or with an array of documents
    public func readOnce(completion: @escaping RapidDocFetchCallback) {
        let fetch = RapidDocumentFetch(collectionID: collectionID, documentID: documentID, cache: handler, callback: completion)
        
        socketManager.fetch(fetch)
    }
    
}

extension RapidDocument {
    
    func getSocketManager() throws -> RapidSocketManager {
        if let manager = handler?.socketManager {
            return manager
        }

        RapidLogger.log(message: RapidInternalError.rapidInstanceNotInitialized.message, level: .critical)
        throw RapidInternalError.rapidInstanceNotInitialized
    }
}
