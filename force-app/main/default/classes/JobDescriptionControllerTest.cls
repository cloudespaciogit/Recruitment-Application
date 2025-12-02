@IsTest
public class JobDescriptionControllerTest {

    // ----------------------------------------------------
    // MOCK CLASS for OpenAI Named Credential Callout
    // ----------------------------------------------------
    private class OpenAIMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{ "choices": [ { "message": { "content": "Mock AI Job Description" } } ] }');
            return res;
        }
    }

    // ----------------------------------------------------
    // TEST DATA USING @TestSetup  (Runs once for all tests)
    // ----------------------------------------------------
    @TestSetup
    static void setupData() {
        
        Client__c client = Recruitment_TestDataFactory.createClient('Test Client', 'client@example.com');
        insert client;
        Project__c project = Recruitment_TestDataFactory.createProject('Test Project');
        
        Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(client, project);
        job.Client__c = client.Id;
        job.Job_Title__c = 'Salesforce Developer';
        job.Skills_Required__c = 'Apex; Java';
        insert job;

        
       
    }

    // ----------------------------------------------------
    // TEST: getJobDetails
    // ----------------------------------------------------
    @IsTest
    static void testGetJobDetails() {

        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();
        Job_Position__c result = JobDescriptionController.getJobDetails(job.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Apex; Java', result.Skills_Required__c);
    }

    // ----------------------------------------------------
    // TEST: generateJobDescription (Mocked callout)
    // ----------------------------------------------------
    @IsTest
    static void testGenerateJobDescription() {

        Job_Position__c job = [SELECT Id, Skills_Required__c, 
                                      Aditional_Skills__c, Qualification__c,
                                      Experience_Required__c, Soft_skills__c
                               FROM Job_Position__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new OpenAIMock());

        Test.startTest();
        String response = JobDescriptionController.generateJobDescription(
            job.Id,
            job.Skills_Required__c,
            job.Aditional_Skills__c,
            job.Qualification__c,
            job.Experience_Required__c,
            job.Soft_skills__c,
            'Professional',
            'Medium',
            'Short'
        );
        Test.stopTest();

        System.assert(response.contains('Mock AI Job Description'));
    }

    // ----------------------------------------------------
    // TEST: saveJobDescription (Success)
    // ----------------------------------------------------
    @IsTest
    static void testSaveJobDescription() {

        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();
        JobDescriptionController.saveJobDescription(job.Id, 'Updated Description');
        Test.stopTest();

        Job_Position__c updatedJob = [
            SELECT Job_Description__c 
            FROM Job_Position__c 
            WHERE Id = :job.Id
        ];

        System.assertEquals('Updated Description', updatedJob.Job_Description__c);
    }

    // ----------------------------------------------------
    // TEST: saveJobDescription Error Case
    // ----------------------------------------------------
    @IsTest
    static void testSaveJobDescriptionError() {

        Test.startTest();
        try {
            JobDescriptionController.saveJobDescription(null, 'Desc');
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
            
            System.assert(e.getMessage().contains('Script-thrown exception'));
        }
        Test.stopTest();
    }
}