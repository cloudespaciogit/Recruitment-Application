/*
##################################################### 
# Created By (Date)   : Shivam Shivhare (02 Sep, 2025)
# Description         : Test class for CandidateDocumentService Apex class.
# Modifications Log   : 
* Ver    Date              Author                   Modification
* 1.0    02 Sep, 2025      Shivam Shivhare          Initial Version
#####################################################
*/

@IsTest
private class CandidateDocumentServiceTest {
    
    // ------------------ Mock Classes ------------------
    /*
* @description : Mock implementation simulating all successful Google Drive operations 
*                (folder search, upload, get files, and delete).
*/
    private class GoogleDriveMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            
            if (req.getEndpoint().contains('/drive/v3/files?q=') && req.getMethod() == 'GET' 
                && !req.getEndpoint().contains('&fields=files')) {
                    // Folder search success
                    res.setStatusCode(200);
                    res.setBody('{"files":[{"id":"mockFolderId","name":"TestFolder"}]}');
                } else if (req.getEndpoint().endsWith('/drive/v3/files') && req.getMethod() == 'POST') {
                    // Folder creation success
                    res.setStatusCode(200);
                    res.setBody('{"id":"newFolderId"}');
                } else if (req.getEndpoint().contains('/upload/drive/v3/files') && req.getMethod() == 'POST') {
                    // File upload success
                    res.setStatusCode(200);
                    res.setBody('{"id":"mockFileId"}');
                } else if (req.getEndpoint().contains('&fields=files') && req.getMethod() == 'GET') {
                    // File retrieval success
                    res.setStatusCode(200);
                    res.setBody('{"files":[{"id":"file123","name":"resume.pdf","mimeType":"application/pdf","size":"1024","createdTime":"2024-01-01T00:00:00.000Z","modifiedTime":"2024-01-02T00:00:00.000Z"}]}');
                } else if (req.getEndpoint().contains('/drive/v3/files/') && req.getMethod() == 'DELETE') {
                    // File deletion success
                    res.setStatusCode(204);
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"files":[]}');
                }
            return res;
        }
    }
    
    /*
* @description : Mock simulating empty folder scenario (no files found).
*/
    private class GoogleDriveMock_EmptyFolder implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"files":[]}');
            return res;
        }
    }
    
    /*
* @description : Mock simulating scenario where folder is created before file upload.
*/
    private class GoogleDriveMock_CreateFolder implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/drive/v3/files?q=') && req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody('{"files":[]}');
            } else if (req.getEndpoint().endsWith('/drive/v3/files') && req.getMethod() == 'POST') {
                res.setStatusCode(200);
                res.setBody('{"id":"createdFolderId"}');
            } else if (req.getEndpoint().contains('/upload/drive/v3/files') && req.getMethod() == 'POST') {
                res.setStatusCode(200);
                res.setBody('{"id":"mockFileId"}');
            }
            return res;
        }
    }
    
    /*
* @description : Mock simulating generic callout failure.
*/
    private class FailingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Error"}');
            return res;
        }
    }
    
    /*
* @description : Mock simulating failure during file deletion.
*/
    private class FailingDeleteMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getMethod() == 'DELETE') {
                res.setStatusCode(500);
                res.setBody('Internal Server Error');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    /*
* @description : Mock simulating failure during file fetch after folder retrieval.
*/
    private class FailingFileFetchMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/drive/v3/files?q=') 
                && req.getMethod() == 'GET' 
                && !req.getEndpoint().contains('&fields=files')) {
                    res.setStatusCode(200);
                    res.setBody('{"files":[{"id":"mockFolderId"}]}');
                } else if (req.getEndpoint().contains('&fields=files') && req.getMethod() == 'GET') {
                    res.setStatusCode(500);
                    res.setBody('File fetch failed');
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"files":[]}');
                }
            return res;
        }
    }
    
    /*
* @description : Mock simulating failure during multipart file upload.
*/
    private class FailingUploadMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            
            if (req.getEndpoint().contains('/drive/v3/files?q=') && req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody('{"files":[{"id":"mockFolderId"}]}');
            } else if (req.getEndpoint().contains('/upload/drive/v3/files') && req.getMethod() == 'POST') {
                res.setStatusCode(400);
                res.setBody('Bad Request in upload');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            
            return res;
        }
    }
    
    // ------------------ Setup ------------------
    /*
* @description : Inserts test data (Candidate__c record) before tests run.
*/
    @TestSetup
    static void setupData() {
        Candidate__c candidate = Recruitment_TestDataFactory.createCandidate('Test Candidate', 'test@gmail.com');
        candidate.Last_name__c = 'Candidate';
        candidate.First_Name__c='Test';
        insert candidate;
    }
    
    // ------------------ Positive Tests ------------------
    /*
* @description : Tests successful file upload to Google Drive.
*/
    @IsTest
    static void testUploadFile() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GoogleDriveMock());
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        String fileId = CandidateDocumentService.uploadFileToDrive(
            'resume.pdf',
            EncodingUtil.base64Encode(Blob.valueOf('dummy data')),
            'application/pdf',
            cand.Id
        );
        System.assertEquals('mockFileId', fileId);
        Test.stopTest();
    }
    
    /*
* @description : Tests successful retrieval of files from Google Drive.
*/
    @IsTest
    static void testGetFiles() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GoogleDriveMock());
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        List<Map<String,Object>> files = CandidateDocumentService.getFiles(cand.Id);
        System.assertEquals(1, files.size());
        System.assertEquals('resume.pdf', (String) files[0].get('name'));
        Test.stopTest();
    }
    
    /*
* @description : Tests successful deletion of a file from Google Drive.
*/
    @IsTest
    static void testDeleteFile() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GoogleDriveMock());
        String result = CandidateDocumentService.deleteFileFromDrive('mockFileId');
        System.assertEquals('File deleted successfully', result);
        Test.stopTest();
    }
    
    /*
* @description : Tests file upload when folder is not found and must be created.
*/
    @IsTest
    static void testUploadFile_createsNewFolder() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_CreateFolder());
        CandidateDocumentService.TEST_parentFolderId = 'parent123';
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        String fileId = CandidateDocumentService.uploadFileToDrive(
            'resume_new.pdf',
            EncodingUtil.base64Encode(Blob.valueOf('dummy data')),
            'application/pdf',
            cand.Id
        );
        System.assertEquals('mockFileId', fileId);
        CandidateDocumentService.TEST_parentFolderId = null;
        Test.stopTest();
    }
    
    // ------------------ Negative Tests ------------------
    
    /*
* @description : Tests upload failure when parent folder ID is blank.
*/
    @IsTest
    static void testUploadFile_blankParentFolderId() {
        Test.startTest();
        CandidateDocumentService.TEST_parentFolderId = ''; 
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        
        Boolean exceptionThrown = false;
        try {
            CandidateDocumentService.uploadFileToDrive(
                'resume.pdf',
                EncodingUtil.base64Encode(Blob.valueOf('dummy data')),
                'application/pdf',
                cand.Id
            );
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } finally {
            CandidateDocumentService.TEST_parentFolderId = null;
        }
        System.assert(exceptionThrown, 'Exception not thrown');
        Test.stopTest();
    }
    
    /*
* @description : Tests upload failure when Google Drive callout returns error.
*/
    @IsTest
    static void testUploadFile_calloutFailure() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FailingMock());
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        Boolean exceptionThrown = false;
        try {
            CandidateDocumentService.uploadFileToDrive(
                'resume.pdf',
                EncodingUtil.base64Encode(Blob.valueOf('dummy data')),
                'application/pdf',
                cand.Id
            );
        } catch(AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown);
        Test.stopTest();
    }
    
    /*
* @description : Tests file retrieval when folder is empty.
*/
    @IsTest
    static void testGetFiles_emptyFolder() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_EmptyFolder());
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        List<Map<String,Object>> files = CandidateDocumentService.getFiles(cand.Id);
        System.assertEquals(0, files.size());
        Test.stopTest();
    }
    
    /*
* @description : Tests file retrieval failure when Google Drive returns error.
*/
    @IsTest
    static void testGetFiles_calloutFailure() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FailingMock());
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        Boolean exceptionThrown = false;
        try {
            CandidateDocumentService.getFiles(cand.Id);
        } catch(AuraHandledException e){
            exceptionThrown = true;
        }
        System.assert(exceptionThrown);
        Test.stopTest();
    }
    
    /*
* @description : Tests file deletion failure when Google Drive API call fails.
*/
    @IsTest
    static void testDeleteFile_calloutFailure() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FailingDeleteMock());
        Boolean exceptionThrown = false;
        try {
            CandidateDocumentService.deleteFileFromDrive('someFileId');
        } catch(AuraHandledException e){
            exceptionThrown = true;
        }
        System.assert(exceptionThrown);
        Test.stopTest();
    }
    
    /*
* @description : Tests failure during file fetch from Drive after folder retrieval.
*/
    @IsTest
    static void testGetFiles_fileFetchFailure() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FailingFileFetchMock());
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        
        Boolean exceptionThrown = false;
        try {
            CandidateDocumentService.getFiles(cand.Id);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Exception not thrown');
        Test.stopTest();
    }
    
    /*
* @description : Tests failure during multipart file upload operation.
*/
    @IsTest
    static void testUploadMultipart_failure() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FailingUploadMock());
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        
        Boolean exceptionThrown = false;
        try {
            CandidateDocumentService.uploadFileToDrive(
                'resume_fail.pdf',
                EncodingUtil.base64Encode(Blob.valueOf('dummy data')),
                'application/pdf',
                cand.Id
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.debug('Caught expected exception: ' + e.getMessage());
        }
        
        System.assert(exceptionThrown, 'Expected AuraHandledException not thrown');
        Test.stopTest();
    }
    
    //===========================================================================================
    @IsTest
    static void testUpdateResumeLink_Positive_Update() {
        Candidate__c cand = [SELECT Id, Resume_Link__c FROM Candidate__c LIMIT 1];
        
        Test.startTest();
        // Update resume link
        CandidateDocumentService.updateResumeLink(cand.Id, '12345DriveId');
        Test.stopTest();
        
        Candidate__c updatedCand = [SELECT Resume_Link__c FROM Candidate__c WHERE Id = :cand.Id];
        System.assertEquals(
            'https://drive.google.com/file/d/12345DriveId/view',
            updatedCand.Resume_Link__c,
            'Resume link should be updated correctly'
        );
    }
    
    @IsTest
    static void testUpdateResumeLink_Positive_Delete() {
        Candidate__c cand = [SELECT Id, Resume_Link__c FROM Candidate__c LIMIT 1];
        
        Test.startTest();
        // Remove resume link
        CandidateDocumentService.updateResumeLink(cand.Id, null);
        Test.stopTest();
        
        Candidate__c updatedCand = [SELECT Resume_Link__c FROM Candidate__c WHERE Id = :cand.Id];
        System.assertEquals(null, updatedCand.Resume_Link__c, 'Resume link should be cleared');
    }
	
	@IsTest
