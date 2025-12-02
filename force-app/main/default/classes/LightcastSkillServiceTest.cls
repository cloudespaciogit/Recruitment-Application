@IsTest
private class LightcastSkillServiceTest {

    // Mock class for positive response (status 200)
    private class LightcastSkillServiceMockSuccess implements HttpCalloutMock {
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

    // Mock class for negative response (non-200)
    private class LightcastSkillServiceMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    // Mock class to simulate exception (e.g., malformed JSON)
    private class LightcastSkillServiceMockThrows implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // malformed JSON body to trigger JSON.deserializeUntyped exception
            res.setBody('{"invalid_json":');
            return res;
        }
    }

    @IsTest
    static void testFetchSkills_Success() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new LightcastSkillServiceMockSuccess());
        List<String> skills = LightcastSkillService.fetchSkills('apex');
        Test.stopTest();

        System.assertEquals(3, skills.size(), 'Should return 3 skill names');
        System.assert(skills.contains('Java'));
        System.assert(skills.contains('Apex'));
        System.assert(skills.contains('LWC'));
    }

    @IsTest
    static void testFetchSkills_ErrorResponse() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new LightcastSkillServiceMockError());
        List<String> skills = LightcastSkillService.fetchSkills('error');
        Test.stopTest();

        System.assertEquals(0, skills.size(), 'Should return empty list on error response');
    }

    @IsTest
    static void testFetchSkills_ExceptionHandling() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new LightcastSkillServiceMockThrows());
        List<String> skills = LightcastSkillService.fetchSkills('exception');
        Test.stopTest();

        System.assertEquals(0, skills.size(), 'Should safely return empty list when exception occurs');
    }
}