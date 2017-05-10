//
//  Task.swift
//  ExampleApp
//
//  Created by Jan on 05/05/2017.
//  Copyright © 2017 Rapid.io. All rights reserved.
//

import Foundation
import Rapid

enum Priority: Int {
    case low
    case medium
    case high
    
    static let allValues: [Priority] = [.low, .medium, .high]
    
    var title: String {
        switch self {
        case .low:
            return "Low"
            
        case .medium:
            return "Medium"
            
        case .high:
            return "High"
        }
    }
}

enum Tag: String {
    case home
    case work
    case other
    
    static let allValues: [Tag] = [.home, .work, .other]
    
    var color: UIColor {
        switch self {
        case .home:
            return UIColor(red: 116/255.0, green: 204/255.0, blue: 244/255.0, alpha: 1)
            
        case .work:
        return UIColor(red: 237/255.0, green: 80/255.0, blue: 114/255.0, alpha: 1)
            
        case .other:
            return UIColor(red: 191/255.0, green: 245/255.0, blue: 171/255.0, alpha: 1)
        }
    }
    
    var title: String {
        switch self {
        case .home:
            return "Home"
            
        case .work:
            return "Work"
            
        case .other:
            return "Other"
        }
    }
}

struct Task {
    let taskID: String
    let title: String
    let description: String?
    let createdAt: Date
    let completed: Bool
    let priority: Priority
    let tags: [Tag]
    
    init?(withSnapshot snapshot: RapidDocumentSnapshot) {
        guard let dict = snapshot.value,
            let title = dict[Task.titleAttributeName] as? String,
            let isoString = dict[Task.createdAttributeName] as? String,
            let priority = dict[Task.priorityAttributeName] as? Int else {
                
            return nil
        }
        
        let tags = dict[Task.tagsAttributeName] as? [String] ?? []
        
        self.taskID = snapshot.id
        self.title = title
        self.description = dict[Task.descriptionAttributeName] as? String
        self.createdAt = Date.dateFromString(isoString)
        self.completed = dict[Task.completedAttributeName] as? Bool ?? false
        self.priority = Priority(rawValue: priority) ?? .low
        self.tags = tags.flatMap({ Tag(rawValue: $0) })
    }
}

extension Task {
    
    static let titleAttributeName = "title"
    static let descriptionAttributeName = "description"
    static let createdAttributeName = "createdAt"
    static let priorityAttributeName = "priority"
    static let tagsAttributeName = "tags"
    static let completedAttributeName = "done"

}

extension Date {

    var isoString: String {
        let formatter = DateFormatter()
        
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        return formatter.string(from: self)
    }
    
    static func dateFromString(_ str: String) -> Date {
        let formatter = DateFormatter()
        
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: str) {
            return date
        }
        else {
            return Date()
        }
    }
    
}
