declare module "@salesforce/apex/SupplierCandidateController.getMyCandidatesBySearch" {
  export default function getMyCandidatesBySearch(param: {searchKey: any}): Promise<any>;
}
declare module "@salesforce/apex/SupplierCandidateController.getNoticePeriodPicklistValues" {
  export default function getNoticePeriodPicklistValues(): Promise<any>;
}
declare module "@salesforce/apex/SupplierCandidateController.updateCandidateFields" {
  export default function updateCandidateFields(param: {candidateId: any, newNoticeValue: any, newExpectedRate: any}): Promise<any>;
}
declare module "@salesforce/apex/SupplierCandidateController.createInterviews" {
  export default function createInterviews(param: {candidateIds: any, jobPositionId: any}): Promise<any>;
}
