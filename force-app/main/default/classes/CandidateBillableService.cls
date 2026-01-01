public with sharing class CandidateBillableService {

    public static void handle(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        if (!isValidContext(newList, oldMap)) return;

        Set<Id> candidateIds = getCandidates(newList, oldMap);
        updateBillable(candidateIds);
    }

    private static Boolean isValidContext(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        return newList != null && oldMap != null &&
               Schema.sObjectType.Candidate__c.isUpdateable();
    }

    private static Set<Id> getCandidates(
        List<Work_Order__c> newList,
        Map<Id, Work_Order__c> oldMap
    ) {
        Set<Id> ids = new Set<Id>();
        for (Work_Order__c wo : newList) {
            if (wo.Candidate__c != null &&
                wo.Status__c == 'Completed' &&
                oldMap.get(wo.Id).Status__c != 'Completed') {
                ids.add(wo.Candidate__c);
            }
        }
        return ids;
    }

    private static void updateBillable(Set<Id> candidateIds) {
        if (candidateIds.isEmpty()) return;

        Map<Id, Boolean> hasOpenWO = new Map<Id, Boolean>();
        for (Work_Order__c wo : [
            SELECT Candidate__c, Status__c
            FROM Work_Order__c
            WHERE Candidate__c IN :candidateIds
        ]) {
            if (wo.Status__c != 'Completed') {
                hasOpenWO.put(wo.Candidate__c, true);
            }
        }

        List<Candidate__c> updates = new List<Candidate__c>();
        for (Id idVal : candidateIds) {
            updates.add(new Candidate__c(
                Id = idVal,
                IsBillable__c = !hasOpenWO.containsKey(idVal)
            ));
        }
        update updates;
    }
}