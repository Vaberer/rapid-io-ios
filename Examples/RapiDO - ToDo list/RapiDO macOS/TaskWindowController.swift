//
//  TaskWindowController.swift
//  RapiDO
//
//  Created by Jan on 16/05/2017.
//  Copyright © 2017 Rapid.io. All rights reserved.
//

import Cocoa

class TaskWindowController: NSWindowController, NSWindowDelegate {

    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.delegate = self
    }
    
    func windowShouldClose(_ sender: Any) -> Bool {
        if let window = window {
            AppDelegate.windowClosed(window)
        }
        return true
    }
}
