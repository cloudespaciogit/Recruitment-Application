/*
##################################################### 
# Created By (Date)   : Admin (22 Jul, 2025)
# Description         : Test class for ExtendWorkOrderController Apex class.
# Modifications Log   : 
* Ver    Date              Author         Modification
* 1.0    22 Jul, 2025      Admin          Initial Version
#####################################################
*/

@isTest
private class ExtendWorkOrderController_Test {
    
    @testSetup
    static void setupData() {
        
        Candidate__c cand = Recruitment_TestDataFactory.createCandidate('Test Candidate', 'testcandidate@example.com');
        Project__c proj = Recruitment_TestDataFactory.createProject('Test Project Description');
        Recruiter__c rec = Recruitment_TestDataFactory.createRecruiter('Test Recruiter', 'recruiter@example.com');
        insert new List<SObject>{ cand, proj, rec };
            Work_Order__c wo = Recruitment_TestDataFactory.createWorkOrder(cand.Id, proj.Id, rec.Id);
        insert wo;
    }
    
    /*
* @description : Tests getAllFieldsValue method - validates successful record retrieval.
*/
    @isTest
    static void testGetAllFieldsValue_Success() {
        Work_Order__c workOrder = [SELECT Id, Candidate__c, Project__c, Recruiter__c 
                                   FROM Work_Order__c LIMIT 1];
        
        Test.startTest();
        Work_Order__c result = ExtendWorkOrderController.getAllFieldsValue(workOrder.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Expected a Work Order record');
        System.assertEquals(workOrder.Candidate__c, result.Candidate__c, 'Candidate value mismatch');
        System.assertEquals(workOrder.Project__c, result.Project__c, 'Project value mismatch');
        System.assertEquals(workOrder.Recruiter__c, result.Recruiter__c, 'Recruiter value mismatch');
    }
    
    /*
* @description : Tests getAllFieldsValue method - validates exception when record does not exist.
*/
    @isTest
    static void testGetAllFieldsValue_NoRecord() {
        Id nonExistentWorkOrderId = 'a0B000000000001AAA'; 
        
        Test.startTest();
        try {
            ExtendWorkOrderController.getAllFieldsValue(nonExistentWorkOrderId);
            System.assert(false, 'Expected AuraHandledException for non-existent record');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Failed to fetch Work Order fields'),
                          'Expected exception message containing: Failed to fetch Work Order fields');
        }
        Test.stopTest();
    }
    
    /*
* @description : Tests markWorkOrderAsExtended method - validates status update to Extended.
*/
    @isTest
    static void testMarkWorkOrderAsExtended_Success() {
        Work_Order__c workOrder = [SELECT Id FROM Work_Order__c LIMIT 1];
        
        Test.startTest();
        ExtendWorkOrderController.markWorkOrderAsExtended(workOrder.Id);
        Test.stopTest();
        
        Work_Order__c updatedWO = [SELECT Status__c FROM Work_Order__c WHERE Id = :workOrder.Id];
        System.assertEquals(RecruitmentApp_Constants.STATUS_EXTENDED, updatedWO.Status__c,
                            'Status not updated to Extended');
    }
    
    /*
* @description : Tests markWorkOrderAsExtended method - validates exception when record does not exist.
*/
    @isTest
    static void testMarkWorkOrderAsExtended_NoRecord() {
        Id nonExistentWorkOrderId = 'a0B000000000002AAA'; 
        
        Test.startTest();
        try {
            ExtendWorkOrderController.markWorkOrderAsExtended(nonExistentWorkOrderId);
            System.assert(false, 'Expected AuraHandledException for non-existent Work Order');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Failed to mark Work Order as Extended'),
                          'Expected exception message containing: Failed to mark Work Order as Extended');
        }
        Test.stopTest();
    }
    /*
* @description : Tests markWorkOrderAsExtended method - validates exception when status is not Working.
*/
    @isTest
    static void testMarkWorkOrderAsExtended_InvalidStatus() {
        // Get a Work Order and set its status to something other than Working
        Work_Order__c workOrder = [SELECT Id, Status__c FROM Work_Order__c LIMIT 1];
        workOrder.Status__c = 'New';
        update workOrder;
        
        Test.startTest();
        try {
            ExtendWorkOrderController.markWorkOrderAsExtended(workOrder.Id);
            System.assert(false, 'Expected AuraHandledException when Work Order status is not Working');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Work Order status must be Working to extend'),
                          'Expected exception message containing: Work Order status must be Working to extend');
        }
        Test.stopTest();
    }
    
}