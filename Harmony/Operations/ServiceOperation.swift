//
//  ServiceOperation.swift
//  Harmony
//
//  Created by Riley Testut on 3/6/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Roxas

class ServiceOperation<R, E: Error>: Operation<R, E>
{
    var ignoreAuthenticationErrors = false
    
    private let task: (@escaping (Result<R, E>) -> Void) -> Progress?
    
    private var retryDelay: TimeInterval = 1.0
    private var didAttemptReauthentication = false
    
    private var taskProgress: Progress?
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(coordinator: SyncCoordinator, task: @escaping (@escaping (Result<R, E>) -> Void) -> Progress?)
    {
        self.task = task
        
        super.init(coordinator: coordinator)
    }
    
    override func main()
    {
        super.main()
        
        self.performTask()
    }
}

private extension ServiceOperation
{
    func performTask()
    {
        self.taskProgress = self.task() { (result) in
            if let progress = self.taskProgress
            {
                // Ensure progress is completed.
                progress.completedUnitCount = progress.totalUnitCount
            }
            
            // We must append .self to our Error enum cases for pattern matching to work.
            // Otherwise, the compiler (incorrectly) defaults to using normal enum pattern matching
            // and won't call our custom pattern matching operator.
            // https://bugs.swift.org/browse/SR-1121
            
            do
            {
                _ = try result.get()
                
                self.result = result
                self.finish()
            }
            catch ServiceError.rateLimitExceeded.self
            {
                guard self.retryDelay < 60 else {
                    self.result = result
                    self.finish()
                    return
                }
                
                print("Retrying request after delay:", self.retryDelay)
                
                self.progress.completedUnitCount -= 1
                
                DispatchQueue.global().asyncAfter(deadline: .now() + self.retryDelay) {
                    self.retryDelay = self.retryDelay * 2
                    self.performTask()
                }
            }
            catch AuthenticationError.tokenExpired.self where !self.didAttemptReauthentication && !self.ignoreAuthenticationErrors
            {
                self.didAttemptReauthentication = true
                
                self.coordinator.authenticate() { (authResult) in
                    switch authResult
                    {
                    case .success:
                        self.performTask()
                        
                    case .failure:
                        // Set result to whatever the result was prior to reauthentication attempt.
                        self.result = result
                        self.finish()
                    }
                }
            }
            catch
            {
                self.result = result
                self.finish()
            }
        }
        
        if let progress = self.taskProgress
        {
            self.progress.addChild(progress, withPendingUnitCount: 1)
        }
    }
}
