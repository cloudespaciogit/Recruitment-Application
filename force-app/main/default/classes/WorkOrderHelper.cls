/*
*#################################################################
* Created By (Date) : Ayush Agrawal (05 Aug, 2025)
* Description       : Trigger Helper Class for WorkOrder__c Object.
* Modifications Log :
* Ver   Date          Author           Modification
* 1.0   05 Aug, 2025  Ayush Agrawal    Initial Version
* 1.1   05 Aug, 2025  Dixit			    Initial Version
################################################################# 
*/

public class WorkOrderHelper {
    /**
* @author (date): Dixit (08 Sep, 2025)
* @description  : Processes Work Order completion.  
*                 If a Work Order is newly marked "Completed", its parent chain is checked.  
*                 All parent Work Orders are also marked as "Completed" if not already.  
* @param newList - List of new Work_Order__c records.  
* @param oldMap  - Map of old Work_Order__c records (Id → record).  
* @return void - Updates parent Work Orders if needed.  
*/
   
   public static void processWorkOrderCompletion(List<Work_Order__c> newList, Map<Id, Work_Order__c> oldMap) {

    Set<Id> newlyWorkOrderIdSet = new Set<Id>();
    for (Work_Order__c wo : newList) {
        Work_Order__c oldWO = oldMap.get(wo.Id);
        if (oldWO != null && oldWO.Status__c != 'Completed' && wo.Status__c == 'Completed') {
            newlyWorkOrderIdSet.add(wo.Id);
        }
    }

    if (newlyWorkOrderIdSet.isEmpty()) {
        System.debug('No newly completed Work Orders found.');
        return;
    }


    Map<Id, Work_Order__c> woMap = new Map<Id, Work_Order__c>(
        [SELECT Id, Status__c, Parent_Work_OrderID__c
         FROM Work_Order__c
         WHERE Id IN :newlyWorkOrderIdSet AND Parent_Work_OrderID__c != null]
    );

    
    Set<Id> allParentsToCompleteSet = new Set<Id>();

    for (Id woId : newlyWorkOrderIdSet) {
        Id currentId = woId;
        while (true) {
            Work_Order__c currentWO = woMap.get(currentId);
            if (currentWO == null || currentWO.Parent_Work_OrderID__c == null) {
                break;
            }
            Id parentId = currentWO.Parent_Work_OrderID__c;
            if (!allParentsToCompleteSet.add(parentId)) {
               
                break;
            }
            currentId = parentId;
        }
    }

    System.debug('All Parents to Complete => ' + allParentsToCompleteSet);

    if (allParentsToCompleteSet.isEmpty()) {
        System.debug('No parent Work Orders to update.');
        return;
    }

    
    List<Work_Order__c> updatesList = new List<Work_Order__c>();
    for (Work_Order__c woParent : [
        SELECT Id, Status__c FROM Work_Order__c WHERE Id IN :allParentsToCompleteSet
    ]) {
        if (woParent.Status__c != 'Completed') {
            woParent.Status__c = 'Completed';
            updatesList.add(woParent);
        }
    }

    if (!updatesList.isEmpty()) {
        try {
            update updatesList;
            System.debug('Parent Work Orders updated successfully: ' + updatesList);
        } catch (Exception e) {
            System.debug('Error updating parent Work Orders: ' + e.getMessage());
        }
    }
}

    
    /**
* @description  : Updates Candidate__c records' IsBillable__c flag.  
*                 If all Work Orders for a Candidate are marked "Completed",  
*                 the Candidate’s IsBillable__c is set to false.  
* @param newList - List of new Work_Order__c records.  
* @param oldMap  - Map of old Work_Order__c records (Id → record).  
* @return void - Updates Candidate__c records as needed.  
*/
    
    
    
