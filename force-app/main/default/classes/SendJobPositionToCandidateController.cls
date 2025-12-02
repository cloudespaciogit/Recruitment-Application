public with sharing class SendJobPositionToCandidateController {

    @AuraEnabled
    public static Map<String, Object> getJobAndCandidates(Id jobPositionId, List<Id> interviewIds) {
        Map<String, Object> response = new Map<String, Object>();

        if (jobPositionId == null) return response;

      
        Job_Position__c job = [
            SELECT Id, Name, Job_Title__c, Job_Location__c,Client__r.Name,Client__r.Website__c,
                   Skills_Required__c, Shift_Time__c, Salary_Range__c	,
                   Experience_Required__c, Job_Description__c,Employment_Type__c
            FROM Job_Position__c
            WHERE Id = :jobPositionId
            LIMIT 1
        ];


        List<Candidate__c> candidates = new List<Candidate__c>();
        if (interviewIds != null && !interviewIds.isEmpty()) {
            candidates = [
                SELECT Id, Name, Email__c
                FROM Candidate__c
                WHERE Id IN (
                    SELECT Candidate__c
                    FROM Interview__c
                    WHERE Id IN :interviewIds
                    AND Candidate__c != NULL
                )
            ];
        }

        response.put('jobPosition', job);
        response.put('candidates', candidates);
        return response;
    }

    
}