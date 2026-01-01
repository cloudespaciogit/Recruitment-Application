/**
 ##################################################### 
 # Created By (Date)   : Admin (22 Jul, 2025)
 # Description         : Apex Controller to support Extend Work Order LWC.
 #                       - Fetches field values for defaulting.
 #                       - Marks the Work Order as extended.
 # Modifications Log   : 
 * Ver    Date              Author         Modification
 * 1.0    22 Jul, 2025      Admin          Initial Version
 #####################################################
 */
//@SuppressWarnings('PMD.ApexCRUDViolation')
/**
 ##################################################### 
 # Created By (Date)   : Admin (22 Jul, 2025)
 # Description         : Apex Controller to support Extend Work Order LWC.
 #                       - Fetches field values for defaulting.
 #                       - Marks the Work Order as extended.
 # Modifications Log   : 
 * Ver    Date              Author         Modification
 * 1.1    26 Dec, 2025      Admin          PMD + USER_MODE + Complexity Fix
 #####################################################
 */
public with sharing class ExtendWorkOrderController {

    /**
     * Fetches required Work Order field values for UI defaulting.
     * This method is invoked from a Lightning Web Component
     * used as a Quick Action on the Work Order record page.
     *
     * @param recordId  Id of the existing Work_Order__c record
     * @return          Work_Order__c record populated with required fields
     * @throws          AuraHandledException if the record cannot be fetched
     */
    @AuraEnabled
    public static Work_Order__c getAllFieldsValue(Id recordId) {
        try {
            return [
                SELECT Id,
                       Candidate__c,
                       Project__c,
                       Role_on_Project__c,
                       Recruiter__c,
                       Renewed__c,
                       Salary_Offered__c
                FROM Work_Order__c
                WHERE Id = :recordId
                WITH USER_MODE
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to fetch Work Order fields: ' + e.getMessage()
            );
        }
    }

    /**
     * Marks an existing Work Order as Extended.
     * Only Work Orders in "Working" status are eligible.
     * The update is performed in USER MODE to enforce
     * object and field-level security.
     *
     * @param recordId  Id of the Work_Order__c record to be extended
     * @throws          AuraHandledException if validation or update fails
     */
    @AuraEnabled
    public static void markWorkOrderAsExtended(Id recordId) {
        try {
            validateUpdatePermissions();

            Work_Order__c wo = fetchWorkOrder(recordId);

            validateWorkingStatus(wo);

            updateAsExtended(wo);

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to extend Work Order: ' + e.getMessage()
            );
        }
    }

    /* =====================================================
       Permission Validation
       ===================================================== */
    private static void validateUpdatePermissions() {
        if (!Schema.sObjectType.Work_Order__c.isUpdateable()) {
            throw new AuraHandledException(
                'You do not have permission to update Work Orders.'
            );
        }

        if (!Schema.sObjectType.Work_Order__c.fields.Status__c.isUpdateable()) {
            throw new AuraHandledException(
                'You do not have permission to update Work Order status.'
            );
        }
    }

    /* =====================================================
       Fetch Work Order in USER MODE
       ===================================================== */
    private static Work_Order__c fetchWorkOrder(Id recordId) {
        return [
            SELECT Id, Status__c
            FROM Work_Order__c
            WHERE Id = :recordId
            WITH USER_MODE
            LIMIT 1
        ];
    }

    /* =====================================================
       Business Validation
       ===================================================== */
    private static void validateWorkingStatus(Work_Order__c wo) {
        if (wo.Status__c != 'Working') {
            throw new AuraHandledException(
                'Work Order must be in Working status. Current status: '
                + wo.Status__c
            );
        }
    }

    /* =====================================================
       Secure Update in USER MODE
       ===================================================== */
    private static void updateAsExtended(Work_Order__c wo) {
        wo.Status__c = 'Extended';

        List<SObject> sanitized =
            Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<SObject>{ wo }
            ).getRecords();

        Database.update(sanitized, AccessLevel.USER_MODE);
    }
}