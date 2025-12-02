/*
##################################################### 
# Created By (Date)   : Shivam Shivhare (11 Nov, 2025)
# Description         : Test class for CandidatePhotoService Apex class.
#                       Covers all positive and negative test scenarios including
#                       different Google Drive callout responses.
# Modifications Log   : 
* Ver    Date              Author              Modification
* 1.0    11 Nov, 2025      Shivam Shivhare     Initial Version
#####################################################
*/

@IsTest
private class CandidatePhotoServiceTest {

    // ------------------ Mock Classes ------------------

    /*
    * @description : Mock implementation simulating all successful Google Drive operations 
    *                (folder fetch, file fetch, and file download).
    */
    private class GoogleDrivePhotoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('mimeType%3D%27application%2Fvnd.google-apps.folder%27')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFolderId","name":"Folder_Test"}]}');
            } else if (endpoint.contains('in+parents')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFileId","name":"Candidate Photo"}]}');
            } else if (endpoint.contains('/drive/v3/files/mockFileId?alt=media')) {
                res.setStatusCode(200);
                res.setBody('This is dummy file content');
            } else {
                res.setStatusCode(404);
                res.setBody('{}');
            }

            return res;
        }
    }

    // ------------------ Mock for HTTP failure ------------------
    private class FailingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Error');
            return res;
        }
    }

    // ------------------ Mock for empty folder ------------------
    private class NoPhotoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            if (endpoint.contains('mimeType%3D%27application%2Fvnd.google-apps.folder%27')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFolderId","name":"Folder_Test"}]}');
            } else if (endpoint.contains('in+parents')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFileId","name":"Resume.pdf"}]}');
            } else {
                res.setStatusCode(200);
                res.setBody('This is dummy file content');
            }
            return res;
        }
    }

    // ------------------ Mock for Step 3 download failure ------------------
    private class FileDownloadFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('mimeType%3D%27application%2Fvnd.google-apps.folder%27')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFolderId","name":"Folder_Test"}]}');
            } else if (endpoint.contains('in+parents')) {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFileId","name":"Candidate Photo"}]}');
            } else if (endpoint.contains('/drive/v3/files/mockFileId?alt=media')) {
                res.setStatusCode(404);
                res.setBody('{"error":"File not found"}');
            }
            return res;
        }
    }

    // ------------------ Test Setup ------------------
    @TestSetup
    static void setupData() {
        Candidate__c c = Recruitment_TestDataFactory.createCandidate('Test', 'test@test.com');
        insert c;
    }

    // ------------------ Positive Test ------------------
    @IsTest
    static void testGetCandidateProfilePhotoBase64_Success() {
        Candidate__c c = [SELECT Id FROM Candidate__c LIMIT 1];
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GoogleDrivePhotoMock());
        String base64 = CandidatePhotoService.getCandidateProfilePhotoBase64(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, base64);
        System.assertEquals(EncodingUtil.base64Encode(Blob.valueOf('This is dummy file content')), base64);
    }

    // ------------------ Negative Tests ------------------
    @IsTest
    static void testGetCandidateProfilePhotoBase64_Failure() {
        Candidate__c c = [SELECT Id FROM Candidate__c LIMIT 1];
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FailingMock());
        String base64 = CandidatePhotoService.getCandidateProfilePhotoBase64(c.Id);
        Test.stopTest();
        System.assertEquals(null, base64);
    }

    @IsTest
    static void testGetCandidateProfilePhotoBase64_NoPhotoFound() {
        Candidate__c c = [SELECT Id FROM Candidate__c LIMIT 1];
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new NoPhotoMock());
        String base64 = CandidatePhotoService.getCandidateProfilePhotoBase64(c.Id);
        Test.stopTest();
        System.assertEquals(null, base64);
    }

    @IsTest
    static void testGetCandidateProfilePhotoBase64_FileDownloadFail() {
        Candidate__c c = [SELECT Id FROM Candidate__c LIMIT 1];
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FileDownloadFailMock());
        String base64 = CandidatePhotoService.getCandidateProfilePhotoBase64(c.Id);
        Test.stopTest();
        System.assertEquals(null, base64);
    }

    @IsTest
    static void testGetCandidateProfilePhotoBase64_ExceptionCatch() {
        Test.startTest();
        Id fakeId = '003000000000000AAA'; // valid format but non-existing
        String base64 = CandidatePhotoService.getCandidateProfilePhotoBase64(fakeId);
        Test.stopTest();
        System.assertEquals(null, base64);
    }
}