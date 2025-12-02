public with sharing class CandidateSearchController {

    public class CandidateSearchParams {
        @AuraEnabled public String skillQuery { get; set; }
        @AuraEnabled public Decimal minExperience { get; set; }
        @AuraEnabled public Decimal maxExperience { get; set; }
        @AuraEnabled public Decimal minSalary { get; set; }
        @AuraEnabled public Decimal maxSalary { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String currentLocation { get; set; }
        @AuraEnabled public String gender { get; set; }
        @AuraEnabled public String noticePeriod { get; set; }
        @AuraEnabled public String highestQualification { get; set; }
        @AuraEnabled public String instituteName { get; set; }
        @AuraEnabled public String languageKnown {get; set;}
        @AuraEnabled public String preferredLocation { get; set; }
        @AuraEnabled public Decimal expectedCTC { get; set; }
        @AuraEnabled public Integer canJoinIn { get; set; }
    }

    @AuraEnabled
    public static List<Candidate__c> searchCandidates(CandidateSearchParams params) {
        String baseQuery = 'SELECT ' +
            'Id, Name, Skills__c, Total_Experience__c, Current_CTC__c, ' +
            'Phone__c, Current_Location__c, Gender__c, Notice_Period__c, LinkedIn_Profile__c, ' +
            'Highest_Qualification__c, Institute_Name__c, Preferred_Location__c, Expected_CTC__c, Can_join_in__c, Language_Known__c, CreatedDate, Rating__c, LastModifiedDate, Total_Experience_txt__c ' +
            'FROM Candidate__c WHERE Id != null';

        // Experience
        if (params.minExperience != null) {
            baseQuery += ' AND Total_Experience__c >= ' + params.minExperience;
        }
        if (params.maxExperience != null) {
            baseQuery += ' AND Total_Experience__c <= ' + params.maxExperience;
        }

        // Salary
        if (params.minSalary != null) {
            baseQuery += ' AND Current_CTC__c >= ' + params.minSalary;
        }
        if (params.maxSalary != null) {
            baseQuery += ' AND Current_CTC__c <= ' + params.maxSalary;
        }

        // Phone
        if (!String.isBlank(params.phone)) {
            baseQuery += ' AND Phone__c LIKE \'%' + String.escapeSingleQuotes(params.phone) + '%\'';
        }

        // Location
        if (!String.isBlank(params.currentLocation)) {
            baseQuery += ' AND Current_Location__c LIKE \'%' + String.escapeSingleQuotes(params.currentLocation) + '%\'';
        }

        // Gender
        if (!String.isBlank(params.gender) && params.gender != 'Any') {
            baseQuery += ' AND Gender__c = \'' + String.escapeSingleQuotes(params.gender) + '\'';
        }

        // Notice Period
        if (!String.isBlank(params.noticePeriod) && params.noticePeriod != 'Any') {
            baseQuery += ' AND Notice_Period__c = \'' + String.escapeSingleQuotes(params.noticePeriod) + '\'';
        }

        // Highest Qualification
        if (!String.isBlank(params.highestQualification)) {
            baseQuery += ' AND Highest_Qualification__c LIKE \'%' + String.escapeSingleQuotes(params.highestQualification) + '%\'';
        }

        // Language Known
        if (!String.isBlank(params.languageKnown)) {
            baseQuery += ' AND Language_Known__c LIKE \'%' + String.escapeSingleQuotes(params.languageKnown) + '%\'';
        }

        // Institute Name
        if (!String.isBlank(params.instituteName)) {
            baseQuery += ' AND Institute_Name__c LIKE \'%' + String.escapeSingleQuotes(params.instituteName) + '%\'';
        }

        // Preferred Location
        if (!String.isBlank(params.preferredLocation)) {
            baseQuery += ' AND Preferred_Location__c LIKE \'%' + String.escapeSingleQuotes(params.preferredLocation) + '%\'';
        }

        // Expected CTC
        if (params.expectedCTC != null) {
            baseQuery += ' AND Expected_CTC__c <= ' + params.expectedCTC;
        }

        // Can Join In
        if (params.canJoinIn != null) {
            baseQuery += ' AND Can_join_in__c = ' + params.canJoinIn;
        }

        List<Candidate__c> candidates = Database.query(baseQuery);

        // Skills filter (AND logic)
        if (!String.isBlank(params.skillQuery)) {
            List<String> skillList = new List<String>();
            for (String s : params.skillQuery.split(',')) {
                if (!String.isBlank(s)) {
                    skillList.add(s.trim().toLowerCase());
                }
            }

            List<Candidate__c> skillFiltered = new List<Candidate__c>();
            for (Candidate__c c : candidates) {
                if (c.Skills__c != null) {
                    // Boolean allMatched = true;
                    // for (String s : skillList) {
                    //     if (!c.Skills__c.toLowerCase().contains(s)) {
                    //         allMatched = false;
                    //         break;
                    //     }
                    // }
                    // if (allMatched) {
                    //     skillFiltered.add(c);
                    // }

                    Boolean matched = false;
                    for (String s : skillList) {
                        if (c.Skills__c.toLowerCase().contains(s)) {
                            matched = true;
                            break;
                        }
                    }
                    if (matched) {
                        skillFiltered.add(c);
                    }
                }
            }
            return skillFiltered;
        }

        return candidates;
    }
        @AuraEnabled(cacheable=true)
    public static List<Job_Position__c> getOpenJobPositions(String searchKey) {
        String key = '%' + searchKey + '%';

        return [
            SELECT Id, Name, Job_Title__c, Status__c, Total_Openings__c, Experience_Required__c, CreatedDate
            FROM Job_Position__c
            WHERE Status__c = 'Open'
            AND (
                Name LIKE :key
                OR Job_Title__c LIKE :key
            )
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static void assignCandidatesToJobs(List<Id> candidateIds, List<Id> jobPositionIds) {
        List<Interview__c> interviews = new List<Interview__c>();

        for (Id jobId : jobPositionIds) {
            for (Id candidateId : candidateIds) {
                interviews.add(new Interview__c(
                    Candidate__c = candidateId,
                    Job_Position__c = jobId,
                    Interview_Status__c = 'New'
                ));
            }
        }

        if (!interviews.isEmpty()) {
            //database.insert
            Database.insert(interviews, false);
        }
    }
}