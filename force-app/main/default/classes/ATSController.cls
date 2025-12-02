public with sharing class ATSController {

    @AuraEnabled(cacheable=true)
    public static List<Interview__c> getATSData(Id jobPositionId) {
        return [
            SELECT Id,
                   Interview_Status__c,
                   Round__c,
                   Feedback__c,
                   Candidate__r.Resume_Link__c,
                   Candidate__r.Name,
                   Candidate__r.Email__c,
                   Candidate__r.Phone__c,
                   Candidate__r.Current_Location__c,
                   Candidate__r.LastModifiedBy.Name,
                   Job_Position__r.Name,
                   Job_Position__c
            FROM Interview__c
            WHERE Candidate__c != null
              AND Job_Position__c = :jobPositionId
            WITH USER_MODE
        ];
    }

    @AuraEnabled
    public static void updateInterviewStages(List<Id> interviewIds, String newStageValue) {
        if (interviewIds == null || interviewIds.isEmpty() || String.isBlank(newStageValue)) {
            throw new AuraHandledException('Invalid input: Interview IDs and new Stage value are required.');
        }

        List<Interview__c> recordsToUpdate = new List<Interview__c>();
        for (Interview__c interview : [
            SELECT Id FROM Interview__c WHERE Id IN :interviewIds WITH USER_MODE
        ]) {
            interview.Interview_Status__c = newStageValue;
            recordsToUpdate.add(interview);
        }

        if (!recordsToUpdate.isEmpty()) {
            try {
                update as user recordsToUpdate;
            } catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }
        }
    }

    @AuraEnabled
    public static void removeCandidateFromJob(List<Id> interviewIds) {
        if (interviewIds == null || interviewIds.isEmpty()) {
            throw new AuraHandledException('Invalid input: Interview IDs are required.');
        }

        String profileName = [
            SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()
        ].Name;

        if (profileName != 'System Administrator') {
            throw new AuraHandledException('Only admins can delete a record.');
        }

        List<Interview__c> interviewRecords = [
            SELECT Id, Job_Position__c, Candidate__c
            FROM Interview__c
            WHERE Id IN :interviewIds
            WITH USER_MODE
        ];

        if (!interviewRecords.isEmpty()) {
            Set<Id> canIds = new Set<Id>();
            Id jobId;

            for (Interview__c inter : interviewRecords) {
                if (inter.Candidate__c != null) {
                    canIds.add(inter.Candidate__c);
                }
                jobId = inter.Job_Position__c;
            }

            List<Event> eventsToDelete = [
                SELECT Id FROM Event
                WHERE Candidate__c IN :canIds
                AND WhatId = :jobId
                WITH USER_MODE
            ];

            if (!eventsToDelete.isEmpty()) {
                Database.delete(eventsToDelete, AccessLevel.USER_MODE);
            }

            Database.delete(interviewRecords, AccessLevel.USER_MODE);
        }
    }

    @AuraEnabled
    public static void collectFeedback(List<Id> interviewIds) {
        if (interviewIds == null || interviewIds.isEmpty()) {
            throw new AuraHandledException('Invalid input: Interview IDs are required.');
        }

        List<Interview__c> interviewRecords = [
            SELECT Id,
                   Round__c,
                   Candidate__r.Name,
                   Job_Position__r.Client__r.Email__c,
                   Job_Position__r.Job_Title__c,
                   Job_Position__r.Client__r.Name
            FROM Interview__c
            WHERE Id IN :interviewIds
            WITH USER_MODE
        ];

        String orgName = UserInfo.getOrganizationName();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Interview__c intId : interviewRecords) {
            String clientName = intId.Job_Position__r.Client__r.Name;
            String candidateName = intId.Candidate__r.Name;
            String jobPosition = intId.Job_Position__r.Job_Title__c;
            String interviewRound = intId.Round__c;
            String clientEmail = intId.Job_Position__r.Client__r.Email__c;

            Map<String, String> data = new Map<String, String>{
                'clientName'     => clientName,
                'candidateName'  => candidateName,
                'jobPosition'    => jobPosition,
                'interviewRound' => interviewRound,
                'orgName'        => orgName
            };

            String emailBody = EmailBody.feedbackEmailBody(data);
            String emailSubject = 'Feedback Request: Interview with ' + candidateName +
                ' for ' + jobPosition + ' (' + interviewRound + ')';

            if (String.isNotBlank(clientEmail)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { clientEmail });
                mail.setSubject(emailSubject);
                mail.setHtmlBody(emailBody);
                emails.add(mail);
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    /**
     * @description Updates multiple Interview__c records (stage, feedback).
     * New signature — accepts direct parameters (no wrapper).
     */
    @AuraEnabled
    public static void updateInterviews(List<Id> recordIds, String newStage, String feedback) {
        System.debug('🚀 Entered updateInterviews');
        System.debug('🆔 Record Ids: ' + recordIds);
        System.debug('🎯 New Stage: ' + newStage);
        System.debug('💬 Feedback: ' + feedback);

        // Validate inputs and delegate to service
        InterviewService.validateInterviewInputs(recordIds, newStage, feedback);
        List<Interview__c> interviewsToUpdate = InterviewService.prepareInterviewUpdates(recordIds, newStage, feedback);
        InterviewService.saveInterviewRecords(interviewsToUpdate);
    }

    @AuraEnabled(cacheable=true)
    public static List<Id> getCandidateIdsFromInterviews(List<Id> interviewIds) {
        if (interviewIds == null || interviewIds.isEmpty()) {
            throw new AuraHandledException('Interview IDs are required.');
        }

        Set<Id> candidateIds = new Set<Id>();
        for (Interview__c i : [
            SELECT Candidate__c FROM Interview__c
            WHERE Id IN :interviewIds AND Candidate__c != null
            WITH USER_MODE
        ]) {
            candidateIds.add(i.Candidate__c);
        }

        if (candidateIds.isEmpty()) {
            throw new AuraHandledException('No candidates found for selected interviews.');
        }

        return new List<Id>(candidateIds);
    }
}