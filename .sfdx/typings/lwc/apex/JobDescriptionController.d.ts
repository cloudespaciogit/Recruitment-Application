declare module "@salesforce/apex/JobDescriptionController.getJobDetails" {
  export default function getJobDetails(param: {jobId: any}): Promise<any>;
}
declare module "@salesforce/apex/JobDescriptionController.generateJobDescription" {
  export default function generateJobDescription(param: {jobId: any, skillsData: any, additional: any, qualification: any, experience: any, soft: any, tone: any, length: any, lengthsize: any}): Promise<any>;
}
declare module "@salesforce/apex/JobDescriptionController.saveJobDescription" {
  export default function saveJobDescription(param: {jobId: any, description: any}): Promise<any>;
}
