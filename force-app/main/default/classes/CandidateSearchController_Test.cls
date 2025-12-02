/**
* @description   Test class for CandidateSearchController.
*                Covers candidate search functionality based on skills, experience, salary, phone,
*                location, gender, notice period, and skill combinations.
*                Also tests job position retrieval and candidate-job assignment logic.
*
* @author        Yuvraj Singh
* @createdDate   2025-08-26
* @testCoverage  Ensures coverage of CandidateSearchController methods.
*/

@isTest
private class CandidateSearchController_Test {
    
    /**
* @description Creates test data for candidates, clients, and job positions.
*              This data is used by all test methods in this class.
*/
    @testSetup
    static void setupTestData() {
        
        Candidate__c cand1 = Recruitment_TestDataFactory.createCandidate('John Doe', 'johndoe@email.com');
        cand1.Skills__c = 'Salesforce, Apex, LWC';
        cand1.Gender__c = 'Male';
        cand1.Notice_Period__c = '1 Month';
        cand1.Current_CTC__c = 60000;
        cand1.Expected_CTC__c = 70000;
        cand1.Highest_Qualification__c = 'B.Tech';
        cand1.Institute_Name__c = 'Test College';
        cand1.Current_Location__c = 'Delhi';
        cand1.Phone__c = '1111111111';
        cand1.Total_Experience__c = 3;
        insert cand1;
        
        Candidate__c cand2 = Recruitment_TestDataFactory.createCandidate('Jane Smith', 'jane.smith@test.com');
        cand2.Skills__c = 'Java, SQL, Salesforce';
        cand2.Gender__c = 'Female';
        cand2.Notice_Period__c = 'Immediate';
        cand2.Can_join_in__c = 30;
        cand2.Total_Experience__c = 3;
        cand2.Current_Location__c = 'Delhi';
        cand2.Language_Known__c = 'Hindi, English';
        cand2.Current_CTC__c = 40000;
        cand2.Preferred_Location__c = 'Pune';
        
        insert cand2;
        
        Client__c client = Recruitment_TestDataFactory.createClient('Client Name', 'Client@email.com');
        client.Phone__c = '1111111111';
        insert client;
        
        Job_Position__c jp = Recruitment_TestDataFactory.createFlexJobPosition();
        jp.client__c = client.Id;
        insert jp;
        
       // Job_Position__c jp = Recruitment_TestDataFactory.createJobPosition(client, null);
       // insert jp;
        
        
    }
    
    
    /**
* @description - for searching candidates by only skills and experience.
*/
    @isTest
    static void testSearchCandidates_skillExperience() {
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.skillQuery = 'Salesforce';
        params.minExperience = 2;
        params.maxExperience = 5;
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals(2, results.size(), 'Expected Result Size');
    }
    
    /**
* @description - for searching candidates by only Current CTC.
*/
    @isTest
    static void testSearchCandidates_minMaxSalary(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.skillQuery = 'Salesforce';
        params.minSalary = 0;
        params.maxSalary = 1000000;
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals(2, results.size(), 'Expected Result Size');
    }
    /**
* @description - for searching candidates by only phone.
*/
    @isTest
    static void testSearchCandidates_phone(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.Phone = '1111111111';
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
    }
    
    
    /**
* @description - for searching candidates by only current location.
*/
    
    @isTest
    static void testSearchCandidates_currentLocation(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.currentLocation = 'Delhi';
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
        System.assertEquals(2, results.size(), 'Expected Result Size');
    }
    
    /**
* @description - for searching candidates by only gender.
*/
    
    @isTest
    static void testSearchCandidates_gender(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.gender = 'Male';
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
    }
    
    /**
* @description - for searching candidates by only notice period.
*/
    @isTest
    static void testSearchCandidates_noticePeriod(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.noticePeriod = '1 Month';
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
    }
    
    /**
* @description - for testing highest qualification.
*/
    
    @isTest
    static void testSearchCandidates_highQual(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.highestQualification = 'B.Tech';
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
        
    }
    /**
* @description - for testing Institute Name.
*/
    
    @isTest
    static void testSearchCandidates_institute(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.instituteName = 'Test College';
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
        
    }
    /**
* @description - for testing Language Known.
*/
    
