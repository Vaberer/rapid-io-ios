//
//  RapidConnectionRequests.swift
//  Rapid
//
//  Created by Jan on 28/03/2017.
//  Copyright © 2017 Rapid.io. All rights reserved.
//

import Foundation

// MARK: Connect

/// Delegate for informing about connection request result
protocol RapidConnectionRequestDelegate: class {
    func connectionEstablished(_ request: RapidConnectionRequest)
    func connectingFailed(_ request: RapidConnectionRequest, error: RapidErrorInstance)
}

/// Connection request
class RapidConnectionRequest: RapidSerializable {
    
    /// Request should timeout even if `Rapid.timeout` is `nil`
    let alwaysTimeout = true
    
    /// ID associated with an abstract connection
    let connectionID: String
    
    /// Connection result delegate
    internal weak var delegate: RapidConnectionRequestDelegate?
    
    /// Timout delegate
    internal weak var timoutDelegate: RapidTimeoutRequestDelegate?
    
    internal var timer: Timer?
    
    init(connectionID: String, delegate: RapidConnectionRequestDelegate) {
        self.connectionID = connectionID
        self.delegate = delegate
    }
    
    // MARK: Rapid serializable
    func serialize(withIdentifiers identifiers: [AnyHashable : Any]) throws -> String {
        return try RapidSerialization.serialize(connection: self, withIdentifiers: identifiers)
    }
    
}

extension RapidConnectionRequest: RapidPriorityRequest {
    
    var priority: RapidRequestPriority {
        return .high
    }
}

extension RapidConnectionRequest: RapidTimeoutRequest {
    
    func requestSent(withTimeout timeout: TimeInterval, delegate: RapidTimeoutRequestDelegate) {
        // Start timeout
        self.timoutDelegate = delegate
        
        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                self?.timer = Timer.scheduledTimer(timeInterval: timeout, target: strongSelf, selector: #selector(strongSelf.requestTimeout), userInfo: nil, repeats: false)
            }
        }
    }
    
    @objc func requestTimeout() {
        timer = nil
        
        timoutDelegate?.requestTimeout(self)
    }
    
    func invalidateTimer() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    func eventAcknowledged(_ acknowledgement: RapidSocketAcknowledgement) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            
            self.delegate?.connectionEstablished(self)
        }
    }
    
    func eventFailed(withError error: RapidErrorInstance) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            
            self.delegate?.connectingFailed(self, error: error)
        }
    }

}

/// Reconnection request
class RapidReconnectionRequest: RapidConnectionRequest {
    
    override func serialize(withIdentifiers identifiers: [AnyHashable : Any]) throws -> String {
        return try RapidSerialization.serialize(reconnection: self, withIdentifiers: identifiers)
    }
    
}

// MARK: Disconnect

/// Disconnection request
class RapidDisconnectionRequest: RapidSerializable, RapidClientEvent {
    
    func serialize(withIdentifiers identifiers: [AnyHashable : Any]) throws -> String {
        return try RapidSerialization.serialize(disconnection: self)
    }
}

// MARK: No operation

/// Empty request for connection test
class RapidEmptyRequest: RapidSerializable, RapidClientEvent {
    
    func serialize(withIdentifiers identifiers: [AnyHashable : Any]) throws -> String {
        return try RapidSerialization.serialize(emptyRequest: self)
    }
}

// MARK: Authorization

class RapidAuthRequest: RapidTimeoutRequest {
    
    /// Request should timeout even if `Rapid.timeout` is `nil`
    let alwaysTimeout = true
    
    let auth: RapidAuthorization
    let callback: RapidAuthCallback?
    
    /// Timout delegate
    internal weak var timoutDelegate: RapidTimeoutRequestDelegate?
    
    internal var timer: Timer?
    
    init(accessToken: String, callback: RapidAuthCallback? = nil) {
        self.auth = RapidAuthorization(accessToken: accessToken)
        self.callback = callback
    }
    
    func requestSent(withTimeout timeout: TimeInterval, delegate: RapidTimeoutRequestDelegate) {
        // Start timeout
        self.timoutDelegate = delegate
        
        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                self?.timer = Timer.scheduledTimer(timeInterval: timeout, target: strongSelf, selector: #selector(strongSelf.requestTimeout), userInfo: nil, repeats: false)
            }
        }
    }
    
    @objc func requestTimeout() {
        timer = nil
        
        timoutDelegate?.requestTimeout(self)
    }
    
    func invalidateTimer() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    func eventAcknowledged(_ acknowledgement: RapidSocketAcknowledgement) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            
            RapidLogger.log(message: "Rapid authorized")
            
            self.callback?(true, nil)
        }
    }
    
    func eventFailed(withError error: RapidErrorInstance) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            
            RapidLogger.log(message: "Rapid authorization failed")
            
            self.callback?(false, error.error)
        }
    }
}

extension RapidAuthRequest: RapidPriorityRequest {
    
    var priority: RapidRequestPriority {
        return .medium
    }
}

extension RapidAuthRequest: RapidSerializable {
    
    func serialize(withIdentifiers identifiers: [AnyHashable : Any]) throws -> String {
        return try RapidSerialization.serialize(authRequest: self, withIdentifiers: identifiers)
    }
}

class RapidUnauthRequest: RapidTimeoutRequest {
    
    /// Request should timeout even if `Rapid.timeout` is `nil`
    let alwaysTimeout = true
    
    let callback: RapidAuthCallback?
    
    /// Timout delegate
    internal weak var timoutDelegate: RapidTimeoutRequestDelegate?
    
    internal var timer: Timer?
    
    init(callback: RapidAuthCallback?) {
        self.callback = callback
    }
    
    func requestSent(withTimeout timeout: TimeInterval, delegate: RapidTimeoutRequestDelegate) {
        // Start timeout
        self.timoutDelegate = delegate
        
        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                self?.timer = Timer.scheduledTimer(timeInterval: timeout, target: strongSelf, selector: #selector(strongSelf.requestTimeout), userInfo: nil, repeats: false)
            }
        }
    }
    
    @objc func requestTimeout() {
        timer = nil
        
        timoutDelegate?.requestTimeout(self)
    }
    
    func invalidateTimer() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    func eventAcknowledged(_ acknowledgement: RapidSocketAcknowledgement) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            
            RapidLogger.log(message: "Rapid unauthorized")
            
            self.callback?(true, nil)
        }
    }
    
    func eventFailed(withError error: RapidErrorInstance) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            
            RapidLogger.log(message: "Rapid unauthorization failed")
            
            self.callback?(false, error.error)
        }
    }
}

extension RapidUnauthRequest: RapidSerializable {
    
    func serialize(withIdentifiers identifiers: [AnyHashable : Any]) throws -> String {
        return try RapidSerialization.serialize(authRequest: self, withIdentifiers: identifiers)
    }
}
