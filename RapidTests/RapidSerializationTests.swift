//
//  RapidQueryTests.swift
//  Rapid
//
//  Created by Jan on 05/04/2017.
//  Copyright © 2017 Rapid.io. All rights reserved.
//

import XCTest
@testable import Rapid

extension RapidTests {
    
    func testJSONValidationInvalidValue() {
        let mut = RapidDocumentMutation(collectionID: testCollectionName, documentID: "1", value: ["name": self], callback: nil)
        
        XCTAssertThrowsError(try mut.serialize(withIdentifiers: [:]), "JSON validation")
    }
    
    func testJSONalidationInvalidKey() {
        let mut = RapidDocumentMutation(collectionID: testCollectionName, documentID: "1", value: [self: "a"], callback: nil)
        
        XCTAssertThrowsError(try mut.serialize(withIdentifiers: [:]), "JSON validation")
    }
    
    func testJSONValidationInvalidKeyPath() {
        let sub = RapidCollectionSub(
            collectionID: testCollectionName,
            filter: RapidFilter.equal(keyPath: "sender.hu.", value: "john123"),
            ordering: nil,
            paging: nil,
            callback: nil,
            callbackWithChanges: nil)
        
        XCTAssertThrowsError(try sub.serialize(withIdentifiers: [:]), "JSON validation")
    }
    
    func testJSONValidationValidParameters() {
        let sub1 = RapidCollectionSub(
            collectionID: testCollectionName,
            filter: RapidFilter.and([
                RapidFilter.or([
                    RapidFilter.equal(keyPath: "$sender", value: "john123"),
                    RapidFilter.greaterThanOrEqual(keyPath: "max_urgency", value: 1),
                    RapidFilter.lessThanOrEqual(keyPath: "min-priority", value: 2)
                    ]),
                RapidFilter.not(RapidFilter.isNull(keyPath: "receiver"))
                ]),
            ordering: [RapidOrdering(keyPath: "sentDate", ordering: .descending)],
            paging: RapidPaging(skip: 10, take: 50),
            callback: nil,
            callbackWithChanges: nil)
        
        let sub2 = RapidCollectionSub(
            collectionID: testCollectionName,
            filter: RapidFilter.equal(keyPath: "sender.hu", value: "john123"),
            ordering: nil,
            paging: nil,
            callback: nil,
            callbackWithChanges: nil)
        
        XCTAssertNoThrow(try sub1.serialize(withIdentifiers: [:]), "JSON validation")
        XCTAssertNoThrow(try sub2.serialize(withIdentifiers: [:]), "JSON validation")
    }
    
    func testEventBatch() {
        let subID = Rapid.uniqueID
        
        let batch: [AnyHashable: Any] = [
            "batch": [
                [
                    "ack": [
                        "evt-id": Rapid.uniqueID
                    ]
                ],
                [
                    "err": [
                        "evt-id": Rapid.uniqueID,
                        "err-type": "permission-denied",
                        "err-msg": "Test message"
                    ]
                ],
                [
                    "upd": [
                        "evt-id": Rapid.uniqueID,
                        "col-id": testCollectionName,
                        "sub-id": subID,
                        "doc":
                            [
                                "id": "1",
                                "etag": Rapid.uniqueID,
                                "body": [
                                    "name": "testy"
                                ]
                        ]
                    ]
                ],
                [
                    "val": [
                        "evt-id": Rapid.uniqueID,
                        "col-id": testCollectionName,
                        "sub-id": subID,
                        "docs": [
                            [
                                "id": "1",
                                "etag": Rapid.uniqueID,
                                "body": [
                                    "name": "test"
                                ]
                            ],
                            [
                                "id": "2",
                                "etag": Rapid.uniqueID,
                                "body": [
                                    "name": "test"
                                ]
                            ]
                        ]
                    ]
                ],
                [
                    "upd": [
                        "evt-id": Rapid.uniqueID,
                        "col-id": testCollectionName,
                        "sub-id": subID,
                        "doc":
                            [
                                "id": "1",
                                "etag": Rapid.uniqueID,
                                "body": [
                                    "name": "testy"
                                ]
                        ]
                    ]
                ],
                [
                    "upd": [
                        "evt-id": Rapid.uniqueID,
                        "col-id": testCollectionName,
                        "sub-id": subID,
                        "psib-id": "1",
                        "doc":
                            [
                                "id": "2",
                                "etag": Rapid.uniqueID,
                                "body": [
                                    "name": "testy"
                                ]
                        ]
                    ]
                ],
                [
                    "upd": [
                        "evt-id": Rapid.uniqueID,
                        "col-id": testCollectionName,
                        "sub-id": Rapid.uniqueID,
                        "psib-id": "1",
                        "doc":
                            [
                                "id": "2",
                                "etag": Rapid.uniqueID,
                                "body": [
                                    "name": "testy"
                                ]
                        ]
                    ]
                ]
            ]
        ]
        
        let responses = RapidSerialization.parse(json: batch) ?? []
        
        XCTAssertEqual(responses.count, 4, "Number of responses")
        
        if !(responses[0] is RapidSocketAcknowledgement) {
            XCTFail("Not an acknowledgement")
        }
        
        if let error = responses[1] as? RapidErrorInstance, case RapidError.permissionDenied(let message) = error.error {
            XCTAssertEqual(message, "Test message", "Error message")
        }
        else {
            XCTFail("Wrong error")
        }
        
        if let batch = responses[2] as? RapidSubscriptionBatch {
            XCTAssertEqual(batch.subscriptionID, subID, "Subscription batch")
            XCTAssertNotNil(batch.collection, "Subscription batch")
            XCTAssertEqual(batch.updates.count, 2, "Subscription batch")
        }
        else {
            XCTFail("Wrong response")
        }
        
        if let batch = responses[3] as? RapidSubscriptionBatch {
            XCTAssertNil(batch.collection, "Subscription batch")
            XCTAssertEqual(batch.updates.count, 1, "Subscription batch")
        }
        else {
            XCTFail("Wrong response")
        }
    }
    