   public static void updateCandidateBillable(List<Work_Order__c> newList, Map<Id, Work_Order__c> oldMap) {
    Set<Id> candidateIdsToCheckSet = new Set<Id>();


    for (Work_Order__c wo : newList) {
        if (wo.Candidate__c != null && wo.Status__c == 'Completed' && oldMap.get(wo.Id).Status__c != 'Completed') {
            candidateIdsToCheckSet.add(wo.Candidate__c);                
        }
    }
    
    if (candidateIdsToCheckSet.isEmpty()) {
        return;
    }

    
    Map<Id, List<Work_Order__c>> candidateWOCompletedMap = new Map<Id, List<Work_Order__c>>();
    Map<Id, List<Work_Order__c>> candidateWONotCompletedMap = new Map<Id, List<Work_Order__c>>();

    for (Work_Order__c wo : [
        SELECT Id, Status__c, Candidate__c 
        FROM Work_Order__c 
        WHERE Candidate__c = :candidateIdsToCheckSet
    ]) {
        if (wo.Status__c == 'Completed') {
            if (!candidateWOCompletedMap.containsKey(wo.Candidate__c)) {
                candidateWOCompletedMap.put(wo.Candidate__c, new List<Work_Order__c>());
            }
            candidateWOCompletedMap.get(wo.Candidate__c).add(wo);
        } else {
            if (!candidateWONotCompletedMap.containsKey(wo.Candidate__c)) {
                candidateWONotCompletedMap.put(wo.Candidate__c, new List<Work_Order__c>());
            }
            candidateWONotCompletedMap.get(wo.Candidate__c).add(wo);
        }
    }

    List<Candidate__c> candidatesToUpdateList = new List<Candidate__c>();

    for (Id candidateId : candidateIdsToCheckSet) {
        Candidate__c cand = new Candidate__c(Id = candidateId);

        if (candidateWONotCompletedMap.containsKey(candidateId)) {
            cand.IsBillable__c = true;
        }
        Else if (candidateWOCompletedMap.containsKey(candidateId)) {
            cand.IsBillable__c = false;
        }

        candidatesToUpdateList.add(cand);
    }

    if (!candidatesToUpdateList.isEmpty()) {
        try{
        update candidatesToUpdateList;
        }
        catch (Exception e) {
        System.debug('Error inserting events: ' + e.getMessage());
    }
    }
}

   
        /**
* @author (date): Ayush Agrawal (07 Sep, 2025)
* @description  :  Will count the number if project associated with one candidate through workorder.
* @param newList - List of new Work_Order__c records.  
* @param oldMap  - Map of old Work_Order__c records (Id → record).  
*/
  public static void updateCandidateProjectCounts(List<Work_Order__c> workOrderList, Map<Id, Work_Order__c> oldMap) {
    Set<Id> candidateIds = new Set<Id>();

    if (workOrderList != null) {
        for (Work_Order__c wo : workOrderList) {
            if (wo.Candidate__c != null) {
                candidateIds.add(wo.Candidate__c);
            }
        }
    }

    if (oldMap != null) {
        for (Work_Order__c oldWO : oldMap.values()) {
            if (oldWO.Candidate__c != null) {
                candidateIds.add(oldWO.Candidate__c);
            }
        }
    }


    if (candidateIds.isEmpty()) return;

    Map<Id, Set<Id>> candidateToProjectsMap = new Map<Id, Set<Id>>();
    List<Work_Order__c> queriedWOs = [
        SELECT Id, Candidate__c, Project__c, Project__r.Name
        FROM Work_Order__c
        WHERE Candidate__c IN :candidateIds
              AND Project__c != null
    ];


    for (Work_Order__c wo : queriedWOs) {
       
        if (!candidateToProjectsMap.containsKey(wo.Candidate__c)) {
            candidateToProjectsMap.put(wo.Candidate__c, new Set<Id>());
        }
        candidateToProjectsMap.get(wo.Candidate__c).add(wo.Project__c);
    }

   

  
    List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();

    for (Id candidateId : candidateIds) {
        Integer count = 0;

        if (candidateToProjectsMap.containsKey(candidateId)) {
            count = candidateToProjectsMap.get(candidateId).size();
        }

        candidatesToUpdate.add(new Candidate__c(
            Id = candidateId,
            No_of_projects__c = count
        ));
    }
    if (!candidatesToUpdate.isEmpty()) {
        update candidatesToUpdate;
    }
}


}