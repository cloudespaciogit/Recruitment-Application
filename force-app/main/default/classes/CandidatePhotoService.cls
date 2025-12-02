/*
##################################################### 
# Created By (Date)   : Shivam Shivhare (10 Nov, 2025)
# Description         : Service class to fetch candidate profile photo 
#                       from Google Drive and return it as Base64 for LWC display.
# Modifications Log   : 
* Ver    Date              Author              Modification
* 1.0    10 Nov, 2025      Shivam Shivhare     Initial Version
#####################################################
*/

public with sharing class CandidatePhotoService {

    /* ==================================================================================
    * Method : getCandidateProfilePhotoBase64
    * Purpose: Fetch the "Candidate Photo" file stored in Google Drive inside 
    *           the candidate-specific folder and return it as Base64 string 
    *           for display in Lightning Web Components.
    * Params :
    *   - candidateId : Salesforce record Id of the Candidate.
    * Returns : Base64 string of the image (if found), otherwise null.
    * ================================================================================== 
    */
    
    
    @AuraEnabled(cacheable=true)
    public static String getCandidateProfilePhotoBase64(Id candidateId) {
        try {
            Candidate__c cand = [SELECT Name FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
            String folderName = cand.Name + '_' + candidateId;

            String namedCredential = 'GoogleDriveNC';
            Http http = new Http();

            // Step 1: Search folder
            HttpRequest folderReq = new HttpRequest();
            folderReq.setEndpoint('callout:' + namedCredential + '/drive/v3/files?q=' + 
                EncodingUtil.urlEncode('mimeType=\'application/vnd.google-apps.folder\' and name=\'' + folderName + '\'', 'UTF-8'));
            folderReq.setMethod('GET');

            HttpResponse folderRes = http.send(folderReq);
            if(folderRes.getStatusCode() != 200) return null;

            Map<String,Object> folderResult = (Map<String,Object>)JSON.deserializeUntyped(folderRes.getBody());
            List<Object> folderFiles = (List<Object>)folderResult.get('files');
            if(folderFiles.isEmpty()) return null;

            String folderId = (String)((Map<String,Object>)folderFiles[0]).get('id');

            // Step 2: Fetch files
            HttpRequest fileReq = new HttpRequest();
            fileReq.setEndpoint('callout:' + namedCredential + '/drive/v3/files?q=' + 
                EncodingUtil.urlEncode('\'' + folderId + '\' in parents and trashed=false', 'UTF-8'));
            fileReq.setMethod('GET');

            HttpResponse fileRes = http.send(fileReq);
            if(fileRes.getStatusCode() != 200) return null;

            Map<String,Object> fileResult = (Map<String,Object>)JSON.deserializeUntyped(fileRes.getBody());
            List<Object> files = (List<Object>)fileResult.get('files');

            Map<String,Object> photoFile = null; // <-- initialize to null!
            for(Object fObj : files) {
                Map<String,Object> f = (Map<String,Object>)fObj;
                if(((String)f.get('name')).contains('Candidate Photo')) {
                    photoFile = f; 
                    break;
                }
            }

            if(photoFile == null) return null;

            String fileId = (String)photoFile.get('id');

            // Step 3: Fetch actual file content
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + namedCredential + '/drive/v3/files/' + fileId + '?alt=media');
            req.setMethod('GET');

            HttpResponse res = http.send(req);
            if(res.getStatusCode() == 200) {
                return EncodingUtil.base64Encode(res.getBodyAsBlob());
            }

            return null;

        } catch(Exception e) {
            return null;
        }
    }
}