    func testCollectionSubscription() {
        let subscription = RapidCollectionSub(collectionID: "users", filter: nil, ordering: nil, paging: nil, callback: nil, callbackWithChanges: nil)
        
        let json: [AnyHashable: Any] = [
            "sub": [
                "col-id": subscription.collectionID
            ]
        ]
        
        do {
            let comparison = try subscription.serialize(withIdentifiers: [:]).json() ?? [:]
            
            if !(comparison == json) {
                XCTFail("Subscription wrongly serialized")
            }
        }
        catch {
            XCTFail("Serialization failed")
        }
    }
    
    func testSubscriptionFilter() {
        let collection = self.rapid.collection(named: "users")
            .filter(by: RapidFilterSimple(keyPath: "text", relation: .equal, value: "texty text"))
        
        let sub = RapidCollectionSub(collectionID: collection.collectionID, filter: collection.subscriptionFilter, ordering: collection.subscriptionOrdering, paging: collection.subscriptionPaging, callback: nil, callbackWithChanges: nil)
        
        let json: [AnyHashable: Any] = [
            "sub": [
                "col-id": sub.collectionID,
                "filter": ["text": "texty text"]
            ]
        ]
        
        do {
            let comparison = try sub.serialize(withIdentifiers: [:]).json() ?? [:]
            
            if !(comparison == json) {
                XCTFail("Subscription wrongly serialized")
            }
        }
        catch {
            XCTFail("Serialization failed")
        }
    }
    
    func testSubscriptionOrdering() {
        let collection = self.rapid.collection(named: testCollectionName)
            .order(by: RapidOrdering(keyPath: "name", ordering: .ascending))
            .order(by: [RapidOrdering(keyPath: "second_nem", ordering: .descending)])
        
        let sub = RapidCollectionSub(collectionID: collection.collectionID, filter: collection.subscriptionFilter, ordering: collection.subscriptionOrdering, paging: collection.subscriptionPaging, callback: nil, callbackWithChanges: nil)
        
        let json: [AnyHashable: Any] = [
            "sub": [
                "col-id": sub.collectionID,
                "order": [
                    ["name": "asc"],
                    ["second_nem": "desc"]
                ]
            ]
        ]
        
        do {
            let comparison = try sub.serialize(withIdentifiers: [:]).json() ?? [:]
            
            if !(comparison == json) {
                XCTFail("Subscription wrongly serialized")
            }
        }
        catch {
            XCTFail("Serialization failed")
        }
    }
    
