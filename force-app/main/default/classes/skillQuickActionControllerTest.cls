/**
* @File Name : skillQuickActionControllerTest.cls
* @Description : Test class for skillQuickActionController
* @Author :
* @Last Modified By :
* @Last Modified On : October 16, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.1 | October 16, 2025 |   | Added full positive & negative test coverage
**/

@isTest
public class skillQuickActionControllerTest {

    @testSetup
    static void setupTestData() {
        // Create first Candidate
        Candidate__c cand1 = Recruitment_TestDataFactory.createCandidate('John Doe', 'johndoe@email.com');
        cand1.Phone__c = '1111111111';
        cand1.Skills__c = 'Salesforce, Apex, LWC';
        cand1.Soft_Skills__c = 'Communication, Teamwork';
        insert cand1;

        // Create second Candidate
        Candidate__c cand2 = Recruitment_TestDataFactory.createCandidate('Jane Smith', 'jane.smith@test.com');
        cand2.Phone__c = '2222222222';
        cand2.Skills__c = 'Java, SQL, Salesforce';
        cand2.Soft_Skills__c = 'Problem Solving, Adaptability';
        insert cand2;

        // Create Client
        Client__c client = Recruitment_TestDataFactory.createClient('Client Name', 'Client@email.com');
        client.Phone__c = '1111111111';
        insert client;

        // Create Job Position
        Job_Position__c jp = Recruitment_TestDataFactory.createFlexJobPosition();
        jp.Client__c = client.Id;
        jp.Skills_Required__c = 'Salesforce, JavaScript';
        jp.Soft_Skills__c = 'Leadership, Problem Solving';
        insert jp;
    }

    // ---------------- Positive Tests ----------------