    @isTest
    static void testSearchCandidates_languageKnown(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.languageKnown = 'Hindi';
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('Jane Smith', results[0].Name, 'Expected Jane Smith to match');
        
    }
    /**
* @description - for testing preferred Location.
*/
    
    @isTest
    static void testSearchCandidates_preferredLocation(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.preferredLocation = 'Pune';
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('Jane Smith', results[0].Name, 'Expected Jane Smith to match');
        
    }
    /**
* @description - for testing expected ctc .
*/
    
    @isTest
    static void testSearchCandidates_expectedCTC(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.expectedCTC = 70000;
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('John Doe', results[0].Name, 'Expected John Doe to match');
        
    }
    /**
* @description - for testing can join in.
*/
    
    @isTest
    static void testSearchCandidates_canJoinIn(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.canJoinIn = '30';
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('Jane Smith', results[0].Name, 'Expected Jane Smith to match');
        
    }
    
    
    /**
* @description - for testing the multiple skill addition and using the "And" methodology in searching when only skills are present.
*/
    
    @isTest
    static void testSearchCandidates_SkillBreak(){
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.skillQuery = 'Salesforce, Java';
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected at least one candidate');
        System.assertEquals('Jane Smith', results[0].Name, 'Expected Jane Smith to match');
        
    }
    
    /**
* @description - for returning open job positions.
*/
    
    @isTest
    static void testgetOpenJobPositions(){
        Test.startTest();
        List<Job_Position__c> results = CandidateSearchController.getOpenJobPositions('Salesforce');
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Should return at least one open job');
        for (Job_Position__c job : results) {
            System.assertEquals('Open', job.Status__c, 'job with open status');
        }
        
    }
    
    
    /**
* @description - for assigning candidates and job positions in a new interview record.
*/
    
    @isTest
    static void testAssignCandidatesToJobs() {
        
        List<Candidate__c> candidates = [SELECT Id FROM Candidate__c];
        
        List<Job_Position__c> jobs = [SELECT Id FROM Job_Position__c WHERE Status__c = 'Open' LIMIT 1];
        
        
        Test.startTest();
        CandidateSearchController.assignCandidatesToJobs(
            new List<Id>{candidates[0].Id, candidates[1].Id}, 
            new List<Id>{jobs[0].Id}
        );
        Test.stopTest();
        
        List<Interview__c> interviews = [
            SELECT Candidate__c, Job_Position__c, Interview_Status__c 
            FROM Interview__c 
            WHERE Job_Position__c = :jobs[0].Id
        ];
        System.assertEquals(2, interviews.size(), 'Two interviews should be created');
        System.assertEquals('New', interviews[0].Interview_Status__c, 'Interview status should be New');
    }
    
    //Negative Test Cases - Non Existent Skill
    @isTest
    static void testSearchCandidates_noResults() {
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        params.skillQuery = 'NonExistentSkill';
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Expected no candidates to be returned');
    }
    
    //Negative Test Cases - Empty Parameter
    @isTest
    static void testSearchCandidates_emptyParams() {
        CandidateSearchController.CandidateSearchParams params = new CandidateSearchController.CandidateSearchParams();
        
        Test.startTest();
        List<Candidate__c> results = CandidateSearchController.searchCandidates(params);
        Test.stopTest();
        
        System.assert(!results.isEmpty(), 'Expected all candidates to be returned');
        System.assertEquals(2, results.size(), 'Should return all candidates created in setup');
    }
    
    //Negative Test Cases - Assign Candidates with Empty Lists
    @isTest
    static void testAssignCandidatesToJobs_emptyLists() {
        Test.startTest();
        CandidateSearchController.assignCandidatesToJobs(new List<Id>(), new List<Id>());
        Test.stopTest();
        
        System.assertEquals(0, [SELECT Count() FROM Interview__c], 'No interviews should be created');
    }
    
    
    //Negative Test Cases - getOpenJobPositions No Match
    @isTest
    static void testGetOpenJobPositions_noMatch() {
        Test.startTest();
        List<Job_Position__c> results = CandidateSearchController.getOpenJobPositions('NonExistentJob');
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Expected no job positions to be returned');
    }
}