    func testSubscriptionComplexFilter() {
        let collection = self.rapid.collection(named: "users")
            .filter(by:
                RapidFilterCompound.and([
                    RapidFilterCompound.or([
                        RapidFilter.equal(keyPath: "sender", value: "john123"),
                        RapidFilterSimple.greaterThanOrEqual(keyPath: "urgency", value: 1),
                        RapidFilterSimple.lessThanOrEqual(keyPath: "priority", value: 2)
                        ]),
                    RapidFilter.not(RapidFilter.isNull(keyPath: "receiver"))
                    ]))
            .filter(by:
                RapidFilter.and([
                    RapidFilter.greaterThan(keyPath: "urgency", value: 2),
                    RapidFilter.lessThan(keyPath: "urgency", value: 4)
                ]))
            .order(by: [
                RapidOrdering(keyPath: "sentDate", ordering: .descending)
                ])
            .order(by:
                RapidOrdering(keyPath: "urgency", ordering: .ascending)
                )
            .limit(to: 50, skip: 10)
        
        let sub = RapidCollectionSub(collectionID: collection.collectionID, filter: collection.subscriptionFilter, ordering: collection.subscriptionOrdering, paging: collection.subscriptionPaging, callback: nil, callbackWithChanges: nil)
        
        let json: [AnyHashable: Any] = [
            "sub": [
                "col-id": sub.collectionID,
                "filter": [
                    "and": [
                        [
                            "and": [
                                [
                                    "or": [
                                        ["sender": "john123"],
                                        ["urgency": ["gte": 1]],
                                        ["priority": ["lte": 2]]
                                    ]
                                ],
                                [
                                    "not": ["receiver": NSNull()]
                                ]
                            ]
                        ],
                        [
                            "and": [
                                ["urgency": ["gt": 2]],
                                ["urgency": ["lt": 4]]
                            ]
                        ]
                    ]
                ],
                "order": [
                    ["sentDate": "desc"],
                    ["urgency": "asc"]
                ],
                "limit": 50,
                "skip": 10
            ]
        ]
        
        do {
            let comparison = try sub.serialize(withIdentifiers: [:]).json() ?? [:]
            
            if !(comparison == json) {
                XCTFail("Subscription wrongly serialized")
            }
        }
        catch {
            XCTFail("Serialization failed")
        }
    }
    
