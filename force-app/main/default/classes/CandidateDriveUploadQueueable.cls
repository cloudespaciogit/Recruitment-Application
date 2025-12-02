/**
* @File Name : CandidateDriveUploadQueueable.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : November 25, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 25, 2025 |   | Initial Version
**/

public class CandidateDriveUploadQueueable implements Queueable, Database.AllowsCallouts {
    private Id contentVersionId;
    private Id candidateId;

    public CandidateDriveUploadQueueable(Id contentVersionId, Id candidateId) {
        this.contentVersionId = contentVersionId;
        this.candidateId = candidateId;
    }

    public void execute(QueueableContext ctx) {
        try {
            if (contentVersionId == null || candidateId == null) {
                System.debug('Missing ids in CandidateDriveUploadQueueable');
                return;
            }

            // Query ContentVersion (VersionData available here)
            ContentVersion cv = [
                SELECT Id, ContentDocumentId, Title, PathOnClient, FileExtension, VersionData
                FROM ContentVersion
                WHERE Id = :contentVersionId
                LIMIT 1
            ];

            if (cv == null) {
                System.debug('ContentVersion not found: ' + contentVersionId);
                return;
            }

            // Query candidate for Name to build folder name
            Candidate__c cand = [SELECT Id, Name FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
            if (cand == null) {
                System.debug('Candidate not found: ' + candidateId);
                return;
            }

            // Build folder name exactly as requested: <CandidateName>_<RecordId>
            String safeName = (String.isBlank(cand.Name) ? 'Candidate' : cand.Name).replaceAll('[^A-Za-z0-9 _-]', '');
            String folderName = safeName + '_' + candidateId;

            // Build upload file name: keep "Resume" + extension if available
            String ext = String.isBlank(cv.PathOnClient) ? cv.FileExtension : (cv.PathOnClient.contains('.') ? '.' + cv.PathOnClient.substringAfterLast('.') : (String.isBlank(cv.FileExtension) ? '' : '.' + cv.FileExtension));
            String driveFileName = 'Resume' + ext;

            // Base64 encode VersionData
            String base64Body = EncodingUtil.base64Encode(cv.VersionData);

            // Mime type inference
            String mimeType = 'application/octet-stream';
            String lowerExt = ext != null && ext.startsWith('.') ? ext.substring(1).toLowerCase() : '';
            if (lowerExt == 'pdf') mimeType = 'application/pdf';
            else if (lowerExt == 'doc') mimeType = 'application/msword';
            else if (lowerExt == 'docx') mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            else if (lowerExt == 'png') mimeType = 'image/png';
            else if (lowerExt == 'jpg' || lowerExt == 'jpeg') mimeType = 'image/jpeg';

            // Use CandidateDocumentService.uploadFileToDrive(folder-specific logic exists there)
            // The service expects: (fileName, base64Data, mimeType, recordId)
            // It internally reads custom metadata for Named Credential & parent folder and will create/get the folder.
            String driveFileId = CandidateDocumentService.uploadFileToDrive(driveFileName, base64Body, mimeType, candidateId);

            System.debug('Drive file id returned: ' + driveFileId);

            // Update Candidate with Drive link
            CandidateDocumentService.updateResumeLink(candidateId, driveFileId);

            // OPTIONAL: if you want to add a ContentDocumentLink from ContentDocument to Candidate (should already exist via FirstPublishLocationId),
            // ensure the file is linked correctly. Usually FirstPublishLocationId creates the link automatically.

        } catch (Exception ex) {
            System.debug('CandidateDriveUploadQueueable error: ' + ex.getMessage());
            // Optionally persist to a custom log record for later retry by admin
        }
    }
}