//
//  MyBuffer.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/26.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import Foundation

public struct MyBuffer {
    
    private var buffer: NSMutableData?
    private var capacity: Int
    private var readIndex = 0
    private var writeIndex = 0

    public init(count: Int) {
        capacity = count
        self.resetAll()
    }
    
    mutating func resetAll() {
        buffer = NSMutableData(capacity: self.capacity)
        writeIndex = 0
        readIndex = 0
    }
    
    public mutating func write(_ data: NSData) {
        defer {
            writeIndex += data.length
        }
        buffer?.append(data as Data)
    }

    public mutating func read(length: Int) -> NSData {
        defer {
            readIndex += length
        }
        let dest = UnsafeMutableRawPointer.allocate(byteCount: length, alignment: 0)
        defer {
            dest.deallocate()
        }
      
        buffer?.getBytes(dest, range: NSRange(location: readIndex, length: length))
         
        return NSData(bytes: dest, length: length)
    }
    
    
    public func isAvailableDataForReading(count: Int) -> Bool {
        if readIndex + count < capacity, readIndex + count <= writeIndex {
            return true
        }
        return false
    }
}
