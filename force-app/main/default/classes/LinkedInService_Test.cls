/**
* @File Name : LinkedInService_Test.cls
* @Description : Test class validating LinkedInService including 
*                success scenarios and callout exception handling.
* @Author : AJAY Kaurav
* @Last Modified On : November 25, 2025
*/

@isTest
public class LinkedInService_Test {

    @testSetup
    static void setupTestData() {
        Client__c client = Recruitment_TestDataFactory.createClient('Test Client', 'client@test.com');
        insert client;

        Project__c proj = Recruitment_TestDataFactory.createProject('Test Project');
        insert proj;

        Job_Position__c jobPos = Recruitment_TestDataFactory.createJobPosition(client, proj);
        jobPos.Skills_Required__c = 'Apex, LWC, Integration';
        jobPos.Employment_Type__c = 'Full-Time';
        jobPos.Mode__c = 'Online';
        jobPos.Work_Mode__c = 'Hybrid';
        jobPos.Shift_Time__c = 'Day';
        jobPos.Qualification__c = 'B.Tech';
        jobPos.Experience_Required__c = 2;
        jobPos.Soft_skills__c = 'Communication';
        jobPos.Aditional_Skills__c = 'Git';
        insert jobPos;
    }

    // ----------------------------------------------------
    // SUCCESS: Get Job Details
    // ----------------------------------------------------
    @isTest
    static void testGetJobDetailsForLinkedin_Success() {
        Job_Position__c jp = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();
        Job_Position__c result = LinkedInService.getJobDetailsForLinkedin(jp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Full-Time', result.Employment_Type__c);
    }

    // ----------------------------------------------------
    // SUCCESS: Get Company Name
    // ----------------------------------------------------
    @isTest
    static void testGetCompanyName_Success() {
        Test.startTest();
        String cname = LinkedInService.getCompanyName();
        Test.stopTest();

        System.assertNotEquals('', cname);
        System.assertNotEquals(null, cname);
    }

    // ----------------------------------------------------
    // SUCCESS: Create LinkedIn Post
    // ----------------------------------------------------
    private class LinkedInMockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"id":"urn:li:ugcPost:98765"}');
            return res;
        }
    }

    @isTest
    static void testCreatePost_Success() {
        Test.setMock(HttpCalloutMock.class, new LinkedInMockSuccess());

        Test.startTest();
        String res = LinkedInService.createPost('Test Hiring Post');
        Test.stopTest();

        System.assert(res.contains('urn:li:ugcPost'), 'Response should contain LinkedIn post URN');
    }

    // ----------------------------------------------------
    // NEGATIVE: CalloutException Path
    // ----------------------------------------------------
    private class LinkedInMockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Mocked LinkedIn failure!');
        }
    }

    @isTest
    static void testCreatePost_CalloutException() {
        Test.setMock(HttpCalloutMock.class, new LinkedInMockError());
        Boolean exceptionThrown = false;

        try {
            Test.startTest();
            LinkedInService.createPost('Error Post');
            Test.stopTest();
        } catch (Exception ex) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown, 'Exception must be thrown on callout failure');
    }
}