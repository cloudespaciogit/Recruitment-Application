/*
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


public with sharing class ExtendWorkOrderController {


    /* ==================================================================================
    * Method: getAllFieldsValue
    * Purpose: Fetch specific field values from the Work_Order__c record.
    *          Used to prepopulate fields when creating a new extended work order.
    * Params : recordId - ID of the Work Order to retrieve.
    * Returns: Work_Order__c record with selected fields.
    * ==================================================================================
    */

    @AuraEnabled
    public static Work_Order__c  getAllFieldsValue(Id recordId){
        try {
            return [SELECT Id,Candidate__c,Project__c,Role_on_Project__c,Recruiter__c,Renewed__c,Salary_Offered__c  FROM Work_Order__c WHERE Id =: recordId LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('Failed to fetch Work Order fields: ' + e.getMessage());
        }
    } 

    /* ==================================================================================
    * Method: markWorkOrderAsExtended
    * Purpose: Update the Status__c field of an existing Work Order to 'Extended'
    *          to indicate it has been renewed/extended.
    * Params : recordId - ID of the Work Order to update.
    * Returns: void
    * ==================================================================================
    */

    @AuraEnabled
    public static void markWorkOrderAsExtended(Id recordId) {
        Work_Order__c wo = [
            SELECT Id, Status__c 
            FROM Work_Order__c 
            WHERE Id = :recordId 
            LIMIT 1
        ];

        if (wo.Status__c != 'Working') {
            throw new AuraHandledException(
                'Work Order status must be Working to extend. Current status: ' + wo.Status__c
            );
        }

        // If DML fails, Salesforce will auto throw exception
        wo.Status__c = RecruitmentApp_Constants.STATUS_EXTENDED;
        update wo;
    }

}