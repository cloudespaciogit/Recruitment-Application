/*
 #####################################################
 # Created By (Date)   : Shivam Shivhare (Dec, 2025)
 # Description         : Queueable Apex to upload Candidate Resume
 #                       to Google Drive using Named Credential.
 #                       - Creates candidate-specific folder
 #                       - Uploads resume file
 #                       - Updates resume link on Candidate record
 #
 # Modifications Log   :
 * Ver    Date              Author         Modification
 * 1.0    Dec, 2025         Admin          Initial Version
 #####################################################
*/
public class CandidateDriveUploadQueueable implements Queueable, Database.AllowsCallouts {

    /* ==================================================================================
     * Member Variables
     * ==================================================================================
     */

    private Id candidateId;
    private String fileName;
    private String contentType;
    private String base64Data;

     /* ==================================================================================
     * Test Flags
     * Purpose: Used to force failure scenarios in test classes
     * ==================================================================================
     */
	@TestVisible
private static Boolean TEST_FORCE_NULL_PARENTFOLDER = false;

@TestVisible
private static Boolean TEST_FORCE_NULL_NAMEDCRED = false;

     /* ==================================================================================
     * Constructor
     * Purpose: Initialize Queueable with candidate & file details
     * ==================================================================================
     */

    public CandidateDriveUploadQueueable(Id candidateId, String fileName, String contentType, String base64Data) {
        this.candidateId = candidateId;
        this.fileName = fileName;
        this.contentType = contentType;
        this.base64Data = base64Data;
    }

