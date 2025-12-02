/*
*#################################################################
* Created By (Date) : Ayush Agrawal (05 Aug, 2025)
* Description       : WorkOrder Handler Class for WorkOrder__c Object.
* Modifications Log :
* Ver   Date          Author           Modification
* 1.0   05 Aug, 2025  Ayush Agrawal    Initial Version
################################################################# 
*/
public class WorkOrderHandler {
    
    /*
     * ==================================================================================
     * Method  : BeforeDelete
     * Purpose : Executes all required logic when Work_Order__c is Delete (before).
     * Params  : oldMap - Trigger.oldMap
     * ==================================================================================
	*/    
     public static void BeforeDelete (Map<Id, Work_Order__c> oldMap) {
     //---- Logic here
	 }
    
    /*
     * ==================================================================================
     * Method  : BeforeInsert
     * Purpose : Executes all required logic when Work_Order__c is Insert (before).
     * Params  : newList - Trigger.new
     * ==================================================================================
	*/
    
     public static void BeforeInsert (List<Work_Order__c> newList) {
	//---- Logic here
	}
    
    /*
     * ==================================================================================
     * Method  : BeforeUpdate
     * Purpose : Executes all required logic when Work_Order__c is Update (before).
     * Params  : newList - Trigger.new, oldMap - Trigger.oldMap
     * ==================================================================================
	*/
    
    public static void BeforeUpdate(List<Work_Order__c> newList, Map<Id, Work_Order__c> oldMap) {
    //---- Logic here
	}
    
    /*
     * ==================================================================================
     * Method  : AfterDelete
     * Purpose : Executes all required logic when Work_Order__c is deleted (after).
     * Params  : oldMap - Trigger.oldMap
     * ==================================================================================
    */    
    public static void AfterDelete(Map<Id, Work_Order__c> oldMap) {
         WorkOrderHelper.updateCandidateProjectCounts(null, oldMap);

    //---- Logic here
    }

    /*
     * ==================================================================================
     * Method  : AfterInsert
     * Purpose : Executes all required logic when Work_Order__c is inserted (after).
     * Params  : newList - Trigger.new
     * ==================================================================================
    */
    public static void AfterInsert(List<Work_Order__c> newList) {
        WorkOrderHelper.updateCandidateProjectCounts(newList, null);

    }
    
    /*
     * ==================================================================================
     * Method  : AfterUpdate
     * Purpose : Executes all required logic when Work_Order__c is updated (after).
     * Params  : newList - Trigger.new, oldMap - Trigger.oldMap 
     * ==================================================================================
	*/
    
     public static void AfterUpdate(List<Work_Order__c> newList, Map<Id, Work_Order__c> oldMap) {
        WorkOrderHelper.processWorkOrderCompletion(newList, oldMap);//Added By Dixit
        WorkOrderHelper.updateCandidateBillable(newList, oldMap);//Added By Dixit
        WorkOrderHelper.updateCandidateProjectCounts(newList, oldMap);

	}
}