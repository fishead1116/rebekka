//
//  RebekkaTests.swift
//  RebekkaTests
//
//  Created by Li Yun Jung on 2017/6/2.
//  Copyright © 2017年 Constantine Fry. All rights reserved.
//

import XCTest
import RebekkaTouch

class RebekkaTests: XCTestCase {
    
    var session: Session!
    
    override func setUp() {
        super.setUp()
        var configuration = SessionConfiguration()
        configuration.host = "ftp://speedtest.tele2.net"
        self.session = Session(configuration: configuration)        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testList() {
        
        let expectation = self.expectation(description: "test list")
        
        self.session.list("/") {
            (resources, error) -> Void in
            print("List directory with result:\n\(resources), error: \(error)\n\n")
            XCTAssert(error == nil)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 5.0, handler: nil)
        
    }
    
    func testFileInfo() {
        
        let expectation = self.expectation(description: "test file info")
        
        self.session.fileInfo("/1MB.zip", completionHandler: { (resource :ResourceItem?,error: Error?) -> (Void) in
            print("File Info:\n\(resource), error: \(error)\n\n")
            
            XCTAssert(error == nil)
            expectation.fulfill()
        })
        
        self.waitForExpectations(timeout: 5.0, handler: nil)
        
    }
    
    func testDownload() {
        
        self.measure {
            // test 10 time and get average and standarad deviation
            
            let expectation = self.expectation(description: "test download")
            
            self.session.download("/1MB.zip", progressHandler: { (progress) in
                print("Progress: \(progress)");
                
            }) {
                (fileURL, error) -> Void in
                print("Download file with result:\n\(fileURL), error: \(error)\n\n")
                
                XCTAssert(error == nil)
                
                if let fileURL = fileURL {
                    do {
                        try FileManager.default.removeItem(at: fileURL)
                        
                        

                    } catch let error as NSError {
                        print("Error: \(error)")
    
                    }
                    
                }
                
                expectation.fulfill()
            }
            
            
            self.waitForExpectations(timeout: 30.0, handler: nil)
            
        }
    }
    //testUpload()
    //testCreate()
    
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
