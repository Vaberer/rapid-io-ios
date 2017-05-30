//
//  RapidUpdate.swift
//  Rapid
//
//  Created by Jan Schwarz on 22/03/2017.
//  Copyright © 2017 Rapid.io. All rights reserved.
//

import Foundation

/// Wrapper for subscription events that came in one batch
class RapidSubscriptionBatch: RapidServerEvent {
    
    internal var eventIDsToAcknowledge: [String]
    let subscriptionID: String
    let collectionID: String
    
    internal(set) var collection: [RapidDocumentSnapshot]?
    internal(set) var updates: [RapidDocumentSnapshot]
    
    init(withSubscriptionID id: String, collection: [RapidDocumentSnapshot]) {
        self.eventIDsToAcknowledge = [Rapid.uniqueID]
        self.subscriptionID = id
        self.collectionID = collection.first?.collectionID ?? ""
        self.collection = collection
        self.updates = []
    }
    
    init?(withCollectionJSON dict: [AnyHashable: Any]) {
        guard let eventID = dict[RapidSerialization.EventID.name] as? String else {
            return nil
        }
        
        guard let subscriptionID = dict[RapidSerialization.SubscriptionValue.SubscriptionID.name] as? String else {
            return nil
        }
        
        guard let collectionID = dict[RapidSerialization.SubscriptionValue.CollectionID.name] as? String else {
            return nil
        }
        
        guard let documents = dict[RapidSerialization.SubscriptionValue.Documents.name] as? [Any] else {
            return nil
        }
        
        self.eventIDsToAcknowledge = [eventID]
        self.subscriptionID = subscriptionID
        self.collectionID = collectionID
        self.collection = documents.flatMap({ RapidDocumentSnapshot(existingDocJson: $0, collectionID: collectionID) })
        self.updates = []
    }
    
    init?(withUpdateJSON dict: [AnyHashable: Any], docRemoved: Bool) {
        guard let eventID = dict[RapidSerialization.EventID.name] as? String else {
            return nil
        }
        
        guard let subscriptionID = dict[RapidSerialization.SubscriptionUpdate.SubscriptionID.name] as? String else {
            return nil
        }
        
        guard let collectionID = dict[RapidSerialization.SubscriptionUpdate.CollectionID.name] as? String else {
            return nil
        }
        
        guard let document = dict[RapidSerialization.SubscriptionUpdate.Document.name] as? [AnyHashable: Any] else {
            return nil
        }
        
        let snapshot: RapidDocumentSnapshot?
        if docRemoved {
            snapshot = RapidDocumentSnapshot(removedDocJson: document, collectionID: collectionID)
        }
        else {
            snapshot = RapidDocumentSnapshot(existingDocJson: document, collectionID: collectionID)
        }
        
        guard let snap = snapshot else {
            return nil
        }
        
        self.eventIDsToAcknowledge = [eventID]
        self.subscriptionID = subscriptionID
        self.collectionID = collectionID
        self.collection = nil
        self.updates = [snap]
    }

    /// Add subscription event to the batch
    ///
    /// - Parameter initialValue: Subscription dataset object
    func merge(event: RapidSubscriptionBatch) {
        eventIDsToAcknowledge.append(contentsOf: event.eventIDsToAcknowledge)
        
        // Since initial value contains whole dataset it overrides all previous single updates
        if let collection = event.collection {
            self.collection = collection
            self.updates = event.updates
        }
        else {
            self.updates.append(contentsOf: event.updates)
        }
    }
    
}

class RapidFetchResponse: RapidServerEvent {
    
    let eventIDsToAcknowledge: [String]
    
    let fetchID: String
    
    let collectionID: String
    
    let documents: [RapidDocumentSnapshot]
    
    init?(withJSON json: [AnyHashable: Any]) {
        guard let eventID = json[RapidSerialization.EventID.name] as? String else {
            return nil
        }
        
        guard let fetchID = json[RapidSerialization.FetchValue.FetchID.name] as? String else {
            return nil
        }
        
        guard let collectionID = json[RapidSerialization.FetchValue.CollectionID.name] as? String else {
            return nil
        }
        
        guard let documents = json[RapidSerialization.FetchValue.Documents.name] as? [Any] else {
            return nil
        }
        
        self.eventIDsToAcknowledge = [eventID]
        self.fetchID = fetchID
        self.collectionID = collectionID
        self.documents = documents.flatMap({ RapidDocumentSnapshot(existingDocJson: $0, collectionID: collectionID) })
    }
    
}
