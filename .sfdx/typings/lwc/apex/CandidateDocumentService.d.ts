declare module "@salesforce/apex/CandidateDocumentService.uploadFileToDrive" {
  export default function uploadFileToDrive(param: {fileName: any, base64Data: any, mimeType: any, recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/CandidateDocumentService.getFiles" {
  export default function getFiles(param: {recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/CandidateDocumentService.deleteFileFromDrive" {
  export default function deleteFileFromDrive(param: {fileId: any}): Promise<any>;
}
declare module "@salesforce/apex/CandidateDocumentService.updateResumeLink" {
  export default function updateResumeLink(param: {candidateId: any, driveFileId: any}): Promise<any>;
}
