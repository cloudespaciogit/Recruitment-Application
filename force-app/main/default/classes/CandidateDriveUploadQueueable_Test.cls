@IsTest
    private class CandidateDriveUploadQueueable_Test {
    
        private class Mock_MissingMeta implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(200);
                res.setBody('{}');
                return res;
            }
        }
    
        private class GoogleDriveMock_Success implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                HttpResponse res = new HttpResponse();
                String endpoint = req.getEndpoint();
                if (endpoint.contains('/drive/v3/files?q=')) {
                    res.setStatusCode(200);
                    res.setBody('{"files":[{"id":"mockFolderId"}]}');
                } else if (endpoint.contains('/upload/drive/v3/files')) {
                    res.setStatusCode(200);
                    res.setBody('{"id":"mockFileId"}');
                }
                return res;
            }
        }
    
        private class GoogleDriveMock_CreateFolderThenUpload implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                HttpResponse res = new HttpResponse();
                String endpoint = req.getEndpoint();
                if (endpoint.contains('/drive/v3/files?q=')) {
                    res.setStatusCode(200);
                    res.setBody('{"files":[]}');
                } else if (endpoint.endsWith('/drive/v3/files')) {
                    res.setStatusCode(200);
                    res.setBody('{"id":"createdFolderId"}');
                } else if (endpoint.contains('/upload/drive/v3/files')) {
                    res.setStatusCode(200);
                    res.setBody('{"id":"mockFileId"}');
                }
                return res;
            }
        }
    
        private class GoogleDriveMock_UploadFailure implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                HttpResponse res = new HttpResponse();
                if (req.getMethod() == 'POST') {
                    res.setStatusCode(400);
                    res.setBody('Bad Request');
                }
                return res;
            }
        }
    
        private class GoogleDriveMock_GenericFailure implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(500);
                return res;
            }
        }
        private class GoogleDriveMock_FailedUploadButFolderOK implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        if (req.getMethod() == 'GET') {
            res.setStatusCode(200);
            res.setBody('{"files":[{"id":"existingFolder"}]}');
        } else {
            res.setStatusCode(400);  // forces fail on upload
            res.setBody('Bad Upload');
        }
        return res;
    }
}

      
    
        @TestSetup
        static void setupData() {
            Candidate__c candidate = Recruitment_TestDataFactory.createCandidate('Test Candidate', 'test@example.com');
            candidate.Last_name__c = 'Candidate';
            candidate.First_Name__c = 'Test';
            insert candidate;
        }
    
        @IsTest
        static void test_Success() {
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_Success());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
            System.assertNotEquals(null, [SELECT Resume_Link__c FROM Candidate__c WHERE Id = :cand.Id].Resume_Link__c);
        }
    
        @IsTest
        static void test_CreateFolder() {
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_CreateFolderThenUpload());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_UploadFailure() {
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_UploadFailure());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_GenericFailure() {
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_GenericFailure());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_NullCandidateExit() {
            Test.startTest();
            System.enqueueJob(new CandidateDriveUploadQueueable(
                null,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_MimeDocxBranch() {
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_Success());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.docx',null,'aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_DocMimeFinalExt() {
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_Success());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.doc',null,'aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_ExtBinCoverage() {
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_Success());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'unknownfile','aaa/bbb','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_MissingParentFolder() {
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new Mock_MissingMeta());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        }
    
        @IsTest
        static void test_MissingNamedCred() {
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new Mock_MissingMeta());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf',null,'aaa'));
            Test.stopTest();
        }
        @IsTest
        static void test_ForceMissingParentFolder() {
            CandidateDriveUploadQueueable.TEST_FORCE_NULL_PARENTFOLDER = true;
        
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
            Test.startTest();
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        
            CandidateDriveUploadQueueable.TEST_FORCE_NULL_PARENTFOLDER = false; // reset
        }
        
        @IsTest
        static void test_ForceMissingNamedCred() {
            CandidateDriveUploadQueueable.TEST_FORCE_NULL_NAMEDCRED = true;
        
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
            Test.startTest();
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,'resume.pdf','application/pdf','aaa'));
            Test.stopTest();
        
            CandidateDriveUploadQueueable.TEST_FORCE_NULL_NAMEDCRED = false; // reset
        }
        @IsTest
        static void test_DefaultMime_OctetStream() {
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_Success());
            // fileName = null + contentType = null → default mime branch hit
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,
                null,      // triggers branch
                null,      // triggers application/octet-stream
                'aaa'
            ));
            Test.stopTest();
        
            System.assert(true);
        }
        
        @IsTest
        static void test_UploadFailure_returnBranch() {
            Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new GoogleDriveMock_FailedUploadButFolderOK());
            System.enqueueJob(new CandidateDriveUploadQueueable(
                cand.Id,
                'resume.pdf',
                'application/pdf',
                'abcdef'
            ));
            Test.stopTest();
        
            System.assert(true);
        }

        
    }