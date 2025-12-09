declare module "@salesforce/apex/SubmitCandidateController.getAllClients" {
  export default function getAllClients(): Promise<any>;
}
declare module "@salesforce/apex/SubmitCandidateController.getJobPositionsByClient" {
  export default function getJobPositionsByClient(param: {clientId: any}): Promise<any>;
}
declare module "@salesforce/apex/SubmitCandidateController.getCandidateForClient" {
  export default function getCandidateForClient(param: {candidateId: any, clientId: any}): Promise<any>;
}
declare module "@salesforce/apex/SubmitCandidateController.getMultipleCandidatesForClient" {
  export default function getMultipleCandidatesForClient(param: {candidateIds: any, clientId: any}): Promise<any>;
}
declare module "@salesforce/apex/SubmitCandidateController.sendCandidateExcelEmail" {
  export default function sendCandidateExcelEmail(param: {candidateIds: any, clientId: any, jobId: any}): Promise<any>;
}
