//
//  Session.swift
//  Rebekka
//
//  Created by Constantine Fry on 17/05/15.
//  Copyright (c) 2015 Constantine Fry. All rights reserved.
//

import Foundation

/** The FTP session. */
open class Session {
    /** The serial private operation queue. */
    fileprivate let operationQueue: OperationQueue
    
    /** The queue for completion handlers. */
    fileprivate let completionHandlerQueue: OperationQueue
    
    /** The serial queue for streams in operations. */
    fileprivate let streamQueue: DispatchQueue
    
    /** The configuration of the session. */
    fileprivate let configuration: SessionConfiguration
    
    public init(configuration: SessionConfiguration,
        completionHandlerQueue: OperationQueue = OperationQueue.main) {
            self.operationQueue = OperationQueue()
            self.operationQueue.maxConcurrentOperationCount = 1
            self.operationQueue.name = "net.ftp.rebekka.operations.queue"
            self.streamQueue = DispatchQueue(label: "net.ftp.rebekka.cfstream.queue", attributes: [])
            self.completionHandlerQueue = completionHandlerQueue
            self.configuration = configuration
    }
    
    /** Returns content of directory at path. */
    open func list(_ path: String, completionHandler: @escaping ResourceResultCompletionHandler) {
        let operation = ResourceListOperation(configuration: configuration, queue: self.streamQueue)
        operation.completionBlock = {
            [weak operation] in
            if let strongOperation = operation {
                self.completionHandlerQueue.addOperation {
                    completionHandler(strongOperation.resources, strongOperation.error)
                }
            }
        }
        operation.path = path
        if !path.hasSuffix("/") {
            operation.path = operation.path! + "/"
        }
        self.operationQueue.addOperation(operation)
    }
    
    open func fileInfo(_ path: String, completionHandler: @escaping FileInfoCompletionHandler) {
        
        let words = path.components(separatedBy: "/")
        var folder = ""
        var fileName = ""
        if( words.count > 1 ){
            
            for word in words[ 0..<words.count-1]{
                folder.append(word)
                folder.append("/")
            }
            fileName = words[words.count-1]
        }else{
            folder = "/"
            fileName = path
        }
        
        list(folder) { (items : [ResourceItem]?,error: Error?) in
            guard error == nil else{
                completionHandler(nil,error)
                return
            }
            guard items != nil else{
                completionHandler(nil,nil)
                return
            }
            for item in items!{
                if(item.name == fileName){
                    completionHandler(item,nil)
                    return
                }
            }
            completionHandler(nil,nil)
        }
    
    }
    /** Creates new directory at path. */
    open func createDirectory(_ path: String, completionHandler: @escaping BooleanResultCompletionHandler) {
        let operation = DirectoryCreationOperation(configuration: configuration, queue: self.streamQueue)
        operation.completionBlock = {
            [weak operation] in
            if let strongOperation = operation {
                self.completionHandlerQueue.addOperation {
                    completionHandler(strongOperation.error == nil, strongOperation.error)
                }
            }
        }
        operation.path = path
        if !path.hasSuffix("/") {
            operation.path = operation.path! + "/"
        }
        self.operationQueue.addOperation(operation)
    }
    
    /** 
    Downloads file at path from FTP server.
    File is stored in /tmp directory. Caller is responsible for deleting this file. */
    open func download(_ path: String, progressHandler:  @escaping FileTransferProgressHandler,completionHandler: @escaping FileURLResultCompletionHandler) {
        
        if path.isEmpty {
            return
        }
    
        self.fileInfo(path, completionHandler: { (resource :ResourceItem?,error: Error?) -> (Void) in
            guard  resource != nil else{
                return
            }
            
            let operation = FileDownloadOperation(configuration: self.configuration, queue: self.streamQueue)

            operation.totalBytes =  resource!.size
            
            operation.completionBlock = {
                [weak operation] in
                if let strongOperation = operation {
                    self.completionHandlerQueue.addOperation {
                        completionHandler(strongOperation.fileURL, strongOperation.error)
                    }
                }
            }
            
            operation.progressHandler = {
                (downloaded : Int64, total : Int64) in
                self.completionHandlerQueue.addOperation {
                    progressHandler(downloaded,total)
                }

            }
            
            operation.path = path
            self.operationQueue.addOperation(operation)
        })
    }
    
    /** Uploads file from fileURL at path. */
    open func upload(_ fileURL: URL, path: String,progressHandler:  @escaping FileTransferProgressHandler, completionHandler: @escaping BooleanResultCompletionHandler) {
        
        var fileSize : UInt64 = 0
        do{
        let attr = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        
        fileSize =  attr[FileAttributeKey.size] as! UInt64
        
        }catch let e {
            completionHandler(false,e)
            return
        }
        
        let operation = FileUploadOperation(configuration: configuration, queue: self.streamQueue)
        operation.totalBytes = Int64(fileSize)
        operation.completionBlock = {
            [weak operation] in
            if let strongOperation = operation {
                self.completionHandlerQueue.addOperation {
                    completionHandler(strongOperation.error == nil, strongOperation.error)
                }
            }
        }
        operation.progressHandler = {
            (downloaded : Int64, total : Int64) in
            self.completionHandlerQueue.addOperation {
                progressHandler(downloaded,total)
            }
            
        }

        operation.path = path
        operation.fileURL = fileURL
        self.operationQueue.addOperation(operation)
    }
}
public typealias ResourceResultCompletionHandler = ([ResourceItem]?, Error?) -> Void

public typealias FileInfoCompletionHandler = (ResourceItem?, Error?) -> (Void)

public typealias FileURLResultCompletionHandler = (URL?, Error?) -> Void
public typealias BooleanResultCompletionHandler = (Bool, Error?) -> Void

public typealias FileTransferProgressHandler = (Int64,Int64) -> (Void)

public let kFTPAnonymousUser = "anonymous"

/** The session configuration. */
public struct SessionConfiguration {
    /**
    The host of FTP server. Defaults to `localhost`.
    Can be like this: 
        ftp://192.168.0.1
        127.0.0.1:21
        localhost
        ftp.mozilla.org
        ftp://ftp.mozilla.org:21
    */
    public var host: String = "localhost"
    
    /* Whether connection should be passive or not. Defaults to `true`. */
    public var passive = true
    
    /** The encoding of resource names. */
    public var encoding = String.Encoding.utf8
    
    /** The username for authorization. Defaults to `anonymous` */
    public var username = kFTPAnonymousUser
    
    /** The password for authorization. Can be empty. */
    public var password = ""
    
    public init() { }
    
    internal func URL() -> Foundation.URL {
        var stringURL = host
        if !stringURL.hasPrefix("ftp://") {
            stringURL = "ftp://\(host)/"
        }
        let url = Foundation.URL(string: stringURL)
        return url!
    }
}

/** Not secure storage for Servers information. Information is storedin plist file in Cache directory.*/
private class SessionConfigurationStorage {
    
    /** The URL to plist file. */
    fileprivate let storageURL: URL!
    
    init() {
        storageURL = URL(fileURLWithPath: "")
    }
    
    /** Returns an array of all stored servers. */
    fileprivate func allServers() {
        
    }
    
    /** Stores server. */
    fileprivate func storeServer() {
        
    }
    
    /** Deletes server. */
    fileprivate func deleteServer() {
        
    }
    
}

/** Stores credentials in Keychain. */
private class CredentialsStorage {
    
}
