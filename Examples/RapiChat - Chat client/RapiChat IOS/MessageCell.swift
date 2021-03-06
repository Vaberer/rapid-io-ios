//
//  MessageCell.swift
//  RapiChat
//
//  Created by Jan on 27/06/2017.
//  Copyright © 2017 Rapid.io. All rights reserved.
//

import UIKit

class MessageCell: UITableViewCell {

    @IBOutlet weak var senderLabel: UILabel! {
        didSet {
            senderLabel.font = UIFont.systemFont(ofSize: 15)
        }
    }
    @IBOutlet weak var timeLabel: UILabel! {
        didSet {
            timeLabel.font = UIFont.systemFont(ofSize: 13)
            timeLabel.textColor = .appText
        }
    }
    @IBOutlet weak var messageTextLabel: UILabel! {
        didSet {
            messageTextLabel.font = UIFont.systemFont(ofSize: 16)
            messageTextLabel.textColor = .appText
        }
    }
    
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        
        return formatter
    }()
    
    func updateDateFormatterStyleWithDate(_ date: Date) {
        if (date as NSDate).isToday() {
            dateFormatter.dateStyle = .none
            
            dateFormatter.timeStyle = .short
        }
        else {
            dateFormatter.dateStyle = .short
            
            dateFormatter.timeStyle = .short
        }
    }
    
    func configure(withMessage message: Message, myUsername: String) {
        senderLabel.textColor = message.sender == myUsername ? UIColor.appRed : .appBlue
        senderLabel.text = message.sender
        
        messageTextLabel.text = message.text
        
        updateDateFormatterStyleWithDate(message.sentDate)
        timeLabel.text = dateFormatter.string(from: message.sentDate)
    }
}
