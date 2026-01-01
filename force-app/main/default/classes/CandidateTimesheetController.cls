/**
* @File Name : CandidateTimesheetController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : December 15, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 15, 2025 |   | Initial Version
**/

public with sharing class CandidateTimesheetController {

    @AuraEnabled(cacheable=true)
    public static List<Timesheet__c> getTimesheetsByDateRange(
        Id candidateId,
        Date startDate,
        Date endDate
    ) {
        if (candidateId == null || startDate == null || endDate == null) {
            return new List<Timesheet__c>();
        }

        return [
            SELECT Id,
                   Status__c,
                   Date__c,
                   Login_Time__c,
                   Logout_Time__c,
                   Total_Working_Hours__c,
                   Penalty__c
            FROM Timesheet__c
            WHERE Candidate__c = :candidateId
              AND Date__c >= :startDate
              AND Date__c <= :endDate
            ORDER BY Date__c DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getHolidays(
        Date startDate,
        Date endDate
    ) {
        Map<String, String> holidayMap = new Map<String, String>();

        if (startDate == null || endDate == null) {
            return holidayMap;
        }

        for (Holiday h : [
            SELECT Name, ActivityDate
            FROM Holiday
            WHERE ActivityDate >= :startDate
            AND ActivityDate <= :endDate
        ]) {
            // Convert Date → ISO String
            holidayMap.put(
                String.valueOf(h.ActivityDate), // yyyy-MM-dd
                h.Name
            );
        }

        System.debug('Holiday Map Keys: ' + holidayMap.keySet());
        return holidayMap;
    }

    @AuraEnabled
    public static Id getLoggedInCandidateId() {
    
        System.debug('=== START getLoggedInCandidateId ===');
        System.debug('Current UserId = ' + UserInfo.getUserId());
    
        // Fetch logged-in user
        User u = [
            SELECT Id, Username, ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
    
        System.debug('User fetched => Id=' + u.Id +
                    ', Username=' + u.Username +
                    ', ContactId=' + u.ContactId);
    
        // Validate ContactId
        if (u.ContactId == null) {
            System.debug('❌ User has NO ContactId. Returning NULL.');
            return null;
        }
    
        // Fetch Candidate linked to Contact
        List<Candidate__c> cands = [
            SELECT Id, Name, Contact__c
            FROM Candidate__c
            WHERE Contact__c = :u.ContactId
            LIMIT 1
        ];
    
        System.debug('Candidate query size = ' + cands.size());
    
        if (cands.isEmpty()) {
            System.debug('❌ No Candidate found for ContactId = ' + u.ContactId);
            return null;
        }
    
        System.debug('✅ Candidate found => Id=' + cands[0].Id +
                    ', Name=' + cands[0].Name);
    
        System.debug('=== END getLoggedInCandidateId ===');
        return cands[0].Id;
    }
}