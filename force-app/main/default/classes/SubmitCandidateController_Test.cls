/*
##################################################### 
# Created By (Date)   : Shivam Shivhare (7 Oct, 2025)
# Description         : Test class for SubmitCandidateController Apex class.
# Modifications Log   : 
* Ver    Date              Author                   Modification
* 1.0    7 Oct, 2025      Shivam Shivhare          Initial Version
#####################################################
*/

@IsTest
private class SubmitCandidateController_Test {

    // ------------------ Test Setup ------------------
    /*
    * @description : Creates reusable test data (Candidates, Client, Job Position) for all tests.
    */
    @TestSetup
    static void setupTestData() {
        // Project
        Project__c proj = Recruitment_TestDataFactory.createProject('Project for Testing');
        insert proj;

        // Clients
        Client__c client = Recruitment_TestDataFactory.createClient('Test Client', 'testclient1@example.com');
        client.Candidate_Fields__c = 'Name,Email__c,Phone__c';
        insert client;

        Client__c clientNoFields = Recruitment_TestDataFactory.createClient('Client No Fields', 'nofields1@example.com');
        insert clientNoFields;

        // Candidates
        Candidate__c cand1 = Recruitment_TestDataFactory.createCandidate('John Doe', 'john1@example.com');
        cand1.Phone__c = '9000000001';
        Candidate__c cand2 = Recruitment_TestDataFactory.createCandidate('Jane Smith', 'jane2@example.com');
        cand2.Phone__c = '9000000002';
        insert new List<Candidate__c>{ cand1, cand2 };

        // Job Position
        Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(client, proj);
        job.Job_description__c = 'Responsible for Salesforce development';
        job.Work_Location__c = 'New York';
        job.Status__c='Open';
        insert job;
    }

    // ------------------ getAllClients Tests ------------------
    /*
    * @description : Positive test for getAllClients. Ensures clients with non-null email are returned.
    */
    @IsTest
    static void testGetAllClients_Positive() {
        Test.startTest();
        List<Client__c> clients = SubmitCandidateController.getAllClients();
        Test.stopTest();

        System.assertNotEquals(0, clients.size(), 'Clients should be returned');
        System.assertNotEquals(null, clients[0].Email__c, 'Client email should not be null');
    }

    /*
    * @description : Negative test for getAllClients. Ensures clients with null email do not appear.
    */
    @IsTest
    static void testGetAllClients_Negative() {
        Integer initialCount = SubmitCandidateController.getAllClients().size();

        Client__c validClient = Recruitment_TestDataFactory.createClient('Valid Client', 'valid3@example.com');
        insert validClient;

        Test.startTest();
        List<Client__c> clients = SubmitCandidateController.getAllClients();
        Test.stopTest();

        for (Client__c c : clients) {
            System.assertNotEquals(null, c.Email__c, 'Client email should not be null');
        }
        System.assert(clients.size() > initialCount, 'Client count should increase after inserting a valid client');
    }

    // ------------------ getJobPositionsByClient Tests ------------------
    /*
    * @description : Positive test for getJobPositionsByClient. Ensures job positions for a valid client are returned.
    */
    @IsTest
    static void testGetJobPositionsByClient_Positive() {
        Client__c client = [SELECT Id FROM Client__c WHERE Name = 'Test Client' LIMIT 1];
		//system.debug('91'+jobs.size());
        Test.startTest();
        List<Job_Position__c> jobs = SubmitCandidateController.getJobPositionsByClient(client.Id);
        Test.stopTest();
        system.debug('91'+jobs.size());

        System.assertNotEquals(0, jobs.size(), 'Job positions should be returned for valid client');
    }

    /*
    * @description : Negative test for getJobPositionsByClient. Ensures empty list returned for invalid client Id.
    */
    @IsTest
    static void testGetJobPositionsByClient_Negative() {
        Test.startTest();
        List<Job_Position__c> jobs = SubmitCandidateController.getJobPositionsByClient('005000000000000AAA');
        Test.stopTest();

        System.assertEquals(true, jobs.isEmpty(), 'Should return empty list for invalid client');
    }

    // ------------------ getCandidateForClient Tests ------------------
    /*
    * @description : Positive test for getCandidateForClient. Ensures correct candidate data returned.
    */
    @IsTest
    static void testGetCandidateForClient_Positive() {
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        Client__c client = [SELECT Id FROM Client__c WHERE Name = 'Test Client' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SubmitCandidateController.getCandidateForClient(cand.Id, client.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('fieldOrder'), 'fieldOrder should be in response');
        System.assert(result.containsKey('values'), 'values should be in response');
    }

    /*
    * @description : Negative test for getCandidateForClient. Ensures default fields used when Candidate_Fields__c is blank.
    */
    @IsTest
    static void testGetCandidateForClient_BlankFields() {
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        Client__c clientNoFields = [SELECT Id FROM Client__c WHERE Name = 'Client No Fields' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SubmitCandidateController.getCandidateForClient(cand.Id, clientNoFields.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should still return even if Candidate_Fields__c is blank');
    }

    // ------------------ getMultipleCandidatesForClient Tests ------------------
    /*
    * @description : Positive test for getMultipleCandidatesForClient. Ensures multiple candidate data returned correctly.
    */
    @IsTest
    static void testGetMultipleCandidatesForClient_Positive() {
        List<Candidate__c> cands = [SELECT Id FROM Candidate__c];
        Client__c client = [SELECT Id FROM Client__c WHERE Name = 'Test Client' LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> results = SubmitCandidateController.getMultipleCandidatesForClient(
            new List<Id>{ cands[0].Id, cands[1].Id }, client.Id
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return data for 2 candidates');
    }

    // ------------------ sendCandidateExcelEmail Tests ------------------
    /*
    * @description : Positive test for sendCandidateExcelEmail. Ensures email is sent successfully without exception.
    */
    @IsTest
    static void testSendCandidateExcelEmail_Positive() {
        List<Candidate__c> cands = [SELECT Id FROM Candidate__c];
        Client__c client = [SELECT Id, Email__c FROM Client__c WHERE Name = 'Test Client' LIMIT 1];
        Job_Position__c job = [SELECT Id FROM Job_Position__c WHERE Client__c = :client.Id LIMIT 1];

        Test.startTest();
        try {
            SubmitCandidateController.sendCandidateExcelEmail(
                new List<Id>{ cands[0].Id, cands[1].Id }, client.Id, job.Id
            );
        } catch (Exception e) {
            System.assert(false, 'sendCandidateExcelEmail should not throw exception: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /*
    * @description : Negative test for sendCandidateExcelEmail. Ensures exception thrown for invalid client Id.
    */
    @IsTest
    static void testSendCandidateExcelEmail_Negative() {
        List<Candidate__c> cands = [SELECT Id FROM Candidate__c LIMIT 1];
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            SubmitCandidateController.sendCandidateExcelEmail(
                new List<Id>{ cands[0].Id }, '005000000000000AAA', job.Id
            );
            Test.stopTest();
        } catch (Exception e) {
            exceptionThrown = true;
        }
        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for invalid client Id');
    }

}