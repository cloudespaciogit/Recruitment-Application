/*
##################################################### 
# Created By (Date)   : Shivam Shivhare (7 Oct, 2025)
# Description         : Controller class for fetching client, job, and candidate information 
#                       and sending candidate details via email in CSV format(SubmitToClient Lwc Component).
#####################################################
*/

public with sharing class SubmitCandidateController {

    /* ==================================================================================
    * Method : getAllClients
    ================================================================================== */
    @AuraEnabled(cacheable=true)
    public static List<Client__c> getAllClients() {
        return [
            SELECT Id, Name, Email__c, Candidate_Fields__c
            FROM Client__c
            WHERE Email__c != null AND IsActive__c = true WITH USER_MODE
            ORDER BY Name
        ];
    }

    /* ==================================================================================
    * Method : getJobPositionsByClient
    ================================================================================== */
    @AuraEnabled(cacheable=true)
    public static List<Job_Position__c> getJobPositionsByClient(Id clientId) {
        return [
            SELECT Id, Name, Job_Title__c, Job_Location__c, Employment_Type__c, Job_Description__c
            FROM Job_Position__c
            WHERE Client__c = :clientId AND Status__c = 'Open' WITH USER_MODE
            ORDER BY Name
        ];
    }

    /* ==================================================================================
    * Method : getCandidateForClient
    ================================================================================== */
    @AuraEnabled
    public static Map<String, Object> getCandidateForClient(Id candidateId, Id clientId) {
        return buildCandidateData(new List<Id>{ candidateId }, clientId)[0];
    }

    /* ==================================================================================
    * Method : getMultipleCandidatesForClient
    ================================================================================== */
    @AuraEnabled
    public static List<Map<String, Object>> getMultipleCandidatesForClient(List<Id> candidateIds, Id clientId) {
        return buildCandidateData(candidateIds, clientId);
    }

    /* ==================================================================================
    * Core Helper – PMD-Safe Dynamic Query
    ================================================================================== */
    private static List<Map<String, Object>> buildCandidateData(List<Id> candidateIds, Id clientId) {

        Client__c clientRec = [
            SELECT Candidate_Fields__c
            FROM Client__c
            WHERE Id = :clientId WITH USER_MODE
            LIMIT 1
        ];

        String fieldList = String.isBlank(clientRec.Candidate_Fields__c)
            ? 'Name,Email__c,Phone__c'
            : clientRec.Candidate_Fields__c;

        Map<String, Schema.SObjectField> allFieldMap =
            Schema.SObjectType.Candidate__c.fields.getMap();

        List<String> requestedFields = fieldList.split(',');
        List<String> validated = new List<String>();

        for(String f : requestedFields){
            String clean = f.trim();
            if(allFieldMap.containsKey(clean)){
                validated.add(clean);
            }
        }

        if(validated.isEmpty()){
            validated.addAll(new List<String>{ 'Name', 'Email__c', 'Phone__c' });
        }

        List<String> queryParts = new List<String>{ 'SELECT ' + String.join(validated, ',') , ' FROM Candidate__c WHERE Id IN :candidateIds' };
        String finalQuery = String.join(queryParts, ' ');

        List<Candidate__c> candidates = Database.query(finalQuery);

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Candidate__c c : candidates) {
            List<Map<String, String>> orderList = new List<Map<String, String>>();
            Map<String, Object> values = new Map<String, Object>();

            for (String api : validated) {
                Schema.DescribeFieldResult dfr = allFieldMap.get(api).getDescribe();
                orderList.add(new Map<String, String>{ 'label' => dfr.getLabel(), 'value' => api });
                values.put(api, c.get(api));
            }

            results.add(new Map<String, Object>{
                'fieldOrder' => orderList,
                'values' => values
            });
        }
        return results;
    }

    /* ==================================================================================
    * Email Sending
    ================================================================================== */
    @AuraEnabled
    public static void sendCandidateExcelEmail(List<Id> candidateIds, Id clientId, Id jobId){

        Client__c clientRec = [
            SELECT Name, Email__c, Candidate_Fields__c
            FROM Client__c
            WHERE Id = :clientId WITH USER_MODE
            LIMIT 1
        ];

        List<Map<String, Object>> candidateData = buildCandidateData(candidateIds, clientId);

        List<String> headers = new List<String>();
        List<String> rows = new List<String>();

        if(!candidateData.isEmpty()){
            List<Map<String, String>> fieldOrder = (List<Map<String, String>>)candidateData[0].get('fieldOrder');
            for (Map<String, String> f : fieldOrder){
                headers.add('"' + f.get('label') + '"');
            }

            for (Map<String, Object> rowData : candidateData){
                Map<String, Object> vals = (Map<String, Object>)rowData.get('values');
                List<String> line = new List<String>();
                for(String api : vals.keySet()){
                    Object v = vals.get(api);
                    line.add('"' + (v != null ? String.valueOf(v).replace('"','""') : '') + '"');
                }
                rows.add(String.join(line, ','));
            }
        }

        Blob csvBlob = Blob.valueOf(String.join(headers, ',') + '\n' + String.join(rows, '\n'));

        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName('Candidate_Details.csv');
        efa.setBody(csvBlob);
        efa.setContentType('text/csv');


        Job_Position__c job = [
            SELECT Name, Job_Title__c, Job_Location__City__s, Employment_Type__c, Job_Description__c
            FROM Job_Position__c
            WHERE Id = :jobId WITH USER_MODE
            LIMIT 1
        ];

        String emailBody = ''
            + 'Hi ' + clientRec.Name + ',\n\n'
            + 'Submitting candidate(s) details for ' + job.Job_Title__c + ' based in ' + job.Job_Location__City__s + '.\n'
            + 'Employment Type: ' + job.Employment_Type__c + '\n\n'
            + 'Job Description: ' + job.Job_Description__c + '\n\n'
            + 'Attached are the details.\n\nThanks,\nRecruitment Team';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ clientRec.Email__c });
        mail.setSubject('Candidate Details');
        mail.setPlainTextBody(emailBody);
        mail.setFileAttachments(new Messaging.EmailFileAttachment[]{ efa });
        mail.setOrgWideEmailAddressId(getOrgWideEmailIdForCurrentUser());

        Messaging.SendEmailResult[] res = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });

        if(!res[0].isSuccess()){
            throw new AuraHandledException('Email failed to send');
        }
    }

    /* ==================================================================================
    * Get Org-Wide Email Address
    ================================================================================== */
    private static Id getOrgWideEmailIdForCurrentUser(){
        OrgWideEmailAddress owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :UserInfo.getUserEmail() WITH USER_MODE
            LIMIT 1
        ];
        return owea.Id;
    }
}