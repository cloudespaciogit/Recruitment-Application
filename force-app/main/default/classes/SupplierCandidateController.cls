/**
* @File Name : SupplierCandidateController.cls
* @Description : this class is used in addtoExistingCandidate lwc
* @Author :
* @Last Modified By :
* @Last Modified On : November 26, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 26, 2025 |   | Initial Version
**/

public with sharing class SupplierCandidateController {

    /* ------------------------------------------------------
       1. Load candidates (search + filter by supplier owner)
       ------------------------------------------------------ */
    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> getMyCandidatesBySearch(String searchKey) {

        Id userId = UserInfo.getUserId();

        // Suppliers owned by the current user
        List<Supplier__c> suppliers = [
            SELECT Id FROM Supplier__c WHERE OwnerId = :userId
        ];
        if (suppliers.isEmpty()) return new List<Candidate__c>();

        Set<Id> supplierIds = new Set<Id>();
        for (Supplier__c s : suppliers) supplierIds.add(s.Id);

        // If no search, return all candidates
        if (String.isBlank(searchKey)) {
            return [
                SELECT Id, Name, Last_name__c, Email__c, Phone__c, Skills__c, Experience_Year__c, Designation__c,
                       Notice_Period__c, Supplier_Expected_Rate__c, Supplier__c
                FROM Candidate__c
                WHERE Supplier__c IN :supplierIds
                ORDER BY Name
            ];
        }

        // SOSL search
        String findTerm = '*' + searchKey.replaceAll('\\*','') + '*';
        List<List<SObject>> searchResult;
        try {
            searchResult = [FIND :findTerm IN ALL FIELDS RETURNING Candidate__c(Id)];
        } catch (Exception ex) {
            return new List<Candidate__c>();
        }

        Set<Id> resultIds = new Set<Id>();
        if (!searchResult.isEmpty() && searchResult[0] != null) {
            for (SObject rec : searchResult[0]) {
                resultIds.add((Id)rec.get('Id'));
            }
        }
        if (resultIds.isEmpty()) return new List<Candidate__c>();

        return [
            SELECT Id, Name, Last_name__c, Email__c, Phone__c, Skills__c, Experience_Year__c, Designation__c,
                   Notice_Period__c, Supplier_Expected_Rate__c, Supplier__c
            FROM Candidate__c
            WHERE Id IN :resultIds AND Supplier__c IN :supplierIds
            ORDER BY Name
        ];
    }

    /* ------------------------------------------------------
       2. Load Notice Period picklist values
       ------------------------------------------------------ */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getNoticePeriodPicklistValues() {
        Schema.DescribeFieldResult f = Candidate__c.Notice_Period__c.getDescribe();
        List<Map<String, String>> results = new List<Map<String, String>>();

        for (Schema.PicklistEntry p : f.getPicklistValues()) {
            results.add(new Map<String, String>{
                'label' => p.getLabel(),
                'value' => p.getValue()
            });
        }
        return results;
    }

    /* ------------------------------------------------------
       3. Update Notice Period + Supplier Expected Rate
       ------------------------------------------------------ */
    @AuraEnabled
    public static Candidate__c updateCandidateFields(
        Id candidateId,
        String newNoticeValue,
        Decimal newExpectedRate
    ) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate Id missing.');
        }

        Candidate__c cand = new Candidate__c(Id = candidateId);

        if (newNoticeValue != null)
            cand.Notice_Period__c = newNoticeValue;

        if (newExpectedRate != null)
            cand.Supplier_Expected_Rate__c = newExpectedRate;

        update cand;

        // return updated record
        return [
            SELECT Id, Name, Last_name__c, Email__c, Phone__c, Skills__c, Experience_Year__c, Designation__c,
                   Notice_Period__c, Supplier_Expected_Rate__c, Supplier__c
            FROM Candidate__c
            WHERE Id = :candidateId
        ];
    }

    /* ------------------------------------------------------
       4. Create Interview Records
       ------------------------------------------------------ */
    @AuraEnabled
    public static List<Interview__c> createInterviews(List<Id> candidateIds, Id jobPositionId) {
        if (candidateIds == null || candidateIds.isEmpty())
            throw new AuraHandledException('No candidates passed.');
        if (jobPositionId == null)
            throw new AuraHandledException('Job Position Id missing.');

        List<Interview__c> toInsert = new List<Interview__c>();
        for (Id cid : candidateIds) {
            Interview__c iv = new Interview__c();
            iv.Candidate__c = cid;
            iv.Job_Position__c = jobPositionId;
            toInsert.add(iv);
        }

        Database.SaveResult[] sr = Database.insert(toInsert, false);
        List<Interview__c> created = new List<Interview__c>();
        List<String> errors = new List<String>();

        for (Integer i = 0; i < sr.size(); i++) {
            if (sr[i].isSuccess()) {
                Interview__c iv = toInsert[i];
                iv.Id = sr[i].getId();
                created.add(iv);
            } else {
                for (Database.Error e : sr[i].getErrors()) {
                    errors.add(e.getMessage());
                }
            }
        }

        if (!errors.isEmpty())
            throw new AuraHandledException(String.join(errors, '; '));

        return created;
    }
}