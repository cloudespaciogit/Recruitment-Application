/**
* @File Name : CandidatePublicController.cls
* @Description :
* @Author : Ashish kumar
* @Last Modified By :
* @Last Modified On : November 24, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 24, 2025 |   | Initial Version
**/

public with sharing class CandidatePublicController {

    public class CandidateResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id candidateId;
    }

    @AuraEnabled(cacheable=false)
    public static CandidateResponse submitCandidateForm(
        String firstName,
        String lastName,
        String email,
        String phone,
        Decimal experienceYears,
        String skills,
        String currentCompany,
        String jobTitle,
        Decimal expectedSalary,
        String noticePeriod,
        String recaptchaToken,
        String resumeFileName,
        String resumeContentType,
        String resumeBase64Body
    ) {
        CandidateResponse resp = new CandidateResponse();
        resp.success = false;

        // Basic server-side validation
        if (String.isBlank(firstName) || String.isBlank(lastName) ||
            String.isBlank(email) || String.isBlank(phone)) {
            resp.message = 'Required fields are missing.';
            return resp;
        }

        // Duplicate email check
        if (!String.isBlank(email)) {
            List<Candidate__c> dup = [SELECT Id FROM Candidate__c WHERE Email__c = :email LIMIT 1];
            if (!dup.isEmpty()) {
                resp.message = 'Email already exists. Please use a different email address.';
                return resp;
            }
        }

        // 1) Insert Candidate record
        Candidate__c cand = new Candidate__c();
        cand.First_Name__c      = firstName;
        cand.Last_name__c       = lastName;         // change if your org uses different API name
        cand.Email__c           = email;
        cand.Phone__c           = phone;
        cand.Experience_Year__c = experienceYears;
        cand.Skills__c          = skills;
        cand.Current_Company__c = currentCompany;
        cand.Job_Title__c       = jobTitle;
        cand.Expected_CTC__c    = expectedSalary;
        cand.Notice_Period__c   = noticePeriod;
        cand.Source__c          = 'Company Website';  // ensure this value exists in picklist

        try {
            insert cand;
        } catch (DmlException de) {
            resp.message = de.getDmlMessage(0);
            return resp;
        }

        // 2) If resume provided, insert ContentVersion (Files) and enqueue Queueable with ContentVersion.Id
        if (!String.isBlank(resumeBase64Body)) {
            try {
                // Decode base64 and create ContentVersion (VersionData expects Blob)
                Blob fileBlob = EncodingUtil.base64Decode(resumeBase64Body);

                ContentVersion cv = new ContentVersion();
                cv.VersionData = fileBlob;
                cv.PathOnClient = !String.isBlank(resumeFileName) ? resumeFileName : ('Resume-' + cand.Id + '.pdf');
                cv.Title = 'Resume - ' + cand.First_Name__c;
                // Do NOT set ContentType (read-only). Salesforce will infer it.
                // Associate to candidate so ContentDocumentLink will be created automatically
                cv.FirstPublishLocationId = cand.Id;

                insert cv;
                System.debug('ContentVersion inserted: ' + cv.Id);

                // Enqueue a queueable that will read the ContentVersion.VersionData and do the Drive callout
                System.enqueueJob(new CandidateDriveUploadQueueable(cv.Id, cand.Id));

            } catch (Exception ex) {
                // If CV insert fails, we still keep candidate but inform the caller
                System.debug('Error inserting ContentVersion or enqueueing job: ' + ex.getMessage());
                resp.message = 'Application saved but resume upload could not be processed: ' + ex.getMessage();
                resp.candidateId = cand.Id;
                // still return success=true? We'll return success with a warning
                resp.success = true;
                return resp;
            }
        }

        resp.success = true;
        resp.message = 'Application submitted successfully. Resume will be uploaded to Drive shortly.';
        resp.candidateId = cand.Id;
        return resp;
    }
}