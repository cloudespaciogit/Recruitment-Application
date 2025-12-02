public with sharing class InterviewService {

    /**
     * @description Validates the inputs before processing (no wrapper).
     */
    public static void validateInterviewInputs(List<Id> recordIds, String newStage, String feedback) {
        if (recordIds == null
            || recordIds.isEmpty()
            || (String.isBlank(newStage) && String.isBlank(feedback))) {
            throw new AuraHandledException(
                'Invalid input: At least one field (Stage or Feedback) and Interview IDs are required.'
            );
        }
    }

    /**
     * @description Prepares Interview__c records with updated values.
     */
    public static List<Interview__c> prepareInterviewUpdates(List<Id> recordIds, String newStage, String feedback) {
        if (recordIds == null || recordIds.isEmpty()) {
            return new List<Interview__c>();
        }

        List<Interview__c> records = [
            SELECT Id, Interview_Status__c, Feedback__c
            FROM Interview__c
            WHERE Id IN :recordIds
            WITH USER_MODE
        ];

        for (Interview__c i : records) {
            if (!String.isBlank(newStage)) {
                i.Interview_Status__c = newStage;
            }
            if (!String.isBlank(feedback)) {
                i.Feedback__c = feedback;
            }
        }
        return records;
    }

    /**
     * @description Saves Interview__c records.
     */
    public static void saveInterviewRecords(List<Interview__c> interviewsToUpdate) {
        if (!interviewsToUpdate.isEmpty()) {
            try {
                System.debug('🟢 Interviews to update: ' + interviewsToUpdate);
                Database.update(interviewsToUpdate, AccessLevel.USER_MODE);
            } catch (Exception e) {
                System.debug('🔴 Apex Error: ' + e.getMessage());
                throw new AuraHandledException('Error updating interviews: ' + e.getMessage());
            }
        }
    }
}