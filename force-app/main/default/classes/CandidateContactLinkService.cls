/**
 * @description
 * Service class responsible for linking existing Candidate__c records
 * to Contact records when portal (Experience Cloud) Users are created.
 *
 * The linkage is performed based on matching email addresses between
 * Candidate__c.Email__c and Contact.Email.
 *
 * @author: Ajay
 *
 * @createdDate: 15-Dec-2025
 *
 * @lastModifiedDate: 15-Dec-2025
 */
public without sharing class CandidateContactLinkService {

    /**
     * @description
     * Entry-point method invoked from User AFTER INSERT trigger.
     * Links existing Candidate__c records to Contacts based on email match.
     *
     * @param insertedUsers
     * List of newly created User records.
     */
    public static void linkCandidatesFromUsers(List<User> insertedUsers) {

        if (insertedUsers == null || insertedUsers.isEmpty()) {
            return;
        }
        Set<Id> contactIds = new Set<Id>();
        for (User usr : insertedUsers) {
            if (usr.ContactId != null) {
                contactIds.add(usr.ContactId);
            }
        }

        if (contactIds.isEmpty()) {
            return;
        }

        Map<Id, Contact> contactMap = fetchEligibleContacts(contactIds);
        if (contactMap.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Contact con : contactMap.values()) {
            accountIds.add(con.AccountId);
        }

        Set<Id> customerAccountIds = getCustomerAccountIds(accountIds);

        if (customerAccountIds.isEmpty()) {
            return;
        }

        Map<String, Id> emailToContactIdMap = new Map<String, Id>();
        for (Contact con : contactMap.values()) {
            if (customerAccountIds.contains(con.AccountId)) {
                emailToContactIdMap.put(con.Email.toLowerCase(), con.Id);
            }
        }
        if (emailToContactIdMap.isEmpty()) {
            return;
        }

        List<Candidate__c> candidatesToUpdate =
            fetchCandidatesForUpdate(emailToContactIdMap);

        if (!candidatesToUpdate.isEmpty()) {
            update candidatesToUpdate;
        }
    }

    // ------------------------------------------------------------------
    // Helper Methods
    // ------------------------------------------------------------------

    /**
     * @description
     * Fetches Contacts that have Email and Account populated.
     *
     * @param contactIds
     * Set of Contact Ids.
     *
     * @return
     * Map of Contact Id to Contact record.
     */
    private static Map<Id, Contact> fetchEligibleContacts(Set<Id> contactIds) {
        Map<Id, Contact> contactMap = new Map<Id, Contact>();

        for (Contact con : [
            SELECT Id, Email, AccountId
            FROM Contact
            WHERE Id IN :contactIds
            AND Email != null
            AND AccountId != null
        ]) {
            contactMap.put(con.Id, con);
        }

        return contactMap;
    }

    /**
     * @description
     * Retrieves Account Ids whose RecordType DeveloperName is 'Customer'.
     *
     * @param accountIds
     * Set of Account Ids to evaluate.
     *
     * @return
     * Set of Account Ids having Customer RecordType.
     */
    private static Set<Id> getCustomerAccountIds(Set<Id> accountIds) {
        Set<Id> customerAccountIds = new Set<Id>();

        if (accountIds.isEmpty()) {
            return customerAccountIds;
        }

        for (Account acc : [
            SELECT Id
            FROM Account
            WHERE Id IN :accountIds
            AND RecordType.DeveloperName = 'Customer_Community_Account'
        ]) {
            customerAccountIds.add(acc.Id);
        }

        return customerAccountIds;
    }

    /**
     * @description
     * Fetches existing Candidate__c records matching email keys
     * and prepares them for Contact linkage.
     *
     * @param emailToContactIdMap
     * Map of lowercase email to Contact Id.
     *
     * @return
     * List of Candidate__c records ready for update.
     */
    private static List<Candidate__c> fetchCandidatesForUpdate(Map<String, Id> emailToContactIdMap) {
        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();

        for (Candidate__c cand : [
            SELECT Id, Email__c, Contact__c
            FROM Candidate__c
            WHERE Email__c IN :emailToContactIdMap.keySet()]) {
            if (cand.Contact__c == null) {
                cand.Contact__c = emailToContactIdMap.get(cand.Email__c.toLowerCase());
                candidatesToUpdate.add(cand);
            }
        }

        return candidatesToUpdate;
    }
}