    func testWrongDocumentIDSubscription() {
        let promise = expectation(description: "Wrong document id")
        
        self.rapid.collection(named: testCollectionName).document(withID: "t e s t").subscribe { (error, _) in
            if let error = error as? RapidError,
                case .invalidData(let reason) = error,
                case .invalidIdentifierFormat(let idef) = reason, idef as? String == "t e s t" {
                promise.fulfill()
            }
            else {
                XCTFail("Subsription passed")
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testWrongDocumentIDMutation() {
        let promise = expectation(description: "Wrong document id")
        
        self.rapid.collection(named: testCollectionName).document(withID: "t e s t").mutate(value: ["name": "test"]) { error, _ in
            if let error = error as? RapidError,
                case .invalidData(let reason) = error,
                case .invalidIdentifierFormat(let idef) = reason, idef as? String == "t e s t" {
                promise.fulfill()
            }
            else {
                XCTFail("Subsription passed")
            }
        }
            
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testEmptyAndFilter() {
        let promise = expectation(description: "Empty compound filter")
        
        self.rapid.collection(named: testCollectionName).filter(by: RapidFilter.and([])).subscribe { (error, _) in
            if let error = error as? RapidError, case .invalidData = error {
                promise.fulfill()
            }
            else {
                XCTFail("Dictionary valid")
            }
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testEmptyOrFilter() {
        let promise = expectation(description: "Empty compound filter")
        
        self.rapid.collection(named: testCollectionName).filter(by: RapidFilter.or([])).subscribe { (error, _) in
            if let error = error as? RapidError, case .invalidData = error {
                promise.fulfill()
            }
            else {
                XCTFail("Dictionary valid")
            }
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testSubscriptionHashes() {
        let collection = self.rapid.collection(named: testCollectionName)
            .filter(by:
                RapidFilterCompound.and([
                    RapidFilterCompound.or([
                        RapidFilter.equal(keyPath: "sender", value: "john123"),
                        RapidFilter.greaterThanOrEqual(keyPath: "urgency", value: 1),
                        RapidFilter.lessThanOrEqual(keyPath: "priority", value: 2)
                        ]),
                    RapidFilter.not(RapidFilter.isNull(keyPath: "receiver"))
                    ]))
            .filter(by:
                RapidFilter.and([
                    RapidFilter.greaterThan(keyPath: "urgency", value: 2),
                    RapidFilter.lessThan(keyPath: "urgency", value: 4)
                    ]))
            .order(by: [
                RapidOrdering(keyPath: "sentDate", ordering: .descending)
                ])
            .order(by:
                RapidOrdering(keyPath: "urgency", ordering: .ascending)
            )
            .limit(to: 50, skip: 10)

        let sub = RapidCollectionSub(collectionID: collection.collectionID, filter: collection.subscriptionFilter, ordering: collection.subscriptionOrdering, paging: collection.subscriptionPaging, callback: nil, callbackWithChanges: nil)
        
        let hash = "\(testCollectionName)#and(and(urgency-lt-4|urgency-gt-2)|and(or(urgency-gte-1|sender-e-john123|priority-lte-2)|not(receiver-e-null)))#o-sentDate-d|o-urgency-a#t50s10"
        
        XCTAssertEqual(sub.subscriptionHash, hash)
    }
    
    func testSubscriptionHashComparison() {
        let collection1 = self.rapid.collection(named: testCollectionName)
            .filter(by:
                RapidFilterCompound.and([
                    RapidFilterCompound.or([
                        RapidFilter.equal(keyPath: "sender", value: "john123"),
                        RapidFilter.greaterThanOrEqual(keyPath: "urgency", value: 1),
                        RapidFilter.lessThanOrEqual(keyPath: "priority", value: 2)
                        ]),
                    RapidFilter.not(RapidFilter.isNull(keyPath: "receiver"))
                    ]))
            .filter(by:
                RapidFilter.and([
                    RapidFilter.greaterThan(keyPath: "urgency", value: 2),
                    RapidFilter.lessThan(keyPath: "urgency", value: 4)
                    ]))
        
        let collection2 = self.rapid.collection(named: testCollectionName)
            .filter(by:
                RapidFilter.and([
                    RapidFilter.lessThan(keyPath: "urgency", value: 4),
                    RapidFilter.greaterThan(keyPath: "urgency", value: 2)
                    ]))
            .filter(by:
                RapidFilterCompound.and([
                    RapidFilter.not(RapidFilter.isNull(keyPath: "receiver")),
                    RapidFilterCompound.or([
                        RapidFilter.greaterThanOrEqual(keyPath: "urgency", value: 1),
                        RapidFilter.equal(keyPath: "sender", value: "john123"),
                        RapidFilter.lessThanOrEqual(keyPath: "priority", value: 2)
                        ])
                    ]))
        
        let sub1 = RapidCollectionSub(collectionID: collection1.collectionID, filter: collection1.subscriptionFilter, ordering: collection1.subscriptionOrdering, paging: collection1.subscriptionPaging, callback: nil, callbackWithChanges: nil)
        
        let sub2 = RapidCollectionSub(collectionID: collection2.collectionID, filter: collection2.subscriptionFilter, ordering: collection2.subscriptionOrdering, paging: collection2.subscriptionPaging, callback: nil, callbackWithChanges: nil)
        
        XCTAssertEqual(sub1.subscriptionHash, sub2.subscriptionHash)

    }
    
    func testSubscriptionUpdateObject() {
        let update1 = RapidSubscriptionUpdate(withUpdateJSON: ["test"])
        let update2 = RapidSubscriptionUpdate(withUpdateJSON: [:])
        let update3 = RapidSubscriptionUpdate(withUpdateJSON: ["doc": [:]])
        
        XCTAssertNil(update1, "Object created")
        XCTAssertNil(update2, "Object created")
        XCTAssertNil(update3, "Object created")
    }
    
    func testSubscriptionBatchObjectForValue() {
        let update1 = RapidSubscriptionBatch(withCollectionJSON: ["test"])
        let update2 = RapidSubscriptionBatch(withCollectionJSON: [:])
        let update3 = RapidSubscriptionBatch(withCollectionJSON: ["evt-id": "kdsjghds"])
        let update4 = RapidSubscriptionBatch(withCollectionJSON: ["evt-id": "kdsjghds", "sub-id": "fjdslkfj"])
        
        XCTAssertNil(update1, "Object created")
        XCTAssertNil(update2, "Object created")
        XCTAssertNil(update3, "Object created")
        XCTAssertNil(update4, "Object created")
    }
    
    func testSubscriptionBatchObjectForUpdate() {
        let update1 = RapidSubscriptionBatch(withUpdateJSON: ["test"])
        let update2 = RapidSubscriptionBatch(withUpdateJSON: [:])
        let update3 = RapidSubscriptionBatch(withUpdateJSON: ["evt-id": "kdsjghds"])
        let update4 = RapidSubscriptionBatch(withUpdateJSON: ["evt-id": "kdsjghds", "sub-id": "fjdslkfj"])
        
        XCTAssertNil(update1, "Object created")
        XCTAssertNil(update2, "Object created")
        XCTAssertNil(update3, "Object created")
        XCTAssertNil(update4, "Object created")
    }
    
    func testSocketAcknowledgement() {
        let ack1 = RapidSocketAcknowledgement(json: ["test"])
        let ack2 = RapidSocketAcknowledgement(json: [:])
        
        XCTAssertNil(ack1, "Object created")
        XCTAssertNil(ack2, "Object created")
    }
}
