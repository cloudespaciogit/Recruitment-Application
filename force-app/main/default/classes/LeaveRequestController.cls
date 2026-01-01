public without sharing class LeaveRequestController {

    @AuraEnabled
    public static void createTimesheets(String payloadJson) {

        TimesheetContext ctx =
            LeaveRequestContextBuilder.build(payloadJson);

        LeaveRequestProcessor.process(ctx);

        LeaveRequestDmlService.persist(ctx);

        LeaveRequestEmailService.notifyIfRequired(ctx);
    }
    @AuraEnabled(cacheable=true)
    public static List<Leave_Notify_Config__mdt> getNotifyConfigs() {
        return [
            SELECT Name__c, Email__c
            FROM Leave_Notify_Config__mdt
            WHERE Is_Active__c = true
            WITH USER_MODE
        ];
    }
    @AuraEnabled
    public static Id getLoggedInCandidateId() {

        User u = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        if (u.ContactId == null) {
            return null;
        }

        List<Candidate__c> c = [
            SELECT Id
            FROM Candidate__c
            WHERE Contact__c = :u.ContactId
            WITH USER_MODE
            LIMIT 1
        ];

        return c.isEmpty() ? null : c[0].Id;
    }
}