public with sharing class PdfSaveController {

    // Send PDF to Candidate as email Attachment
   @AuraEnabled
    public static void sendpdf(String woId, String pdfData, String fileName) {

        // Decode base64 to Blob
        Blob pdfBlob = EncodingUtil.base64Decode(pdfData);

        // Create email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

        // ---- Set Email Parameters ----
        // Fetch recipient email (example: owner's email of the record)
        Work_Order__c wo = [SELECT Candidate__r.Name, Candidate__r.Email__c FROM Work_Order__c WHERE Id = :woId LIMIT 1];
        String toAddress = wo.Candidate__r.Email__c;

        email.setToAddresses(new String[]{ toAddress });

        email.setSubject('Your PDF Document - ' + fileName);

        email.setPlainTextBody(
            'Hello,' + wo.Candidate__r.Name +
            '\n\nPlease find the attached aggrement form PDF workorder. Send a signed copy of this document to us.' +            
            '\n\nThanks & Regards,' +
            '\nYour Company'
        );

        // ---- Create Attachment for Email ----
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(fileName);
        attachment.setBody(pdfBlob);
        attachment.setContentType('application/pdf');

        email.setFileAttachments(new Messaging.EmailFileAttachment[]{ attachment });

        // ---- Send Email ----
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });

        System.debug('📧 Email with PDF sent successfully.');
    }
    
    @AuraEnabled
    public static Work_Order__c getcandidate(Id woId) {
        Work_Order__c wo = [
            SELECT Id,
                Candidate__r.Name,
                Project__r.Client__r.Name,
                Project__r.Client__r.Phone__c,
                Project__r.Client__r.Email__c,
                Project__r.Client__r.Website__c,
                Project__r.Client__r.Address__Street__s,
                Project__r.Client__r.Address__City__s,
                Project__r.Client__r.Address__PostalCode__s,
                Project__r.Client__r.Address__StateCode__s,
                Project__r.Client__r.Address__CountryCode__s,
                Project__r.Project_Manager__c,
                Name
            FROM Work_Order__c
            WHERE Id = :woId
        ];
        return wo;
    }
}