    @isTest
    static void testGetCandidateSkills_withCandidate() {
        Candidate__c cand = [SELECT Id FROM Candidate__c WHERE Name = 'John Doe' LIMIT 1];

        Test.startTest();
        Map<String, List<String>> result = skillQuickActionController.getCandidateSkills(cand.Id, 'Candidate');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('skills'));
        System.assert(result.containsKey('softSkills'));
        System.assertEquals(3, result.get('skills').size());
        System.assertEquals(2, result.get('softSkills').size());
    }

    @isTest
    static void testGetCandidateSkills_withJobPosition() {
        Job_Position__c jp = [SELECT Id FROM Job_Position__c LIMIT 1];

        Test.startTest();
        Map<String, List<String>> result = skillQuickActionController.getCandidateSkills(jp.Id, 'Job Position');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('skills'));
        System.assert(result.containsKey('softSkills'));
        System.assertEquals(2, result.get('skills').size());
        System.assertEquals(2, result.get('softSkills').size());
    }

    @isTest
    static void testUpdateCandidateSkills_withCandidate() {
        Candidate__c cand = [SELECT Id FROM Candidate__c WHERE Name = 'John Doe' LIMIT 1];

        List<String> newSkills = new List<String>{'Python', 'SOQL'};
        List<String> newSoftSkills = new List<String>{'Adaptability'};

        Test.startTest();
        skillQuickActionController.updateCandidateSkills(cand.Id, 'Candidate', newSkills, newSoftSkills);
        Test.stopTest();

        Candidate__c updatedCand = [SELECT Skills__c, Soft_Skills__c FROM Candidate__c WHERE Id = :cand.Id];
        System.assertEquals('Python, SOQL', updatedCand.Skills__c);
        System.assertEquals('Adaptability', updatedCand.Soft_Skills__c);
    }

    @isTest
    static void testUpdateCandidateSkills_withJobPosition() {
        Job_Position__c jp = [SELECT Id FROM Job_Position__c LIMIT 1];

        List<String> newSkills = new List<String>{'FSL', 'CPQ'};
        List<String> newSoftSkills = new List<String>{'Time Management', 'Creativity'};

        Test.startTest();
        skillQuickActionController.updateCandidateSkills(jp.Id, 'Job Position', newSkills, newSoftSkills);
        Test.stopTest();

        Job_Position__c updatedJp = [SELECT Skills_Required__c, Soft_Skills__c FROM Job_Position__c WHERE Id = :jp.Id];
        System.assertEquals('FSL, CPQ', updatedJp.Skills_Required__c);
        System.assertEquals('Time Management, Creativity', updatedJp.Soft_Skills__c);
    }

    // ---------------- Negative / Edge Case Tests ----------------

    @isTest
    static void testGetCandidateSkills_nullId() {
        Boolean didThrow = false;
        try {
            skillQuickActionController.getCandidateSkills(null, 'Candidate');
        } catch (AuraHandledException e) {
            didThrow = true;
        }
        System.assert(didThrow);
    }

    @isTest
    static void testUpdateCandidateSkills_nullId() {
        Boolean didThrow = false;
        try {
            skillQuickActionController.updateCandidateSkills(null, 'Candidate', new List<String>{'Skill1'}, new List<String>{'Soft1'});
        } catch (AuraHandledException e) {
            didThrow = true;
        }
        System.assert(didThrow);
    }

    @isTest
    static void testGetCandidateSkills_invalidObjName() {
        Candidate__c cand = [SELECT Id FROM Candidate__c WHERE Name = 'John Doe' LIMIT 1];
        Map<String, List<String>> result = skillQuickActionController.getCandidateSkills(cand.Id, 'InvalidObj');
        System.assertEquals(true, result.isEmpty());
    }

    @isTest
    static void testUpdateCandidateSkills_invalidObjName() {
        Candidate__c cand = [SELECT Id FROM Candidate__c WHERE Name = 'John Doe' LIMIT 1];
        Boolean didThrow = false;

        try {
            skillQuickActionController.updateCandidateSkills(cand.Id, 'InvalidObj', new List<String>{'Skill1'}, new List<String>{'Soft1'});
        } catch (AuraHandledException e) {
            didThrow = true;
        }

        System.assert(didThrow);
    }

    @isTest
    static void testUpdateCandidateSkills_withEmptyLists() {
        Candidate__c cand = [SELECT Id, Skills__c, Soft_Skills__c FROM Candidate__c WHERE Name = 'Jane Smith' LIMIT 1];

        Test.startTest();
        skillQuickActionController.updateCandidateSkills(cand.Id, 'Candidate', new List<String>(), new List<String>());
        Test.stopTest();

        Candidate__c updatedCand = [SELECT Skills__c, Soft_Skills__c FROM Candidate__c WHERE Id = :cand.Id];
        System.assertEquals(null, updatedCand.Skills__c, 'Skills__c should be null when empty list is passed');
        System.assertEquals(null, updatedCand.Soft_Skills__c, 'Soft_Skills__c should be null when empty list is passed');
    }
 
   @isTest
    static void testUpdateCandidateSkills_candidateUpdateFailure() {
    
        // Get a real Candidate__c Id
        Candidate__c cand = [SELECT Id FROM Candidate__c WHERE Name = 'Jane Smith' LIMIT 1];
    
        String realIdStr = cand.Id;
    
        // Modify the last 5 characters to create a non-existing but valid Id
        String fakeIdStr = realIdStr.substring(0, realIdStr.length() - 5) + 'ABCDE';
    
        // Cast back to Id
        Id fakeCandId = (Id) fakeIdStr;
    
        Boolean didThrow = false;
    
        try {
            Test.startTest();
            skillQuickActionController.updateCandidateSkills(
                fakeCandId,
                'Candidate',
                new List<String>{ 'Apex' },
                new List<String>{ 'Leadership' }
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            didThrow = true;
        }
    
        System.assert(didThrow, 'Expected AuraHandledException for candidate update failure');
    }

	
   	@isTest
    static void testUpdateCandidateSkills_jobPositionUpdateFailure() {
        Job_Position__c jp = [SELECT Id FROM Job_Position__c LIMIT 1];
    	String realIdStr = jp.Id;
    
        // Modify the last 5 characters to create a non-existing but valid Id
        String fakeIdStr = realIdStr.substring(0, realIdStr.length() - 5) + 'ABCDE';
    
        // Cast back to Id
        Id fakeJobId = (Id) fakeIdStr;
    
        Boolean didThrow = false;
    
        try {
            Test.startTest();
            skillQuickActionController.updateCandidateSkills(
                fakeJobId,
                'Job Position',
                new List<String>{'SkillA'},
                new List<String>{'SoftA'}
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            didThrow = true;
        }
    
        System.assert(didThrow, 'Expected AuraHandledException for JP update failure');
    }
}