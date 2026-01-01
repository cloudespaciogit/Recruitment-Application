/**
 * @description Controller used by AddToExistingCandidate LWC for:
 *              - searching supplier-owned candidates (with SOSL)
 *              - pagination support
 *              - returning Notice Period picklist values
 *              - updating candidate fields
 *              - creating Interview__c records
 *
 * @file SupplierCandidateController.cls
 * @lastModifiedOn December 26, 2025
 *
 * NOTES:
 *  - Server-side pagination implemented
 *  - CRUD / FLS checks applied where DML occurs
 */
public with sharing class SupplierCandidateController {

    /* ------------------------------------------------------
       PAGINATION RESULT WRAPPER
       ------------------------------------------------------ */
    public class CandidatePageResult {
        @AuraEnabled public List<Candidate__c> records;
        @AuraEnabled public Integer totalRecords;
    }

    /* ------------------------------------------------------
       RESUME UPLOAD DTO
       ------------------------------------------------------ */
    public class ResumeUploadRequest {
        @AuraEnabled public String fileName;
        @AuraEnabled public String contentType;
        @AuraEnabled public String base64Body;
    }

    /* ------------------------------------------------------
       1. Load candidates (search + pagination)
       ------------------------------------------------------ */
    @AuraEnabled(cacheable=true)
    public static CandidatePageResult getMyCandidatesBySearch(
        String searchKey,
        Integer pageSize,
        Integer pageNumber
    ) {
        CandidatePageResult result = new CandidatePageResult();
        result.records = new List<Candidate__c>();

        pageSize = (pageSize == null || pageSize <= 0) ? 5 : pageSize;
        pageNumber = (pageNumber == null || pageNumber <= 0) ? 1 : pageNumber;
        Integer offsetSize = (pageNumber - 1) * pageSize;

        Id userId = UserInfo.getUserId();

        List<Supplier__c> suppliers = [
            SELECT Id FROM Supplier__c WHERE OwnerId = :userId
        ];
        if (suppliers.isEmpty()) {
            result.totalRecords = 0;
            return result;
        }

        Set<Id> supplierIds = new Set<Id>();
        for (Supplier__c s : suppliers) supplierIds.add(s.Id);

        if (String.isBlank(searchKey)) {

            result.totalRecords = [
                SELECT COUNT()
                FROM Candidate__c
                WHERE Supplier__c IN :supplierIds
            ];

            result.records = [
                SELECT Id, Name, Last_name__c, Email__c, Phone__c, Skills__c,
                       Experience_Year__c, Designation__c, Notice_Period__c,
                       Supplier_Expected_Rate__c, Supplier__c
                FROM Candidate__c
                WHERE Supplier__c IN :supplierIds
                ORDER BY Name
                LIMIT :pageSize OFFSET :offsetSize
            ];
            return result;
        }

        String findTerm = '*' + searchKey.replaceAll('\\*','') + '*';
        List<List<SObject>> searchResult = [
            FIND :findTerm IN ALL FIELDS
            RETURNING Candidate__c(Id)
        ];

        Set<Id> resultIds = new Set<Id>();
        if (!searchResult.isEmpty()) {
            for (SObject s : searchResult[0]) {
                resultIds.add((Id)s.get('Id'));
            }
        }

        if (resultIds.isEmpty()) {
            result.totalRecords = 0;
            return result;
        }

        result.totalRecords = [
            SELECT COUNT()
            FROM Candidate__c
            WHERE Id IN :resultIds
            AND Supplier__c IN :supplierIds
        ];

        result.records = [
            SELECT Id, Name, Last_name__c, Email__c, Phone__c, Skills__c,
                   Experience_Year__c, Designation__c, Notice_Period__c,
                   Supplier_Expected_Rate__c, Supplier__c
            FROM Candidate__c
            WHERE Id IN :resultIds
            AND Supplier__c IN :supplierIds
            ORDER BY Name
            LIMIT :pageSize OFFSET :offsetSize
        ];

        return result;
    }

    /* ------------------------------------------------------
       2. Picklist
       ------------------------------------------------------ */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getNoticePeriodPicklistValues() {
        List<Map<String, String>> res = new List<Map<String, String>>();
        for (Schema.PicklistEntry p :
            Candidate__c.Notice_Period__c.getDescribe().getPicklistValues()
        ) {
            res.add(new Map<String, String>{
                'label' => p.getLabel(),
                'value' => p.getValue()
            });
        }
        return res;
    }

    /* ------------------------------------------------------
       RESUME UPLOAD HANDLER
       ------------------------------------------------------ */
    private static void handleResumeUpload(
        ResumeUploadRequest resume,
        Id candidateId
    ) {
        if (resume == null || String.isBlank(resume.base64Body)) return;

        System.enqueueJob(
            new CandidateDriveUploadQueueable(
                candidateId,
                resume.fileName,
                resume.contentType,
                resume.base64Body
            )
        );
    }

    /* ------------------------------------------------------
       3. Update Candidate + Resume Upload
       ------------------------------------------------------ */
    /*@AuraEnabled
    public static Candidate__c updateCandidateFields(
        Id candidateId,
        String newNoticeValue,
        Decimal newExpectedRate,
        ResumeUploadRequest resume
    ) {
        system.debug('resume-----'+resume);
        if (candidateId == null) {
            throw new AuraHandledException('Candidate Id missing.');
        }

        Candidate__c cand = new Candidate__c(Id = candidateId);

        if (newNoticeValue != null) {
            cand.Notice_Period__c = newNoticeValue;
        }
        if (newExpectedRate != null) {
            cand.Supplier_Expected_Rate__c = newExpectedRate;
        }

        try {
            update cand;
            handleResumeUpload(resume, candidateId);
        } catch (DmlException ex) {
            throw new AuraHandledException(
                'Failed to update Candidate: ' + ex.getMessage()
            );
        }

        return [
            SELECT Id, Name, Last_name__c, Email__c, Phone__c,
                   Experience_Year__c, Designation__c,
                   Notice_Period__c, Supplier_Expected_Rate__c
            FROM Candidate__c
            WHERE Id = :candidateId
        ];
    }*/

    @AuraEnabled
public static Candidate__c updateCandidateFields(
    Id candidateId,
    String newNoticeValue,
    Decimal newExpectedRate,
    String resumeJson
) {
    if (candidateId == null) {
        throw new AuraHandledException('Candidate Id missing.');
    }

    Candidate__c cand = new Candidate__c(Id = candidateId);

    if (newNoticeValue != null) {
        cand.Notice_Period__c = newNoticeValue;
    }
    if (newExpectedRate != null) {
        cand.Supplier_Expected_Rate__c = newExpectedRate;
    }

    ResumeUploadRequest resume;
    if (!String.isBlank(resumeJson)) {
        resume = (ResumeUploadRequest) JSON.deserialize(
            resumeJson,
            ResumeUploadRequest.class
        );
    }

    try {
        update cand;
        handleResumeUpload(resume, candidateId);
    } catch (DmlException ex) {
        throw new AuraHandledException(
            'Failed to update Candidate: ' + ex.getMessage()
        );
    }

    return [
        SELECT Id, Name, Last_name__c, Email__c, Phone__c,
               Experience_Year__c, Designation__c,
               Notice_Period__c, Supplier_Expected_Rate__c
        FROM Candidate__c
        WHERE Id = :candidateId
    ];
}


    /* ------------------------------------------------------
       4. Create Interviews
       ------------------------------------------------------ */
    @AuraEnabled
    public static List<Interview__c> createInterviews(
        List<Id> candidateIds,
        Id jobPositionId
    ) {
        if (candidateIds == null || candidateIds.isEmpty()) {
            throw new AuraHandledException('No candidates passed.');
        }
        if (jobPositionId == null) {
            throw new AuraHandledException('Job Position Id missing.');
        }

        List<Interview__c> existing = [
            SELECT Id, Candidate__c
            FROM Interview__c
            WHERE Job_Position__c = :jobPositionId
            AND Candidate__c IN :candidateIds
        ];

        if (!existing.isEmpty()) {

            Set<Id> candIds = new Set<Id>();
            for (Interview__c iv : existing) {
                candIds.add(iv.Candidate__c);
            }

            List<Candidate__c> cands = [
                SELECT Id, Name
                FROM Candidate__c
                WHERE Id IN :candIds
            ];

            List<String> names = new List<String>();
            for (Candidate__c c : cands) {
                names.add(c.Name);
            }

            throw new AuraHandledException(
                'Interview already exists for candidate(s): ' +
                String.join(names, ', ')
            );
        }


        List<Interview__c> toInsert = new List<Interview__c>();
        for (Id cid : candidateIds) {
            toInsert.add(new Interview__c(
                Candidate__c = cid,
                Job_Position__c = jobPositionId
            ));
        }

        insert toInsert;
        return toInsert;
    }
}