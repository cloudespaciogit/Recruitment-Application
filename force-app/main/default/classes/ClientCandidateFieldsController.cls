/*
##################################################### 
# Created By (Date)   : Shivam Shivhare (6 Oct, 2025)
# Description         : Controller class for managing client-specific email preferences.
#                       Allows configuration of which Candidate fields should appear in 
#                       client emails and in what order (used in SubmitToClient LWC component).
# Modifications Log   : 
* Ver    Date              Author                   Modification
* 1.0    6 Oct, 2025      Shivam Shivhare          Initial Version
#####################################################
*/
public with sharing class ClientCandidateFieldsController {

    /* ==================================================================================
    * Method : getCandidateFieldOptions
    * Purpose: Dynamically fetch all available Candidate__c fields that clients can choose
    *           to include in their email preferences.
    * Params : None
    * Returns: List<Map<String, String>> containing:
    *   - 'label' : Field Label (display name)
    *   - 'value' : Field API Name
    *================================================================================== */
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getCandidateFieldOptions() {
        Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.Candidate__c.fields.getMap();
        List<Map<String,String>> options = new List<Map<String,String>>();
        
        for(String fieldName : fieldsMap.keySet()){
            Schema.DescribeFieldResult f = fieldsMap.get(fieldName).getDescribe();
            if(f.isAccessible() && !f.isCalculated() && f.getType() != Schema.DisplayType.ID) {
                options.add(new Map<String,String>{
                    'label' => f.getLabel(),
                    'value' => fieldName
                });
            }
        }

        
        for(Integer i = 0; i < options.size() - 1; i++){
            for(Integer j = i + 1; j < options.size(); j++){
                String labelA = options[i].get('label').toLowerCase();
                String labelB = options[j].get('label').toLowerCase();
                if(labelA > labelB){
                    Map<String,String> temp = options[i];
                    options[i] = options[j];
                    options[j] = temp;
                }
            }
        }

        return options;
    }

    /* ==================================================================================
    * Method : getClientCandidateFields
    * Purpose: Retrieve the saved email field preferences for a specific client.
    * Params : 
    *   - clientId : Id of the Client__c record.
    * Returns: String containing comma-separated Candidate field API names in preferred order.
    *================================================================================== */
    
    @AuraEnabled(cacheable=true)
    public static String getClientCandidateFields(Id clientId) {
        Client__c c = [SELECT Candidate_Fields__c FROM Client__c WHERE Id = :clientId LIMIT 1];
        return c.Candidate_Fields__c;
    }
	
    /* ==================================================================================
    * Method : saveClientCandidateFields
    * Purpose: Save or update the client’s email field preferences.
    * Params : 
    *   - clientId       : Id of the Client__c record.
    *   - selectedFields : Comma-separated list of Candidate field API names in preferred order.
    * Returns: None
    *================================================================================== */
    
    @AuraEnabled
    public static void saveClientCandidateFields(Id clientId, String selectedFields) {
        Client__c c = new Client__c(Id = clientId, Candidate_Fields__c = selectedFields);
        update c;
    }
}