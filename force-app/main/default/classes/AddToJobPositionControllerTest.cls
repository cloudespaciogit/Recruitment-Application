@IsTest
private class AddToJobPositionControllerTest {
    
    @testSetup
    static void setupData() {
        
       
        
        Client__c client = Recruitment_TestDataFactory.createClient('Test Client', 'client@example.com');
        Project__c project = Recruitment_TestDataFactory.createProject('Test Project');
        
        Candidate__c cand = Recruitment_TestDataFactory.createCandidate('Test Candidate', 'candidate6@example.com');
        cand.Designation__c = 'Developer';
        cand.Skills__c = 'Apex, Java';
        
        Candidate__c cand1 = Recruitment_TestDataFactory.createCandidate('Test Candidate1', 'candidate7@example.com');
        Candidate__c cand2 = Recruitment_TestDataFactory.createCandidate('Test Candidate2', 'candidate8@example.com');
        
        insert new List<SObject>{ client, project, cand, cand1, cand2 };
            
            Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(client, project);
        job.Client__c = client.Id;
        job.Job_Title__c = 'Salesforce Developer';
        job.Skills_Required__c = 'Apex; Java';
        insert job;
        
        Interview__c inter = Recruitment_TestDataFactory.createInterview(cand, job);
        inter.Interview_Date__c = DateTime.now().addDays(1);
        inter.Interview_Mode__c = 'Online';
        insert inter;
    }
    
    
    @IsTest
    static void testSearchJobs() {
        Candidate__c c = [SELECT Id FROM Candidate__c LIMIT 1];
        
        Test.startTest();
        List<Job_Position__c> results =
            AddToJobPositionController.getJobPositions(c.Id, 'Salesforce');
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Search should return matched job positions');
    }
    
    
    @IsTest
    static void testWithoutSearch_NoCandidate() {
        Test.startTest();
        List<Job_Position__c> results =
            AddToJobPositionController.getJobPositions(null, null);
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return all available jobs');
    }
    
    
    @IsTest
    static void testSmartMatching() {
        Candidate__c cand = [
            SELECT Id FROM Candidate__c WHERE Designation__c = 'Developer' LIMIT 1
        ];
        
        Test.startTest();
        List<Job_Position__c> results =
            AddToJobPositionController.getJobPositions(cand.Id, null);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Matching jobs must be returned');
    }
    
    
    @IsTest
    static void testAddCandidateToJobs() {
        Candidate__c freeCand = [
            SELECT Id FROM Candidate__c WHERE Email__c = 'candidate7@example.com' LIMIT 1
        ];
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];
        
        List<Id> jobIds = new List<Id>{job.Id};
            
            Test.startTest();
        AddToJobPositionController.addCandidateToJobs(freeCand.Id, jobIds);
        Test.stopTest();
        
        Integer interviewCount = [
            SELECT COUNT() FROM Interview__c WHERE Candidate__c = :freeCand.Id
        ];
        System.assertEquals(1, interviewCount, 'Interview inserted successfully');
    }
    
    
    @IsTest
    static void testAddCandidateToJobs_NullValues() {
        Test.startTest();
        AddToJobPositionController.addCandidateToJobs(null, null);
        Test.stopTest();
        
        System.assert(true, 'Method should gracefully exit without error');
    }
    
    
    @IsTest
    static void testDuplicateAssignmentHandling() {
        
        Candidate__c assignedCand = [
            SELECT Id FROM Candidate__c 
            WHERE Email__c = 'candidate6@example.com' LIMIT 1
        ];
        
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];
        List<Id> jobIds = new List<Id>{ job.Id };
            
            Test.startTest();
        try {
            AddToJobPositionController.addCandidateToJobs(assignedCand.Id, jobIds);
            System.assert(false, 'Should throw AuraHandledException for duplicate');
        } catch (AuraHandledException ex) {
            
            
            String m = ex.getMessage().toLowerCase();
            System.assert(
                m.contains('candidate already assigned'),
                'Exception should mention Candidate already assigned | Actual: ' + ex.getMessage()
            );
        }
        
        Test.stopTest();
    }
    
    
    @IsTest
    static void testPartialDuplicateAssignment() {
        
        Candidate__c assignedCand = [
            SELECT Id FROM Candidate__c WHERE Email__c = 'candidate6@example.com' LIMIT 1
        ];
        
        Client__c client = [SELECT Id FROM Client__c LIMIT 1];
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        
        Job_Position__c newJob = Recruitment_TestDataFactory.createJobPosition(client, project);
        newJob.Job_Title__c = 'Junior Developer';
        insert newJob;
        
        Job_Position__c existingJob = [
            SELECT Id FROM Job_Position__c LIMIT 1
        ];
        
        List<Id> jobIds = new List<Id>{ existingJob.Id, newJob.Id };
            
            Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            AddToJobPositionController.addCandidateToJobs(assignedCand.Id, jobIds);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            
            
            String m = ex.getMessage().toLowerCase();
            System.assert(
                m.contains('some job positions were already assigned'),
                'Exception should mention partial assignment | Actual: ' + ex.getMessage()
            );
        }
        
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception must be thrown for partial duplicate case');
        
        Integer countNewInterview = [
            SELECT COUNT() 
            FROM Interview__c 
            WHERE Candidate__c = :assignedCand.Id 
            AND Job_Position__c = :newJob.Id
        ];
        System.assertEquals(1, countNewInterview, 'New job must be assigned successfully');
    }
}