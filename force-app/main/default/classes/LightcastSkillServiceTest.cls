@IsTest
private class LightcastSkillServiceTest {

/**
* @description Creates test data for candidates, clients, and job positions.
*              This data is used by all test methods in this class.
*/
    @TestSetup
    static void setupTestData() {

         Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User u = new User(
            FirstName = 'Test',
            LastName = 'Owner',
            Alias = 'tuser',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            CommunityNickname = 'testuser' + System.currentTimeMillis(),
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
    }

    /**
    * @description Mock class that simulates a successful (HTTP 200) response
    *              from the Lightcast Skills API endpoint.
    */
    private class LightcastSkillServiceMockSuccess implements HttpCalloutMock {

        /**
        * @description Returns a mocked successful API response containing
        *              a list of sample skills in JSON format.
        *
        * @param req HttpRequest – The outgoing request sent by the Apex code.
        *
        * @return HttpResponse – Mocked response with status 200 and valid JSON.
        */
        public HTTPResponse respond(HTTPRequest req) {
            System.assert(req.getEndpoint().contains('callout:Lightcast/skills/versions/latest/skills'));
            System.assertEquals('GET', req.getMethod());

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data":[{"name":"Java"},{"name":"Apex"},{"name":"LWC"}]}');
            return res;
        }
    }


    /**
    * @description Mock class that simulates an error response (non-200)
    *              from the Lightcast Skills API endpoint.
    */
    private class LightcastSkillServiceMockError implements HttpCalloutMock {

        /**
        * @description Returns a mocked failure response with HTTP 500
        *              to simulate server-side API errors.
        *
        * @param req HttpRequest – The outgoing request sent by the Apex code.
        *
        * @return HttpResponse – Mocked error response with status 500.
        */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }


    /**
    * @description Mock class that simulates an API response that triggers a
    *              JSON parsing exception during deserialization.
    */
    private class LightcastSkillServiceMockThrows implements HttpCalloutMock {

        /**
        * @description Returns a mocked response with malformed JSON intended to
        *              simulate JSON parsing exceptions in consuming code.
        *
        * @param req HttpRequest – The outgoing request sent by the Apex code.
        *
        * @return HttpResponse – Mocked HTTP 200 but with invalid JSON body.
        */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"invalid_json":');
            return res;
        }
    }


    @IsTest
    static void testFetchSkillsSuccess() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u){
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new LightcastSkillServiceMockSuccess());
        List<String> skills = LightcastSkillService.fetchSkills('apex');
        Test.stopTest();

        System.assertEquals(3, skills.size(), 'Should return 3 skill names');
        System.assert(skills.contains('Java'));
        System.assert(skills.contains('Apex'));
        System.assert(skills.contains('LWC'));
          }
    }

    @IsTest
    static void testFetchSkillsErrorResponse() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u){
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new LightcastSkillServiceMockError());
        List<String> skills = LightcastSkillService.fetchSkills('error');
        Test.stopTest();

        System.assertEquals(0, skills.size(), 'Should return empty list on error response');
    }
    }
    @IsTest
    static void testFetchSkillsExceptionHandling() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
          System.runAs(u){
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new LightcastSkillServiceMockThrows());
        List<String> skills = LightcastSkillService.fetchSkills('exception');
        Test.stopTest();

        System.assertEquals(0, skills.size(), 'Should safely return empty list when exception occurs');
    }
    }
}