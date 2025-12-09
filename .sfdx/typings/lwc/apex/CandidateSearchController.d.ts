declare module "@salesforce/apex/CandidateSearchController.searchCandidates" {
  export default function searchCandidates(param: {params: any}): Promise<any>;
}
declare module "@salesforce/apex/CandidateSearchController.getOpenJobPositions" {
  export default function getOpenJobPositions(param: {searchKey: any}): Promise<any>;
}
declare module "@salesforce/apex/CandidateSearchController.assignCandidatesToJobs" {
  export default function assignCandidatesToJobs(param: {candidateIds: any, jobPositionIds: any}): Promise<any>;
}
