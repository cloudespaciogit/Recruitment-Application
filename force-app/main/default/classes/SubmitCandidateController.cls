/*
##################################################### 
# Created By (Date)   : Shivam Shivhare (7 Oct, 2025)
# Description         : Controller class for fetching client, job, and candidate information 
#                       and sending candidate details via email in CSV format(SubmitToClient Lwc Component).
# Modifications Log   : 
* Ver    Date              Author                   Modification
* 1.0    7 Oct, 2025      Shivam Shivhare          Initial Version
#####################################################
*/

public with sharing class SubmitCandidateController {

    /* ==================================================================================
    * Method : getAllClients
    * Purpose: Fetch all clients with valid email addresses.
    * Params : None
    * Returns: List of Client__c records (Id, Name, Email__c, Candidate_Fields__c)
    * Notes  : Cacheable for Lightning/Aura to improve performance.
    *================================================================================== */
    @AuraEnabled(cacheable=true)
    public static List<Client__c> getAllClients() {
        return [
            SELECT Id, Name, Email__c, Candidate_Fields__c
            FROM Client__c
            WHERE Email__c != null AND IsActive__c = true
            ORDER BY Name
        ];
    }

    /* ==================================================================================
    * Method : getJobPositionsByClient
    * Purpose: Fetch all job positions for a given client.
    * Params : 
    *   - clientId : Id of the Client__c record.
    * Returns: List of Job_Position__c records (Id, Name, Job_Title__c, Work_Location__c, Employment_Type__c, Job_description__c)
    * Notes  : Cacheable to reduce repeated queries in Lightning/Aura.
    *================================================================================== */
    @AuraEnabled(cacheable=true)
    public static List<Job_Position__c> getJobPositionsByClient(Id clientId) {
        return [
            SELECT Id, Name, Job_Title__c, Job_Location__c, Employment_Type__c, Job_Description__c
            FROM Job_Position__c
            WHERE Client__c = :clientId AND Status__c = 'Open'
            ORDER BY Name
        ];
    }

    /* ==================================================================================
    * Method : getCandidateForClient
    * Purpose: Fetch details of a single candidate for a given client.
    * Params : 
    *   - candidateId : Id of the Candidate__c record.
    *   - clientId    : Id of the Client__c record.
    * Returns: Map<String, Object> containing:
    *   - 'fieldOrder' : List of field labels and API names in display order.
    *   - 'values'     : Map of field API names to candidate values.
    * Notes  : Uses buildCandidateData() helper method.
    *================================================================================== */
    @AuraEnabled
    public static Map<String, Object> getCandidateForClient(Id candidateId, Id clientId) {
        return buildCandidateData(new List<Id>{ candidateId }, clientId)[0];
    }

    /* ==================================================================================
    * Method : getMultipleCandidatesForClient
    * Purpose: Fetch details of multiple candidates for a given client.
    * Params : 
    *   - candidateIds : List of Candidate__c Ids.
    *   - clientId     : Id of the Client__c record.
    * Returns: List<Map<String, Object>> each containing:
    *   - 'fieldOrder' : List of field labels and API names in display order.
    *   - 'values'     : Map of field API names to candidate values.
    * Notes  : Uses buildCandidateData() helper method.
    *================================================================================== */
    @AuraEnabled
    public static List<Map<String, Object>> getMultipleCandidatesForClient(List<Id> candidateIds, Id clientId) {
        return buildCandidateData(candidateIds, clientId);
    }

    /* ==================================================================================
    * Method : buildCandidateData
    * Purpose: Helper method to dynamically fetch candidate fields as per client configuration.
    * Params : 
    *   - candidateIds : List of Candidate__c Ids.
    *   - clientId     : Id of the Client__c record.
    * Returns: List<Map<String, Object>> where each map contains:
    *   - 'fieldOrder' : List of field labels and API names.
    *   - 'values'     : Map of API name => field value.
    * Notes  : Uses Client__c.Candidate_Fields__c to determine which fields to fetch. Defaults to Name, Email__c, Phone__c.
    *================================================================================== */
    private static List<Map<String, Object>> buildCandidateData(List<Id> candidateIds, Id clientId) {
        Client__c clientRec = [
            SELECT Candidate_Fields__c
            FROM Client__c
            WHERE Id = :clientId
            LIMIT 1
        ];

        String fieldList = String.isBlank(clientRec.Candidate_Fields__c) ? 'Name,Email__c,Phone__c' : clientRec.Candidate_Fields__c;
        List<String> fieldApiNames = fieldList.split(',');
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Candidate__c.fields.getMap();

        String query = 'SELECT ' + fieldList + ' FROM Candidate__c WHERE Id IN :candidateIds';
        List<Candidate__c> candidates = Database.query(query);

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Candidate__c c : candidates) {
            List<Map<String, String>> fieldOrder = new List<Map<String, String>>();
            Map<String, Object> values = new Map<String, Object>();

            for (String apiName : fieldApiNames) {
                Schema.DescribeFieldResult dfr = fieldMap.get(apiName.trim()).getDescribe();
                fieldOrder.add(new Map<String, String>{ 'label' => dfr.getLabel(), 'value' => apiName });
                values.put(apiName, c.get(apiName));
            }

            results.add(new Map<String, Object>{
                'fieldOrder' => fieldOrder,
                'values' => values
            });
        }
        return results;
    }

    /* ==================================================================================
    * Method : sendCandidateExcelEmail
    * Purpose: Sends an email to the client with a CSV attachment of candidate details.
    * Params : 
    *   - candidateIds : List of Candidate__c Ids.
    *   - clientId     : Id of the Client__c record.
    *   - jobId        : Id of the Job_Position__c record.
    * Returns: None
    * Notes  : Builds CSV from candidate data dynamically, attaches to email, and sends via Messaging API.
    *================================================================================== */
    @AuraEnabled
    public static void sendCandidateExcelEmail(List<Id> candidateIds, Id clientId, Id jobId) {
        // Fetch client and candidate fields
        Client__c clientRec = [SELECT Name, Email__c, Candidate_Fields__c FROM Client__c WHERE Id = :clientId LIMIT 1];
        String fieldList = String.isBlank(clientRec.Candidate_Fields__c) ? 'Name,Email__c,Phone__c' : clientRec.Candidate_Fields__c;
        List<String> fieldApiNames = fieldList.split(',');
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Candidate__c.fields.getMap();

        // Fetch candidates
        String query = 'SELECT ' + fieldList + ' FROM Candidate__c WHERE Id IN :candidateIds';
        List<Candidate__c> candidates = Database.query(query);

        // Build CSV headers
        List<String> headers = new List<String>();
        for (String apiName : fieldApiNames) {
            headers.add('"' + fieldMap.get(apiName.trim()).getDescribe().getLabel() + '"');
        }

        // Build CSV rows
        List<String> rows = new List<String>();
        for (Candidate__c c : candidates) {
            List<String> values = new List<String>();
            for (String apiName : fieldApiNames) {
                Object val = c.get(apiName.trim());
                values.add('"' + (val != null ? String.valueOf(val).replace('"','""') : '') + '"');
            }
            rows.add(String.join(values, ','));
        }

        // Convert CSV to Blob
        String csv = String.join(headers, ',') + '\n' + String.join(rows, '\n');
        Blob csvBlob = Blob.valueOf(csv);

        // Create email attachment
        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName('Candidate_Details.csv');
        efa.setBody(csvBlob);
        efa.setContentType('text/csv');

        // Fetch job details
        Job_Position__c job = [SELECT Name, Job_Title__c, Job_Location__City__s , Employment_Type__c, Job_Description__c
                               FROM Job_Position__c WHERE Id = :jobId LIMIT 1];

        // Build email body
        String emailBody = ''
            + 'Hi ' + clientRec.Name + ',\n\n'
            + 'As discussed, submitting you details of the candidate(s) for the ' + job.Job_Title__c + ' position based in ' + job.Job_Location__City__s  + '.\n'
            + 'Employment Type: ' + job.Employment_Type__c + '\n\n'
            + 'Job Role: ' + job.Job_Title__c + '\n'
            + 'Location: ' + job.Job_Location__City__s + '\n'
            + 'Job Type: ' + job.Employment_Type__c + '\n'
            + 'Job Description: ' + job.Job_Description__c + '\n\n'
            + 'Please find attached candidate details.\n\nThanks,\nRecruitment Team';

        // Send email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { clientRec.Email__c });
        mail.setSubject('Candidate Details');
        mail.setPlainTextBody(emailBody);
        mail.setFileAttachments(new Messaging.EmailFileAttachment[] { efa });

        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }

}