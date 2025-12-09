declare module "@salesforce/apex/CustomEmailComposerController.getFromAddresses" {
  export default function getFromAddresses(): Promise<any>;
}
declare module "@salesforce/apex/CustomEmailComposerController.sendEmailNow" {
  export default function sendEmailNow(param: {toAddresses: any, ccAddresses: any, bccAddresses: any, subject: any, htmlBody: any, relatedRecordId: any, fromType: any, fromId: any, fromAddress: any}): Promise<any>;
}
