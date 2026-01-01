/**
 * @description
 * Controller class for Applicant Tracking System (ATS).
 * Provides Aura-enabled methods to fetch interview data, update interview stages,
 * remove candidates from jobs, collect interview feedback, and perform
 * bulk interview updates.
 *
 * @author Ayush
 * @modifiedBy Kshitiz
 */
public with sharing class ATSController {

    /**
     * @description
     * Retrieves interview records for a specific Job Position.
     * Used to populate ATS data tables in Lightning components.
     *
     * @param jobPositionId
     *        Id of the Job_Position__c record for which interviews are required.
     *
     * @return List<Interview__c>
     *         List of interview records associated with the given job position.
     */
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
                   Candidate__r.Source__c,
                   CreatedDate,
                   Job_Position__r.Name,
                   Job_Position__c
            FROM Interview__c
            WHERE Candidate__c != null
              AND Job_Position__c = :jobPositionId
            WITH USER_MODE
        ];
    }

    /**
     * @description
     * Updates the interview stage (Interview_Status__c) for multiple
     * Interview__c records.
     *
     * @param interviewIds
     *        List of Interview__c record Ids to update.
     *
     * @param newStageValue
     *        New stage value to be set on Interview_Status__c.
     *
     * @throws AuraHandledException
     *         If input validation fails or update operation encounters an error.
     
    @AuraEnabled
    public static void updateInterviewStages(List<Id> interviewIds, String newStageValue) {
        if (interviewIds == null || interviewIds.isEmpty() || String.isBlank(newStageValue)) {
            throw new AuraHandledException('Invalid input: Interview IDs and new Stage value are required.');
        }

        List<Interview__c> recordsToUpdate = new List<Interview__c>();
        for (Interview__c interview : [
            SELECT Id
            FROM Interview__c
            WHERE Id IN :interviewIds
            WITH USER_MODE
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
    } */

    /**
     * @description
     * Removes candidate interview records from a job position.
     * Also deletes related Event records for the same candidates and job.
     *
     * This operation is restricted to System Administrators only.
     *
     * @param interviewIds
     *        List of Interview__c record Ids to delete.
     *
     * @throws AuraHandledException
     *         If input is invalid or user is not authorized.
     */
    @AuraEnabled
    public static void removeCandidateFromJob(List<Id> interviewIds) {
        if (interviewIds == null || interviewIds.isEmpty()) {
            throw new AuraHandledException('Invalid input: Interview IDs are required.');
        }

        validateAdminAccess();

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
                SELECT Id
                FROM Event
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

    /**
     * @description
     * Validates that the current user has System Administrator profile.
     * Used to restrict destructive operations.
     *
     * @throws AuraHandledException
     *         If the current user is not a System Administrator.
     */
    private static void validateAdminAccess() {
        String profileName = [
            SELECT Name
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            WITH USER_MODE
        ].Name;

        if (profileName != 'System Administrator') {
            throw new AuraHandledException('Please contact admin. You cant delete this record');
        }
    }

    /**
     * @description
     * Sends feedback request emails to clients for selected interviews.
     * Email content is generated using EmailBody helper.
     *
     * @param interviewIds
     *        List of Interview__c record Ids for which feedback is requested.
     *
     * @throws AuraHandledException
     *         If no interview Ids are provided.
     */
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
            String emailSubject =
                'Feedback Request: Interview with ' + candidateName +
                ' for ' + jobPosition + ' (' + interviewRound + ')';

            if (String.isNotBlank(clientEmail)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { clientEmail });
                mail.setSubject(emailSubject);
                mail.setHtmlBody(emailBody);
                emails.add(mail);
                mail.setOrgWideEmailAddressId(ATSControllerHelper.getOrgWideEmailIdForCurrentUser());
            }
        }

        if (!emails.isEmpty()) {
           // Messaging.sendEmail(emails);
           Messaging.sendEmail(emails);
        }
    }

    /**
     * @description
     * Updates multiple Interview__c records with stage and feedback values.
     * Delegates validation and DML operations to InterviewService.
     *
     * @param recordIds
     *        List of Interview__c record Ids to update.
     *
     * @param newStage
     *        New interview stage value.
     *
     * @param feedback
     *        Feedback text to be saved.
     */
    @AuraEnabled
    public static void updateInterviews(List<Id> recordIds, String newStage, String feedback) {
        InterviewService.validateInterviewInputs(recordIds, newStage, feedback);
        List<Interview__c> interviewsToUpdate =
            InterviewService.prepareInterviewUpdates(recordIds, newStage, feedback);
        InterviewService.saveInterviewRecords(interviewsToUpdate);
    }

    /**
     * @description
     * Retrieves unique Candidate__c Ids from given Interview__c records.
     *
     * @param interviewIds
     *        List of Interview__c record Ids.
     *
     * @return List<Id>
     *         List of unique Candidate__c Ids.
     *
     * @throws AuraHandledException
     *         If no candidates are found for provided interviews.
     */
    @AuraEnabled(cacheable=true)
    public static List<Id> getCandidateIdsFromInterviews(List<Id> interviewIds) {
        if (interviewIds == null || interviewIds.isEmpty()) {
            throw new AuraHandledException('Interview IDs are required.');
        }

        Set<Id> candidateIds = new Set<Id>();
        for (Interview__c i : [
            SELECT Candidate__c
            FROM Interview__c
            WHERE Id IN :interviewIds
              AND Candidate__c != null
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