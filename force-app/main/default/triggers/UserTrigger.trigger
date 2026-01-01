/**
 * @description
 * Trigger executed after User creation.
 * Handles linkage of existing Candidate__c records
 * to Contacts created via Experience Cloud self-registration.
 *
 * @author Ajay
 * @createdDate 15-Dec-2025
 * @lastModifiedDate 15-Dec-2025
 */
trigger UserTrigger on User (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        CandidateContactLinkService.linkCandidatesFromUsers(Trigger.new);
    }
}