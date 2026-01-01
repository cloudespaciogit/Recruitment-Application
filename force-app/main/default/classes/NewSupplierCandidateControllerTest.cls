@IsTest
public class NewSupplierCandidateControllerTest {

    /* =========================
       TEST SETUP
       ========================= */
    @TestSetup
    static void setupData() {

        // Create a standard user to run tests in USER_MODE
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        // Client
        Client__c client =
            Recruitment_TestDataFactory.createClient('Test Client', 'client@test.com');
        insert client;

        // Project
        Project__c proj =
            Recruitment_TestDataFactory.createProject('Test Project');
        insert proj;

        // Job Position
        Job_Position__c job =
            Recruitment_TestDataFactory.createJobPosition(client, proj);
        insert job;
    }

    /* =========================
       HAPPY PATH TEST
       ========================= */
    @IsTest
    static void testSubmitCandidateSuccess() {

        User u = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];
        Job_Position__c job = [SELECT Id FROM Job_Position__c LIMIT 1];

        System.runAs(u) {

            NewSupplierCandidateController.CandidateRequest req =
                new NewSupplierCandidateController.CandidateRequest();

            req.firstName = 'Ashish';
            req.lastName = 'Kumar';
            req.email = 'ashish@test.com';
            req.phone = '9999999999';
            req.experienceYears = 3;
            req.skills = 'Salesforce';
            req.currentCompany = 'ABC Corp';
            req.jobTitle = 'Developer';
            req.expectedSalary = 100000;
            req.noticePeriod = '15 Days';
            req.jobPositionId = job.Id;

            // Resume payload (dummy base64)
            req.resumeFileName = 'resume.pdf';
            req.resumeContentType = 'application/pdf';
            req.resumeBase64Body = EncodingUtil.base64Encode(
                Blob.valueOf('dummy resume content')
            );

            String jsonReq = JSON.serialize(req);

            Test.startTest();
            NewSupplierCandidateController.CandidateResponse resp =
                NewSupplierCandidateController.submitCandidateForm(jsonReq);
            Test.stopTest();

            System.assertEquals(true, resp.success, 'Submission should succeed');
            System.assertNotEquals(null, resp.candidateId, 'Candidate Id should be returned');
            System.assert(
                resp.message.contains('Application submitted successfully'),
                'Success message expected'
            );

            // Candidate inserted
            Candidate__c c = [
                SELECT Id, Email__c
                FROM Candidate__c
                WHERE Id = :resp.candidateId
            ];
            System.assertEquals('ashish@test.com', c.Email__c);

            // Interview created
            List<Interview__c> interviews = [
                SELECT Id
                FROM Interview__c
                WHERE Candidate__c = :c.Id
            ];
            System.assertEquals(1, interviews.size(), 'Interview should be created');
        }
    }
    
    @IsTest
    static void testSubmitCandidateCatchInvalidJson() {
    
        User u = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];
    
        System.runAs(u) {
    
            String jsonReq = ''; // Invalid JSON input
    
            Test.startTest();
            NewSupplierCandidateController.CandidateResponse resp =
                NewSupplierCandidateController.submitCandidateForm(jsonReq);
            Test.stopTest();
    
            // ✅ Assertions (MANDATORY)
            System.assertNotEquals(
                null,
                resp,
                'Response should not be null'
            );
    
            System.assertEquals(
                false,
                resp.success,
                'Success should be false for invalid JSON'
            );
    
            System.assertEquals(
                'Invalid request format. Please refresh and try again.',
                resp.message,
                'Correct error message should be returned'
            );
    
            System.assertEquals(
                null,
                resp.candidateId,
                'CandidateId should be null when request fails'
            );
        }
    }


    /* =========================
       DUPLICATE EMAIL TEST
       ========================= */
    @IsTest
    static void testSubmitCandidateDuplicateEmail() {
        User u = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];
    
        System.runAs(u) {
        // Existing candidate
        Candidate__c existing =
            Recruitment_TestDataFactory.createCandidate('Existing', 'duplicate@test.com');
        insert existing;

        NewSupplierCandidateController.CandidateRequest req =
            new NewSupplierCandidateController.CandidateRequest();

        req.firstName = 'New';
        req.lastName = 'Candidate';
        req.email = 'duplicate@test.com';
        req.phone = '8888888888';

        String jsonReq = JSON.serialize(req);

        Test.startTest();
        NewSupplierCandidateController.CandidateResponse resp =
            NewSupplierCandidateController.submitCandidateForm(jsonReq);
        Test.stopTest();

        System.assertEquals(false, resp.success);
        System.assertEquals(
            'Email already exists. Please use a different email address.',
            resp.message
        );
            
        }
    }

    /* =========================
       MISSING REQUIRED FIELDS
       ========================= */
    @IsTest
    static void testSubmitCandidateMissingFields() {
        User u = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];
    
        System.runAs(u) {
        NewSupplierCandidateController.CandidateRequest req =
            new NewSupplierCandidateController.CandidateRequest();

        req.firstName = 'OnlyFirstName';

        String jsonReq = JSON.serialize(req);

        Test.startTest();
        NewSupplierCandidateController.CandidateResponse resp =
            NewSupplierCandidateController.submitCandidateForm(jsonReq);
        Test.stopTest();

        System.assertEquals(false, resp.success);
        System.assertEquals('Required fields are missing.', resp.message);
        }
    }

    /* =========================
       INVALID JSON
       ========================= */
    @IsTest
    static void testSubmitCandidateInvalidJson() {
        User u = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];
    
        System.runAs(u) {
        Test.startTest();
        NewSupplierCandidateController.CandidateResponse resp =
            NewSupplierCandidateController.submitCandidateForm('{invalid json}');
        Test.stopTest();

        System.assertEquals(false, resp.success);
        System.assertEquals(
            'Invalid request format. Please refresh and try again.',
            resp.message
        );
        }
    }
}