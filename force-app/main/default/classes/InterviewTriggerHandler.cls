/* 
  *#################################################################
  * Created By (Date) : Admin (26 Aug, 2025)
  * Description       : Trigger Handler Class for Interview__c Object. 
  *                     Delegates logic to InterviewTriggerHelper.
  * Modifications Log :
  * Ver   Date         Author   Modification
  * 1.0   26 Aug, 2025 Admin    Initial Version
  *################################################################# 
*/

public class InterviewTriggerHandler {
    
    /*
     * ==================================================================================
     * Method  : handleBeforeDelete
     * Purpose : Executes all required logic when Interview__c is Delete (before).
     * Params  : oldMap - Trigger.oldMap
     * ==================================================================================
	*/    
     public static void handleBeforeDelete (Map<Id, Interview__c> oldMap) {
     //---- Logic here
	 }
    
    /*
     * ==================================================================================
     * Method  : handleBeforeInsert
     * Purpose : Executes all required logic when Interview__c is Insert (before).
     * Params  : newList - Trigger.new
     * ==================================================================================
	*/
    
     public static void handleBeforeInsert (List<Interview__c> newList) {
	//---- Logic here
	}
    
    /*
     * ==================================================================================
     * Method  : handleBeforeUpdate
     * Purpose : Executes all required logic when Interview__c is Update (before).
     * Params  : newList - Trigger.new, oldMap - Trigger.oldMap
     * ==================================================================================
	*/
    
    public static void handleBeforeUpdate(List<Interview__c> newList, Map<Id, Interview__c> oldMap) {
    //---- Logic here
	}
    
    /*
     * ==================================================================================
     * Method  : handleAfterDelete
     * Purpose : Executes all required logic when Interview__c is deleted (after).
     * Params  : oldMap - Trigger.oldMap
     * ==================================================================================
    */    
    public static void handleAfterDelete(Map<Id, Interview__c> oldMap) {
    //---- Logic here
    }

    /*
     * ==================================================================================
     * Method  : handleAfterInsert
     * Purpose : Executes all required logic when Interview__c is inserted (after).
     * Params  : newList - Trigger.new
     * ==================================================================================
    */
    public static void handleAfterInsert(List<Interview__c> newList) {
 InterviewTriggerHelper.handleInterviewEvents(newList, null);

    }
    
    /*
     * ==================================================================================
     * Method  : handleAfterUpdate
     * Purpose : Executes all required logic when Interview__c is updated (after).
     * Params  : newList - Trigger.new, oldMap - Trigger.oldMap 
     * ==================================================================================
	*/
    
     public static void handleAfterUpdate(List<Interview__c> newList, Map<Id, Interview__c> oldMap) {
        InterviewTriggerHelper.handleStatusChange(newList, oldMap);
        InterviewTriggerHelper.createWorkOrder(newList, oldMap);
 		InterviewTriggerHelper.handleInterviewEvents(newList, oldMap);
	}
 }