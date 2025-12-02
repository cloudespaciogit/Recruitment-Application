/*
##################################################### 
# Created By (Date)   : Shivam Shivhare (7 Oct, 2025)
# Description         : Test class for ClientCandidateFieldsController Apex class.
# Modifications Log   : 
* Ver    Date              Author             Modification
* 1.0    7 Oct, 2025      Shivam Shivhare     Initial Version
#####################################################
*/

@IsTest
private class ClientCandidateFieldsControllerTest {

    // ------------------ Test Setup ------------------
    /**
    * @description : Creates reusable Client test data using Recruitment_TestDataFactory.
    */
    @TestSetup
    static void setupData() {
        

        Client__c client = Recruitment_TestDataFactory.createClient('Test Client', 'testclient@example.com');
        client.Candidate_Fields__c = 'Name__c,Email__c';
        insert client;
    }


    /**
    * @description : Verifies that getCandidateFieldOptions returns valid label-value maps.
    */
    @IsTest
    static void testGetCandidateFieldOptions() {
        Test.startTest();
        List<Map<String, String>> options = ClientCandidateFieldsController.getCandidateFieldOptions();
        Test.stopTest();

        System.assertNotEquals(0, options.size(), 'Options list should not be empty');
        System.assert(options[0].containsKey('label'), 'Each map should contain a label key');
        System.assert(options[0].containsKey('value'), 'Each map should contain a value key');
    }

    
    /**
    * @description : Verifies that getClientCandidateFields returns the correct field string.
    */
    @IsTest
    static void testGetClientCandidateFields() {
        Client__c client = [SELECT Id FROM Client__c LIMIT 1];

        Test.startTest();
        String fields = ClientCandidateFieldsController.getClientCandidateFields(client.Id);
        Test.stopTest();

        System.assertEquals('Name__c,Email__c', fields, 'Fetched field list should match the initial value');
    }

    /**
    * @description : Ensures saveClientCandidateFields updates the Candidate_Fields__c successfully.
    */
    @IsTest
    static void testSaveClientCandidateFields() {
        Client__c client = [SELECT Id, Candidate_Fields__c FROM Client__c LIMIT 1];

        Test.startTest();
        ClientCandidateFieldsController.saveClientCandidateFields(client.Id, 'Phone__c,Experience__c');
        Test.stopTest();

        Client__c updatedClient = [SELECT Candidate_Fields__c FROM Client__c WHERE Id = :client.Id];
        System.assertEquals('Phone__c,Experience__c', updatedClient.Candidate_Fields__c, 'Candidate fields should be updated successfully');
    }

    /**
    * @description : Verifies that exception is thrown when null Client Id is passed to saveClientCandidateFields.
    */
    @IsTest
    static void testSaveClientCandidateFieldsInvalidId() {
        Boolean exceptionThrown = false;

        try {
            Test.startTest();
            ClientCandidateFieldsController.saveClientCandidateFields(null, 'Dummy');
            Test.stopTest();
        } catch (Exception e) {
            exceptionThrown = true;
        }

        System.assert(exceptionThrown, 'Exception should be thrown for null Client Id');
    }
}