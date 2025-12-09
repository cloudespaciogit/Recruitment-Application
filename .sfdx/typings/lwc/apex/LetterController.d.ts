declare module "@salesforce/apex/LetterController.getLetterData" {
  export default function getLetterData(param: {recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/LetterController.createPdfAndSendEmail" {
  export default function createPdfAndSendEmail(param: {htmlContent: any, recordId: any}): Promise<any>;
}
