//
//  FileDownloadOperation.swift
//  Rebekka
//
//  Created by Constantine Fry on 25/05/15.
//  Copyright (c) 2015 Constantine Fry. All rights reserved.
//

import Foundation

/** Operation for downloading a file from FTP server. */
internal class FileDownloadOperation: ReadStreamOperation {
    
    fileprivate var fileHandle: FileHandle?
    var fileURL: URL?
    
    var downloadedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    
    
    override func start() {
        let filePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
        self.fileURL = URL(fileURLWithPath: filePath)
        do {
            try Data().write(to: self.fileURL!, options: NSData.WritingOptions.atomic)
            self.fileHandle = try FileHandle(forWritingTo: self.fileURL!)
            self.startOperationWithStream(self.readStream)
        } catch let error as NSError {
            self.error = error
            self.finishOperation()
        }
    }
    
    override func streamEventEnd(_ aStream: Stream) -> (Bool, NSError?) {
        self.fileHandle?.closeFile()
        return (true, nil)
    }
    
    override func streamEventError(_ aStream: Stream) {
        super.streamEventError(aStream)
        self.fileHandle?.closeFile()
        if self.fileURL != nil {
            do {
                try FileManager.default.removeItem(at: self.fileURL!)
            } catch _ {
            }
        }
        self.fileURL = nil
    }
    
    override func streamEventHasBytes(_ aStream: Stream) -> (Bool, NSError?) {
        if let inputStream = aStream as? InputStream {
            var parsetBytes: Int = 0
            repeat {
                parsetBytes = inputStream.read(self.temporaryBuffer, maxLength: 1024)
                if parsetBytes > 0 {
                    autoreleasepool {
                        //autoreleasepool is aimed for Obj-C object
                        //not sure if it is needed here
                        let data = Data(bytes: UnsafePointer<UInt8>(self.temporaryBuffer), count: parsetBytes)
                        self.fileHandle!.write(data)
                        downloadedBytes += Int64(parsetBytes)
                        progressHandler?(downloadedBytes,totalBytes)
                    }
                }
            } while (parsetBytes > 0)
        }
        return (true, nil)
    }
}
