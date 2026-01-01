/*
 #####################################################
 # Created By (Date)   : Shivam Shivhare (Dec, 2025)
 # Description         : Apex Controller for Public Career Site.
 #                       - Job search with filters & pagination
 #                       - Fetch job details
 #                       - Candidate creation / update
 #                       - Duplicate candidate prevention
 #                       - Interview creation
 #                       - Resume upload via Queueable (Google Drive)
 #
 # Modifications Log   :
 * Ver    Date              Author         Modification
 * 1.0    Dec, 2025         Admin          Initial Version
 #####################################################
*/
public without sharing class CandidatePublicController {

    /* ==================================================================================
     * Inner Class: CandidateResponse
     * Purpose    : Wrapper class to send candidate submission response
     *              back to LWC / Aura components.
     * ==================================================================================
     */
    public class CandidateResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public Boolean interviewCreated;
        @AuraEnabled public Id interviewId;
    }

     /* ==================================================================================
     * Inner Class: JobSearchResponse
     * Purpose    : Wrapper class for Job search results with pagination info.
     * ==================================================================================
     */
    public class JobSearchResponse {
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public List<Job_Position__c> jobs;
    }

   
  /*  @AuraEnabled(cacheable=true)
    public static List<Job_Position__c> getOpenJobPositions() {
        return [
            SELECT Id, Name, Job_Title__c, Job_Location__City__s,
                   Skills_Required__c, Pay_Rate_Salary_range__c,
                   Status__c, Job_Description__c, Experience_Required__c
            FROM Job_Position__c
            WHERE Status__c = 'Open'
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }*/

    /* ==================================================================================
     * Method: getJobDetails
     * Purpose: Fetch detailed information of a Job Position.
     * Params : jobId - Job_Position__c record Id
     * Returns: Job_Position__c record
     * ==================================================================================
     */
    @AuraEnabled(cacheable=true)
    public static Job_Position__c getJobDetails(Id jobId) {
        if (jobId == null) return null;
        return [
            SELECT Id, Name, Job_Title__c, Job_Location__City__s,
                   Skills_Required__c, Pay_Rate_Salary_range__c, Status__c,
                   Job_Description__c, Experience_Required__c, OwnerId
            FROM Job_Position__c
            WHERE Id = :jobId
            WITH USER_MODE LIMIT 1
            
        ];
    }

     /* ==================================================================================
     * Method: searchJobPositions
     * Purpose: Search Job Positions with filters & pagination.
     *          - Job Title search
     *          - City filter
     *          - Experience range
     * Params :
     *  - pageNumber     : Current page
     *  - pageSize       : Records per page
     *  - searchKey      : Job title keyword
     *  - cityFilter     : Job location city
     *  - minExperience  : Minimum experience
     *  - maxExperience  : Maximum experience
     * Returns: JobSearchResponse wrapper
     * ==================================================================================
     */
    @AuraEnabled
    public static JobSearchResponse searchJobPositions(
        Integer pageNumber,
        Integer pageSize,
        String searchKey,
        String cityFilter,
        Decimal minExperience,
        Decimal maxExperience
    ) {
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        if (pageSize == null || pageSize < 1) pageSize = 10;

        Integer offsetVal = (pageNumber - 1) * pageSize;

        // ---- Base WHERE clause ----
        String whereClause = ' FROM Job_Position__c WHERE Status__c = \'Open\' ';

        // ---- Search (Job title OR skills) ----
        // ---- Search ONLY IN Job Title ----
// ---- Search ONLY in Job Title (case insensitive by default) ----
if (!String.isBlank(searchKey)) {
    String key = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
    whereClause += ' AND Job_Title__c LIKE \'' + key + '\' ';
}


        // ---- City filter ----
        if (!String.isBlank(cityFilter)) {
            String cityKey = '%' + String.escapeSingleQuotes(cityFilter.trim()) + '%';
            whereClause += ' AND Job_Location__City__s LIKE \'' + cityKey + '\' ';
        }

        // ---- Experience range (assumes Experience_Required__c is numeric) ----
// ---- Experience Filter ----
// NOTE: Experience_Required__c is Numeric
if (minExperience != null && maxExperience != null) {
    whereClause += ' AND (Experience_Required__c >= ' + minExperience +
                   ' AND Experience_Required__c <= ' + maxExperience + ') ';
} else if (minExperience != null && maxExperience == null) {
    // 10+ case => exp >= 10
    whereClause += ' AND Experience_Required__c >= ' + minExperience + ' ';
}



        // ---- Count query ----
        String countQuery = 'SELECT COUNT() ' + whereClause;
        Integer total = Database.countQuery(countQuery);

        // ---- Data query (paged) ----
        String dataQuery =
            'SELECT Id, Name, Job_Title__c, Job_Location__City__s,' +
            '       Skills_Required__c, Pay_Rate_Salary_range__c,' +
            '       Status__c, Job_Description__c, Experience_Required__c, ' +
             '       CreatedDate ' +
            whereClause +
            ' ORDER BY CreatedDate DESC ' +
            ' LIMIT ' + pageSize +
            ' OFFSET ' + offsetVal;

        List<Job_Position__c> jobs = Database.query(dataQuery);

        JobSearchResponse resp = new JobSearchResponse();
        resp.totalRecords = total;
        resp.pageNumber  = pageNumber;
        resp.pageSize    = pageSize;
        resp.jobs        = jobs;

        return resp;
    }

    /* ==================================================================================
     * Method: checkExistingCandidate
     * Purpose: Check if Candidate already exists using Email or Phone.
     * Params :
     *  - email : Candidate email
     *  - phone : Candidate phone
     * Returns: Existing Candidate__c record or null
     * ==================================================================================
     */
    @AuraEnabled
    public static Candidate__c checkExistingCandidate(String email, String phone) {
        if (String.isBlank(email) && String.isBlank(phone)) return null;

        List<Candidate__c> found = new List<Candidate__c>();

        if (!String.isBlank(email)) {
            found = [
                SELECT Id, First_Name__c, Last_name__c, Email__c, Phone__c, Skills__c,
                       Experience_Year__c, Current_Company__c, Designation__c,
                       Expected_CTC__c, Notice_Period__c
                FROM Candidate__c
                WHERE Email__c = :email
                WITH USER_MODE LIMIT 1
            ];
            if (!found.isEmpty()) return found[0];
        }

        if (!String.isBlank(phone)) {
            found = [
                SELECT Id, First_Name__c, Last_name__c, Email__c, Phone__c, Skills__c,
                       Experience_Year__c, Current_Company__c, Designation__c,
                       Expected_CTC__c, Notice_Period__c
                FROM Candidate__c
                WHERE Phone__c = :phone
                WITH USER_MODE LIMIT 1
            ];
            if (!found.isEmpty()) return found[0];
        }
        return null;
    }

    /* ==================================================================================
     * Method: submitCandidateForm
     * Purpose: Handles complete Candidate Application flow.
     *          - Create / Update Candidate
     *          - Create Interview record
     *          - Upload Resume asynchronously
     * ==================================================================================
     */
    @AuraEnabled
    public static CandidateResponse submitCandidateForm(
        String firstName,
        String lastName,
        String email,
        String phone,
        Decimal experienceYears,
        String skills,
        String currentCompany,
        String jobTitle,
        Decimal expectedSalary,
        String noticePeriod,
        String recaptchaToken,
        String resumeFileName,
        String resumeContentType,
        String resumeBase64Body,
        Id jobId
    ) {
        CandidateResponse resp = new CandidateResponse();
        resp.success = false;

        // ------- Validation -----------
        if (String.isBlank(firstName) || String.isBlank(lastName) ||
            String.isBlank(email) || String.isBlank(phone)) {

            resp.message = 'Required fields are missing.';
            return resp;
        }

        // ------- Candidate Lookup -------
        Candidate__c cand;
        List<Candidate__c> existing = [
            SELECT Id
            FROM Candidate__c
            WHERE Email__c = :email
           WITH USER_MODE LIMIT 1
        ];

        Boolean isExisting = !existing.isEmpty();
        if (isExisting) {
            cand = existing[0];
        } else {
            cand = new Candidate__c();
        }

        // ---------- Update values ----------
        cand.First_Name__c      = firstName;
        cand.Last_name__c       = lastName;
        cand.Email__c           = email;
        cand.Phone__c           = phone;
        cand.Experience_Year__c = experienceYears;
        cand.Skills__c          = skills;
        cand.Current_Company__c = currentCompany;
        cand.Designation__c     = jobTitle;
        cand.Expected_CTC__c    = expectedSalary;
        cand.Notice_Period__c   = noticePeriod;
        cand.Source__c          = 'Company Website';

        try {
            if (isExisting) {
                update cand;
            } else {
                insert cand;
            }
        } catch (Exception e) {
            resp.message = 'Error saving candidate — ' + e.getMessage();
            return resp;
        }

        resp.candidateId = cand.Id;

        // ---------- Interview Section ----------
        if (jobId != null) {

            Interview__c existingInterview;
            List<Interview__c> existList = [
                SELECT Id
                FROM Interview__c
                WHERE Candidate__c = :cand.Id
                AND Job_Position__c = :jobId
                WITH USER_MODE LIMIT 1
            ];

            if (!existList.isEmpty()) {

                existingInterview = existList[0];

                resp.success = true;
                resp.interviewCreated = false;
                resp.interviewId = existingInterview.Id;
                resp.message = 'You have already applied for this job earlier.';

            } else {

                Interview__c newInterview = new Interview__c();
                newInterview.Candidate__c = cand.Id;
                newInterview.Job_Position__c = jobId;
                newInterview.Interview_Status__c = 'New';

                // Assign Owner from Job Position
                try {
                    Job_Position__c jp = [
                        SELECT OwnerId
                        FROM Job_Position__c
                        WHERE Id = :jobId WITH USER_MODE LIMIT 1
                    ];
                    if (jp != null)
                        newInterview.OwnerId = jp.OwnerId;
                } catch (Exception e) {
                    // keep default
                }

                insert newInterview;

                resp.success = true;
                resp.interviewCreated = true;
                resp.interviewId = newInterview.Id;
                resp.message = 'Application submitted successfully.';
            }
        } else {
            resp.message = 'Candidate saved successfully.';
            resp.success = true;
        }

        // -------- Resume Upload Queueable ----------
        if (!String.isBlank(resumeBase64Body)) {
            try {
                System.enqueueJob(new CandidateDriveUploadQueueable(
                    cand.Id,
                    resumeFileName,
                    resumeContentType,
                    resumeBase64Body
                ));
            } catch (Exception e) {
                resp.message += ' but resume upload failed: ' + e.getMessage();
            }
        }

        return resp;
    }
}