static void testUpdateResumeLink_NullCandidateId() {
    Boolean exceptionThrown = false;
    try {
        Test.startTest();
        CandidateDocumentService.updateResumeLink(null, 'anyDriveId');
        Test.stopTest();
    } catch (AuraHandledException e) {
        exceptionThrown = true;
        System.assert(
    e.getMessage().contains('Candidate Id is required') ||
    e.getMessage().contains('Script-thrown exception'),
    'Expected AuraHandledException for null candidateId'
);

    }
    System.assert(exceptionThrown, 'Expected AuraHandledException for null candidateId');
}

    
@IsTest
static void testUpdateResumeLink_GenericException() {
    Boolean exceptionThrown = false;

    try {
        Test.startTest();
        // Pass a fake Id that is valid format but won't exist
        CandidateDocumentService.updateResumeLink(Id.valueOf('001000000000000AAA'), '123DriveId');
        Test.stopTest();
    } catch (AuraHandledException e) {
        exceptionThrown = true;
        // Debug the actual exception message
        System.debug('Caught AuraHandledException: ' + e.getMessage());
       System.assert(
    e.getMessage().contains('Unexpected error') || 
    e.getMessage().contains('Script-thrown exception'),
    'Expected generic AuraHandledException'
);

    }

    System.assert(exceptionThrown, 'Expected AuraHandledException for generic exception');
}
  
   @IsTest
static void testUpdateResumeLink_DmlException_Coverage() {
    Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
    delete cand; 

    Boolean exceptionThrown = false;
    try {
        Test.startTest();
        CandidateDocumentService.updateResumeLink(cand.Id, '123DriveId');
        Test.stopTest();
    } catch (AuraHandledException e) {
        exceptionThrown = true;
        System.debug('DML Exception Message: ' + e.getMessage());
        System.assert(
    e.getMessage().contains('Failed to update Resume Link') ||
    e.getMessage().contains('Script-thrown exception'),
    'Expected DML exception message'
);

    }
    System.assert(exceptionThrown, 'Expected AuraHandledException for DML failure');
}



}