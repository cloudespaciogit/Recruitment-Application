declare module "@salesforce/apex/ATSController.getATSData" {
  export default function getATSData(param: {jobPositionId: any}): Promise<any>;
}
declare module "@salesforce/apex/ATSController.updateInterviewStages" {
  export default function updateInterviewStages(param: {interviewIds: any, newStageValue: any}): Promise<any>;
}
declare module "@salesforce/apex/ATSController.removeCandidateFromJob" {
  export default function removeCandidateFromJob(param: {interviewIds: any}): Promise<any>;
}
declare module "@salesforce/apex/ATSController.collectFeedback" {
  export default function collectFeedback(param: {interviewIds: any}): Promise<any>;
}
declare module "@salesforce/apex/ATSController.updateInterviews" {
  export default function updateInterviews(param: {recordIds: any, newStage: any, feedback: any}): Promise<any>;
}
declare module "@salesforce/apex/ATSController.getCandidateIdsFromInterviews" {
  export default function getCandidateIdsFromInterviews(param: {interviewIds: any}): Promise<any>;
}
