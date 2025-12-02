/*
##################################################### 
# Created By (Date)   : Shivam Shivhare (02 Sep, 2025)
# Description         : Service class for handling Google Drive operations 
#                       (upload, fetch, delete) for record-specific documents.
# Modifications Log   : 
* Ver    Date              Author                   Modification
* 1.0    02 Sep, 2025      Shivam Shivhare          Initial Version
#####################################################
*/


public with sharing class CandidateDocumentService {

     private static String NAMED_CREDENTIAL = getNamedCredential();
	@TestVisible private static String TEST_parentFolderId;


     private static String getNamedCredential() {
        try {
            Google_Drive_Parent_Folder__mdt md = [
                SELECT Named_Credential__c 
                FROM Google_Drive_Parent_Folder__mdt 
                LIMIT 1
            ];
            return md.Named_Credential__c;
        } catch (Exception e) {
            System.debug('Error fetching Named Credential: ' + e.getMessage());
            return 'GoogleDriveNC'; 
        }
    }

    /* ==================================================================================
    * Method : uploadFileToDrive
    * Purpose: Upload a file to Google Drive inside a record-specific folder.
    * Params : 
    *   - fileName       : Name of the file.
    *   - base64Data     : File data encoded in base64.
    *   - mimeType       : MIME type of the file.
    *   - recordId       : Salesforce record Id (Candidate, Project, etc.).
    *   - objectApiName  : API name of the object.
    * Returns: Google Drive file Id of the uploaded file.
    *================================================================================== 
    */
    @AuraEnabled
    public static String uploadFileToDrive(String fileName, String base64Data, String mimeType, Id recordId) {
        try {
             Candidate__c cand = [SELECT Name FROM Candidate__c WHERE Id = :recordId LIMIT 1];
            String recordName = cand.Name;
            
            String folderName = recordName + '_' + recordId;

            // Fetch Parent Folder ID
         
            String parentFolderId;
            
            if (TEST_parentFolderId != null) {
                parentFolderId = TEST_parentFolderId;
            } else {
                Google_Drive_Parent_Folder__mdt parentFolderMetadata = [
                    SELECT Parent_Folder_ID__c 
                    FROM Google_Drive_Parent_Folder__mdt 
                    LIMIT 1
                ];
                parentFolderId = parentFolderMetadata.Parent_Folder_ID__c;
            }

            if (String.isBlank(parentFolderId)) {
                throw new AuraHandledException('Parent Folder ID is not configured in Custom Metadata.');
            }

            // Create/Get folder + Upload
            String folderId = getOrCreateFolder(folderName, parentFolderId);
            return uploadMultipart(folderId, fileName, base64Data, mimeType);

        } catch (Exception e) {
            System.debug('Error in uploadFileToDrive: ' + e.getMessage());
            throw new AuraHandledException('File upload failed: ' + e.getMessage());
        }
    }

    /* ==================================================================================
    * Method : getOrCreateFolder
    * Purpose: Ensure a record-specific folder exists under parent and return its ID.
    * Params : 
    *   - folderName     : Name of the folder to create/search.
    *   - parentFolderId : Parent Google Drive folder Id.
    * Returns: Folder Id in Google Drive.
    * ================================================================================== 
    */
    private static String getOrCreateFolder(String folderName, String parentFolderId) {
        String folderId;
        Http http = new Http();

        try {
            // Step 1: Build the query
            String query = 'name = \'' + folderName + '\' and mimeType = \'application/vnd.google-apps.folder\' and \'' + parentFolderId + '\' in parents and trashed = false';
            String encodedQuery = EncodingUtil.urlEncode(query, 'UTF-8');

            // Step 2: Search for the folder
            HttpRequest searchReq = new HttpRequest();
            searchReq.setEndpoint('callout:' + NAMED_CREDENTIAL + '/drive/v3/files?q=' + encodedQuery);
            searchReq.setMethod('GET');
            HttpResponse searchRes = http.send(searchReq);

            if (searchRes.getStatusCode() == 200) {
                Map<String, Object> searchResult = (Map<String, Object>) JSON.deserializeUntyped(searchRes.getBody());
                List<Object> files = (List<Object>) searchResult.get('files');

                if (!files.isEmpty()) {
                    folderId = (String)((Map<String, Object>)files[0]).get('id');
                    return folderId;
                }
            }

            // Step 3: If not found, create new folder
            HttpRequest createReq = new HttpRequest();
            createReq.setEndpoint('callout:' + NAMED_CREDENTIAL + '/drive/v3/files');
            createReq.setMethod('POST');
            createReq.setHeader('Content-Type', 'application/json');

            String body = JSON.serialize(new Map<String, Object>{
                'name' => folderName,
                'mimeType' => 'application/vnd.google-apps.folder',
                'parents' => new List<String>{ parentFolderId }
            });
            createReq.setBody(body);

            HttpResponse createRes = http.send(createReq);
            if (createRes.getStatusCode() == 200 || createRes.getStatusCode() == 201) {
                Map<String, Object> createResult = (Map<String, Object>) JSON.deserializeUntyped(createRes.getBody());
                folderId = (String) createResult.get('id');
            } else {
                throw new CalloutException('Failed to create folder. Response: ' + createRes.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in getOrCreateFolder: ' + e.getMessage());
            throw new AuraHandledException('Error creating/getting folder: ' + e.getMessage());
        }

        return folderId;
    }

    /* ==================================================================================
    * Method : uploadMultipart
    * Purpose: Upload the file into the given folder using multipart request.
    * Params : 
    *   - candidateFolderId : Folder Id in Google Drive where file will be uploaded.
    *   - fileName          : Name of the file.
    *   - base64Data        : Base64 encoded data of the file.
    *   - mimeType          : MIME type of the file.
    * Returns: Uploaded file Id in Google Drive.
    * ================================================================================== 
    */

    private static String uploadMultipart(String candidateFolderId, String fileName, String base64Data, String mimeType) {
        try {
            String endpoint = 'callout:' + NAMED_CREDENTIAL + '/upload/drive/v3/files?uploadType=multipart';

            // File metadata
            Map<String, Object> metadata = new Map<String, Object>{
                'name' => fileName,
                'parents' => new List<String>{ candidateFolderId }
            };

            String metadataJson = JSON.serialize(metadata);
            String boundary = 'CandidateDocBoundary';

            String bodyStart = '--' + boundary + '\r\n'
                + 'Content-Type: application/json; charset=UTF-8\r\n\r\n'
                + metadataJson + '\r\n'
                + '--' + boundary + '\r\n'
                + 'Content-Type: ' + mimeType + '\r\n'
                + 'Content-Transfer-Encoding: base64\r\n\r\n';

            String bodyEnd = '\r\n--' + boundary + '--';

            String fullBody = bodyStart + base64Data + bodyEnd;

            // HTTP Request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'multipart/related; boundary=' + boundary);
            req.setBody(fullBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) result.get('id');
            } else {
                throw new CalloutException('Upload failed. Status: ' + res.getStatus() + ' Body: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in uploadMultipart: ' + e.getMessage());
            throw new AuraHandledException('File upload failed: ' + e.getMessage());
        }
    }

    /* ==================================================================================
    * Method : getFiles
    * Purpose: Get all files of a record from Google Drive.
    * Params : 
    *   - recordId      : Salesforce record Id (Candidate, Project, etc.).
    *   - objectApiName : API name of the object.
    * Returns: List of file metadata maps from Google Drive.
    * ================================================================================== 
    */

    @AuraEnabled
    public static List<Map<String, Object>> getFiles(Id recordId) {
        try {
            Candidate__c cand = [SELECT Name FROM Candidate__c WHERE Id = :recordId LIMIT 1];
            String recordName = cand.Name;
            String folderName = recordName + '_' + recordId;

            String parentFolderId = [SELECT Parent_Folder_ID__c FROM Google_Drive_Parent_Folder__mdt LIMIT 1].Parent_Folder_ID__c;

            Http http = new Http();

            // Search for candidate folder
            String folderQuery = 'mimeType = \'application/vnd.google-apps.folder\' and name = \'' + folderName 
                                 + '\' and \'' + parentFolderId + '\' in parents and trashed = false';

            HttpRequest folderReq = new HttpRequest();
            folderReq.setEndpoint('callout:' + NAMED_CREDENTIAL + '/drive/v3/files?q=' + EncodingUtil.urlEncode(folderQuery, 'UTF-8'));
            folderReq.setMethod('GET');

            HttpResponse folderRes = http.send(folderReq);
            if (folderRes.getStatusCode() != 200) {
                throw new CalloutException('Failed to search candidate folder: ' + folderRes.getBody());
            }

            Map<String, Object> folderResult = (Map<String, Object>) JSON.deserializeUntyped(folderRes.getBody());
            List<Object> folderFiles = (List<Object>) folderResult.get('files');

            if (folderFiles.isEmpty()) {
                return new List<Map<String, Object>>();
            }

            String folderId = (String) ((Map<String, Object>) folderFiles[0]).get('id');

            // Fetch all files
            String fileQuery = '\'' + folderId + '\' in parents and trashed = false';
            HttpRequest fileReq = new HttpRequest();
            fileReq.setEndpoint(
                'callout:' + NAMED_CREDENTIAL + 
                '/drive/v3/files?q=' + EncodingUtil.urlEncode(fileQuery, 'UTF-8') +
                '&fields=files(id,name,mimeType,size,createdTime,modifiedTime)'
            );
            fileReq.setMethod('GET');

            HttpResponse fileRes = http.send(fileReq);
            if (fileRes.getStatusCode() != 200) {
                throw new CalloutException('Failed to fetch files: ' + fileRes.getBody());
            }

            Map<String, Object> fileResult = (Map<String, Object>) JSON.deserializeUntyped(fileRes.getBody());
            List<Object> files = (List<Object>) fileResult.get('files');

            List<Map<String, Object>> fileList = new List<Map<String, Object>>();
            for (Object f : files) {
                fileList.add((Map<String, Object>) f);
            }

            return fileList;

        } catch (Exception e) {
            System.debug('Error in getFiles: ' + e.getMessage());
            throw new AuraHandledException('Error fetching files: ' + e.getMessage());
        }
    }

    /* ==================================================================================
    * Method : deleteFileFromDrive
    * Purpose: Delete a file from Google Drive.
    * Params : 
    *   - fileId : Google Drive file Id.
    * Returns: Success message if file is deleted.
    * ================================================================================== 
    */

    @AuraEnabled
    public static String deleteFileFromDrive(String fileId) {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + NAMED_CREDENTIAL + '/drive/v3/files/' + fileId);
            req.setMethod('DELETE');

            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 204) {
                return 'File deleted successfully';
            } else {
                throw new CalloutException('Failed to delete file. Status: ' + res.getStatus() + ' Body: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in deleteFileFromDrive: ' + e.getMessage());
            throw new AuraHandledException('File delete failed: ' + e.getMessage());
        }
    }

   /* ==================================================================================
    * Method : updateResumeLink
    * Purpose: Update resume field of candidate record .
    * Params : 
    *   - candidateId : recordId.
        - driveFileId : Id Of drive file.
    * ================================================================================== 
    */
    @AuraEnabled
public static void updateResumeLink(Id candidateId, String driveFileId) {
    if (candidateId == null) {
        throw new AuraHandledException('Candidate Id is required.');
    }

    try {
        Candidate__c cand;
        if (driveFileId == null) {
            // Delete case: Resume field 
            cand = new Candidate__c(Id = candidateId, Resume_Link__c = null);
        } else {
            // Upload case: Resume link
            String driveLink = 'https://drive.google.com/file/d/' + driveFileId + '/view';
            cand = new Candidate__c(Id = candidateId, Resume_Link__c = driveLink);
        }
        update cand;

    } catch (DmlException dmlEx) {
        // Ensure message is never null
        String msg = (dmlEx.getMessage() != null) ? dmlEx.getMessage() : 'Unknown DML error';
        throw new AuraHandledException('Failed to update Resume Link: ' + msg);

    } catch (Exception ex) {
        // Ensure message is never null
        String msg = (ex.getMessage() != null) ? ex.getMessage() : 'Unknown error';
        throw new AuraHandledException('Unexpected error: ' + msg);
    }
}


}