@IsTest
private class CandidatePublicControllerTest {

    // ========================================================
    // GLOBAL TEST DATA (Created ONLY once in @testSetup)
    // ========================================================
    static User testUser;
    static Recruiter__c recruiter;
    static Client__c client;
    static Project__c project;
    static List<Job_Position__c> jobList;
    static Candidate__c existingCandidate;
    static Interview__c existingInterview;

    // ========================================================
    // SETUP METHOD – All INSERTS only here
    // ========================================================
    @testSetup
    static void setupData() {

        // -------------------------------------------
        // USER
        // -------------------------------------------
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'tuser@test.com',
            Username = 'test' + System.currentTimeMillis() + '@test.com',
            Alias = 'tusr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert testUser;

        // -------------------------------------------
        // RECRUITER using FACTORY
        // -------------------------------------------
        recruiter = Recruitment_TestDataFactory.createRecruiter('Recruiter1', 'rec@test.com');
        recruiter.OwnerId = testUser.Id;
        insert recruiter;

        // -------------------------------------------
        // CLIENT using FACTORY
        // -------------------------------------------
        client = Recruitment_TestDataFactory.createClient('Test Client', 'client@test.com');
        client.Recruiter__c = recruiter.Id;
        client.OwnerId = testUser.Id;
        insert client;

        // -------------------------------------------
        // PROJECT using FACTORY
        // -------------------------------------------
        project = Recruitment_TestDataFactory.createProject('Test Project Description');
        insert project;

        // -------------------------------------------
        // JOB POSITIONS (5 records)
        // -------------------------------------------
        jobList = new List<Job_Position__c>();

       for (Integer i = 0; i < 5; i++) {

    Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(client, project);
    job.Job_Title__c = 'Developer ' + i;
    job.Status__c = 'Open';
    job.Job_Description__c = 'Test Job Description';

    // Fix for minExperience test
    job.Experience_Required__c = (i == 0) ? 10 : i; // First job = 10, others 1..4

    job.Job_Location__City__s = 'Mumbai';
    job.OwnerId = testUser.Id;

    jobList.add(job);
}


        insert jobList;

        // -------------------------------------------
        // Existing Candidate using Factory
        // -------------------------------------------
        existingCandidate = Recruitment_TestDataFactory.createCandidate('Existing Tester', 'existing@test.com');
        existingCandidate.Phone__c = '9999999999';
        insert existingCandidate;

        // -------------------------------------------
        // Existing Interview (linked to first job)
        // -------------------------------------------
        existingInterview = Recruitment_TestDataFactory.createInterview(existingCandidate, jobList[0]);
        existingInterview.OwnerId = testUser.Id;
        insert existingInterview;
    }

    // ========================================================
    // TEST METHODS (NO INSERTS HERE)
    // ========================================================

   /* @IsTest
    static void testGetOpenJobPositions() {
        List<Job_Position__c> res = CandidatePublicController.getOpenJobPositions();
        System.assert(res.size() == 5);
    }*/

    @IsTest
    static void testGetJobDetails() {
        Job_Position__c jp = [SELECT Id FROM Job_Position__c LIMIT 1];
        Job_Position__c details = CandidatePublicController.getJobDetails(jp.Id);
        System.assertNotEquals(null, details);
    }

    @IsTest
    static void testSearchJobPositions() {
        CandidatePublicController.JobSearchResponse resp =
            CandidatePublicController.searchJobPositions(1, 10, 'Developer', 'Mumbai', 0, 3);

        System.assert(resp.totalRecords > 0);
        System.assert(resp.jobs.size() > 0);
    }

    @IsTest
    static void testCheckExistingCandidate() {
        Candidate__c c1 = CandidatePublicController.checkExistingCandidate('existing@test.com', null);
        System.assertNotEquals(null, c1);

        Candidate__c c2 = CandidatePublicController.checkExistingCandidate(null, '9999999999');
        System.assertNotEquals(null, c2);

        Candidate__c none = CandidatePublicController.checkExistingCandidate('xx@test.com', '111');
        System.assertEquals(null, none);
    }

    @IsTest
    static void testSubmitCandidate_New() {

        Job_Position__c jp = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();
        CandidatePublicController.CandidateResponse resp =
            CandidatePublicController.submitCandidateForm(
                'John', 'Doe', 'john@test.com', '9000000001', 3,
                'Apex', 'Corp', 'Developer', 12,
                '30 Days', 'token', 'resume.pdf', 'application/pdf', 'BASE64',
                jp.Id
            );
        Test.stopTest();

        System.assert(resp.success);
        System.assert(resp.interviewCreated);
        System.assertNotEquals(null, resp.candidateId);
        System.assertNotEquals(null, resp.interviewId);
    }

    @IsTest
static void testSearchJobPositions_MinExpOnly() {
    // Call the search method with minExperience set and maxExperience null
    CandidatePublicController.JobSearchResponse resp =
        CandidatePublicController.searchJobPositions(
            1,          // pageNumber
            10,         // pageSize
            'Developer',// search keyword
            'Mumbai',   // city
            10,         // minExperience
            null        // maxExperience
        );

    System.assert(resp.totalRecords > 0);
    System.assert(resp.jobs.size() > 0);
}

    
    @IsTest
    static void testSubmitCandidate_NoJobId() {

        Test.startTest();
        CandidatePublicController.CandidateResponse resp =
            CandidatePublicController.submitCandidateForm(
                'Ana', 'Singh', 'ana@test.com', '9000000002', 2,
                'Java', 'TechCo', 'Engineer', 10,
                '15 Days', null, null, null, null, null
            );
        Test.stopTest();

        System.assert(resp.success);
        System.assertEquals('Candidate saved successfully.', resp.message);
        System.assertEquals(null, resp.interviewId);
    }
    
    @IsTest
static void testSubmitCandidate_RequiredFieldsMissing() {
    // Call with firstName blank to trigger validation
    Test.startTest();
    CandidatePublicController.CandidateResponse resp =
        CandidatePublicController.submitCandidateForm(
            '',                   // firstName missing
            'Doe',
            'test@test.com',
            '9000000001',
            3, 'Apex', 'Corp', 'Developer', 12,
            '30 Days', '', '', '', '', null
        );
    Test.stopTest();

    System.assertEquals(false, resp.success);
    System.assertEquals('Required fields are missing.', resp.message);
}
@IsTest
static void testCoverExistingCandidateAssignment() {

    // Create existing candidate
    Candidate__c existing = new Candidate__c(
        First_Name__c = 'Test',
        Last_Name__c = 'Existing',
        Email__c = 'existingCover@test.com',
        Phone__c = '9998887777'
    );
    insert existing;

    // Call the method with SAME email → will hit: cand = existing[0];
    CandidatePublicController.CandidateResponse resp =
        CandidatePublicController.submitCandidateForm(
            'Test',
            'Existing',
            'existingCover@test.com',   // SAME email → existing found
            '9998887777',
            3,
            'Apex',
            'Company',
            'Developer',
            10,
            '30 Days',
            'token',
            'resume.pdf',
            'application/pdf',
            null,   // no resumeBase64Body
            null    // jobId = null → interview logic skipped
        );

    // Pass if no exception thrown → line covered
    System.assertEquals(true, resp.success);
}
    
    

}