        /* ==================================================================================
     * Method: execute
     * Purpose: Main Queueable execution method
     *          - Validate inputs
     *          - Fetch Candidate
     *          - Resolve Google Drive parent folder
     *          - Create candidate folder
     *          - Upload resume
     *          - Update resume link on Candidate
     * ==================================================================================
     */
    public void execute(QueueableContext ctx) {
        System.debug('================ QUEUEABLE START ================');
        System.debug('candidateId = ' + candidateId);
        System.debug('fileName = ' + fileName);
        System.debug('contentType = ' + contentType);
        System.debug('base64 len = ' + (base64Data != null ? String.valueOf(base64Data.length()) : 'NULL'));

        String summary = ''; 

        try {
            if (candidateId == null) {
                System.debug('No candidate id, aborting');
                return;
            }

            Candidate__c cand = [SELECT Id, Name FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
            summary += '\nCandidate Loaded OK';

            String parentFolderId = getParentFolderId();
            summary += '\nParentFolderId = ' + parentFolderId;
            if (String.isBlank(parentFolderId)) {
                summary += '\n❌ Parent folder id missing';
                System.debug(summary);
                return;
            }

            String namedCredential = getNamedCredential();
            summary += '\nNamedCred = ' + namedCredential;
            if (String.isBlank(namedCredential)) {
                summary += '\n❌ Named Credential missing';
                System.debug(summary);
                return;
            }

            String safeName = (cand.Name != null ? cand.Name : 'Candidate').replaceAll('[^A-Za-z0-9 _-]', '');
            String folderName = safeName + '_' + candidateId;
            summary += '\nFolderName = ' + folderName;

            String folderId = getOrCreateFolder(folderName, parentFolderId, namedCredential);
            summary += '\nFolderId = ' + folderId;
            if (String.isBlank(folderId)) {
                summary += '\n❌ Folder creation FAILED';
                System.debug(summary);
                return;
            }

            String mime = contentType;
            if (String.isBlank(mime)) {
                String lower = (fileName == null ? '' : fileName.toLowerCase());
                if (lower.endsWith('.pdf')) mime = 'application/pdf';
                else if (lower.endsWith('.docx')) mime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
                else if (lower.endsWith('.doc')) mime = 'application/msword';
                else mime = 'application/octet-stream';
            }
            summary += '\nMime = ' + mime;

            // Force file name to 'Resume.ext'
            String ext = '';
            if (fileName != null && fileName.contains('.')) {
                ext = fileName.substringAfterLast('.');
            } else if (mime.contains('pdf')) ext = 'pdf';
            else if (mime.contains('word')) ext = 'doc';
            else ext = 'bin';
            String finalFileName = 'Resume.' + ext;

            String driveFileId = uploadMultipart(folderId, finalFileName, base64Data, mime, namedCredential);
            summary += '\nDriveFileId = ' + driveFileId;

            if (String.isBlank(driveFileId)) {
                summary += '\n❌ Upload FAILED';
                System.debug(summary);
                return;
            }

            updateResumeLink(candidateId, driveFileId);
            summary += '\n✔ Resume Link Updated';

        } catch (Exception e) {
            summary += '\n💥 FINAL ERROR: ' + e.getMessage();
            System.debug('Queueable error: ' + e);
        }

        System.debug('================ SUMMARY ================ ' + summary);
        System.debug('================ QUEUEABLE END ================');
    }

    /* ==================================================================================
     * Method: getNamedCredential
     * Purpose: Fetch Google Drive Named Credential from Custom Metadata
     * Returns: Named Credential name
     * ==================================================================================
     */
    private static String getNamedCredential() {
    try {
        if (TEST_FORCE_NULL_NAMEDCRED) return null;

        Google_Drive_Parent_Folder__mdt md =
            [SELECT Named_Credential__c FROM Google_Drive_Parent_Folder__mdt LIMIT 1];
        return md.Named_Credential__c;
    } catch (Exception e) {
        System.debug('getNamedCredential error: ' + e.getMessage());
        return null;
    }
}

    /* ==================================================================================
     * Method: getParentFolderId
     * Purpose: Fetch Google Drive Parent Folder Id from Custom Metadata
     * Returns: Parent Folder Id
     * ==================================================================================
     */

    private static String getParentFolderId() {
    try {
        if (TEST_FORCE_NULL_PARENTFOLDER) return null;

        Google_Drive_Parent_Folder__mdt md =
            [SELECT Parent_Folder_ID__c FROM Google_Drive_Parent_Folder__mdt LIMIT 1];
        return md.Parent_Folder_ID__c;
    } catch (Exception e) {
        System.debug('getParentFolderId error: ' + e.getMessage());
        return null;
    }
}

    /* ==================================================================================
     * Method: getOrCreateFolder
     * Purpose: Fetch existing folder or create new folder in Google Drive
     * ==================================================================================
     */
    private static String getOrCreateFolder(String folderName, String parentFolderId, String namedCredential) {
        Http http = new Http();
        try {
            String query = 'name = \'' + folderName + '\' and mimeType = \'application/vnd.google-apps.folder\' and \'' + parentFolderId + '\' in parents and trashed = false';
            String encoded = EncodingUtil.urlEncode(query, 'UTF-8');

            HttpRequest searchReq = new HttpRequest();
            searchReq.setEndpoint('callout:' + namedCredential + '/drive/v3/files?q=' + encoded);
            searchReq.setMethod('GET');

            HttpResponse searchRes = http.send(searchReq);
            System.debug('Folder search response status=' + (searchRes==null?'null':searchRes.getStatus()) + ' body=' + (searchRes==null?'':searchRes.getBody()));
            if (searchRes != null && (searchRes.getStatusCode() == 200)) {
                Map<String,Object> r = (Map<String,Object>) JSON.deserializeUntyped(searchRes.getBody());
                List<Object> files = (List<Object>) r.get('files');
                if (files != null && !files.isEmpty()) return (String)((Map<String,Object>)files.get(0)).get('id');
            }

            // create folder
            HttpRequest createReq = new HttpRequest();
            createReq.setEndpoint('callout:' + namedCredential + '/drive/v3/files');
            createReq.setMethod('POST');
            createReq.setHeader('Content-Type', 'application/json');
            createReq.setBody(JSON.serialize(new Map<String,Object>{ 'name' => folderName, 'mimeType' => 'application/vnd.google-apps.folder', 'parents' => new List<String>{ parentFolderId } }));

            HttpResponse createRes = http.send(createReq);
            System.debug('Folder create response status=' + (createRes==null?'null':createRes.getStatus()) + ' body=' + (createRes==null?'':createRes.getBody()));
            if (createRes != null && (createRes.getStatusCode() == 200 || createRes.getStatusCode() == 201)) {
                Map<String,Object> r2 = (Map<String,Object>) JSON.deserializeUntyped(createRes.getBody());
                return (String) r2.get('id');
            }
        } catch (Exception e) {
            System.debug('getOrCreateFolder ERROR: ' + e.getMessage());
        }
        return null;
    }

    /* ==================================================================================
     * Method: uploadMultipart
     * Purpose: Upload file to Google Drive using multipart upload
     * ==================================================================================
     */
    private static String uploadMultipart(String folderId, String fileName, String base64Data, String mimeType, String namedCredential) {
        try {
            String endpoint = 'callout:' + namedCredential + '/upload/drive/v3/files?uploadType=multipart';
            Map<String,Object> metadata = new Map<String,Object>{ 'name' => fileName, 'parents' => new List<String>{ folderId } };
            String metadataJson = JSON.serialize(metadata);
            String boundary = 'CandidateBoundary' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
            String bodyStart = '--' + boundary + '\r\n' + 'Content-Type: application/json; charset=UTF-8\r\n\r\n' + metadataJson + '\r\n' + '--' + boundary + '\r\n' + 'Content-Type: ' + mimeType + '\r\n' + 'Content-Transfer-Encoding: base64\r\n\r\n';
            String bodyEnd = '\r\n--' + boundary + '--';
            String fullBody = bodyStart + base64Data + bodyEnd;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'multipart/related; boundary=' + boundary);
            req.setBody(fullBody);

            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('Upload response status=' + (res==null?'null':res.getStatus()) + ' body=' + (res==null?'':res.getBody()));
            if (res != null && (res.getStatusCode() == 200 || res.getStatusCode() == 201)) {
                Map<String,Object> parsed = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
                return (String) parsed.get('id');
            }
        } catch (Exception e) {
            System.debug('uploadMultipart ERROR: ' + e.getMessage());
        }
        return null;
    }

    /* ==================================================================================
     * Method: updateResumeLink
     * Purpose: Update Resume link on Candidate record
     * ==================================================================================
     */

    private static void updateResumeLink(Id candidateId, String driveFileId) {
        try {
            String link = 'https://drive.google.com/file/d/' + driveFileId + '/view';
            update new Candidate__c(Id = candidateId, Resume_Link__c = link);
        } catch (Exception e) {
            System.debug('updateResumeLink ERROR: ' + e.getMessage());
        }
    }
}