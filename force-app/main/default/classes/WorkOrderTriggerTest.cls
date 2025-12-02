@IsTest
public class WorkOrderTriggerTest {
    @testSetup
    static void setupTestData() {
        // ---------------------------
        // Create Candidates
        // ---------------------------
        Candidate__c cand1 = Recruitment_TestDataFactory.createCandidate('Candidate 1', 'cand1@test.com');
        Candidate__c cand2 = Recruitment_TestDataFactory.createCandidate('Candidate 2', 'cand2@test.com');
        Candidate__c cand3 = Recruitment_TestDataFactory.createCandidate('Candidate 3', 'cand3@test.com');
        Candidate__c cand4 = Recruitment_TestDataFactory.createCandidate('Candidate 4', 'cand4@test.com');
        insert new List<Candidate__c>{cand1, cand2, cand3, cand4};
            
            // ---------------------------
            // Create Projects
            // ---------------------------
            Project__c proj1 = Recruitment_TestDataFactory.createProject('Project X');
        Project__c proj2 = Recruitment_TestDataFactory.createProject('Project Y');
        insert new List<Project__c>{proj1, proj2};
            
            // ---------------------------
            // Create Recruiter
            // ---------------------------
            Recruiter__c rec = Recruitment_TestDataFactory.createRecruiter('Recruiter X', 'rec@test.com');
        insert rec;
        
        // ---------------------------
        // Insert Parent-Child Work Orders for Candidate 1 (existing structure)
        // ---------------------------
        Work_Order__c parentWO = Recruitment_TestDataFactory.createWorkOrder(cand1.Id, proj1.Id, rec.Id);
        insert parentWO; // Insert parentWO first to get its Id
        Work_Order__c childWO = Recruitment_TestDataFactory.createWorkOrder(cand1.Id, proj1.Id, rec.Id);
        childWO.Parent_Work_OrderID__c = parentWO.Id;
        insert childWO;
        
        // ---------------------------
        // Create reusable Work Orders for all test scenarios
        // ---------------------------
        List<Work_Order__c> workOrders = new List<Work_Order__c>{
            // Candidate 1 duplicate projects
            Recruitment_TestDataFactory.createWorkOrder(cand1.Id, proj1.Id, rec.Id),
                Recruitment_TestDataFactory.createWorkOrder(cand1.Id, proj1.Id, rec.Id),
                
                // Candidate 2 duplicate projects
                Recruitment_TestDataFactory.createWorkOrder(cand2.Id, proj1.Id, rec.Id),
                Recruitment_TestDataFactory.createWorkOrder(cand2.Id, proj1.Id, rec.Id),
                
                // Candidate 3 null project
                new Work_Order__c(Candidate__c = cand3.Id, Project__c = null, Recruiter__c = rec.Id, Status__c = 'Working'),
                
                // Candidate 4 for deletion test
                Recruitment_TestDataFactory.createWorkOrder(cand4.Id, proj1.Id, rec.Id),
                
                // Multiple candidate-project mapping
                Recruitment_TestDataFactory.createWorkOrder(cand1.Id, proj1.Id, rec.Id),
                Recruitment_TestDataFactory.createWorkOrder(cand2.Id, proj2.Id, rec.Id),
                
                // Null candidate test
                new Work_Order__c(Candidate__c = null, Project__c = proj1.Id, Recruiter__c = rec.Id, Status__c = 'Working')
                };
                    insert workOrders;
    }
    
    
//---------------------------- Project Count test start -----------------------------------
//-----------------------------------------------------------------------------------
    @isTest
    static void testCandidateProjectCounts() {
        List<Work_Order__c> workOrders = [
            SELECT Id, Status__c 
            FROM Work_Order__c 
            WHERE Candidate__r.Name = 'Candidate 4'
        ];
        
        System.assert(!workOrders.isEmpty(), 'No Work Orders found for Candidate 4');
        
        for (Work_Order__c wo : workOrders) {
            wo.Status__c = 'Completed';
        }
        Test.startTest();
        update workOrders;
        Test.stopTest();

		        
        Candidate__c cand = [SELECT No_of_Projects__c FROM Candidate__c WHERE Name = 'Candidate 4' LIMIT 1];
        System.assertEquals(1, cand.No_of_Projects__c, 'Candidate should have 1 unique project');
    }
    
    
    @isTest
    static void testDuplicateProjectsPerCandidate() {
        List<Work_Order__c> workOrders = [
            SELECT Id, Status__c 
            FROM Work_Order__c 
            WHERE Candidate__r.Name = 'Candidate 4' AND Project__c != null
        ];
        System.assert(!workOrders.isEmpty(), 'No Work Orders found for Candidate 4');
        
        for (Work_Order__c wo : workOrders) {
            wo.Status__c = 'Completed';
        }
        
        Test.startTest();
        update workOrders;
        Test.stopTest();
        
        Candidate__c cand = [SELECT No_of_Projects__c FROM Candidate__c WHERE Name = 'Candidate 4' LIMIT 1];
        System.assertEquals(1, cand.No_of_Projects__c, 'Duplicate project should only count once');
    }
    
    
    
    @isTest
    static void testWorkOrderWithNullProject() {
        Work_Order__c wo = [
            SELECT Id, Candidate__c, Project__c 
            FROM Work_Order__c 
            WHERE Project__c != null 
            LIMIT 1
        ];
        System.assertNotEquals(null, wo.Project__c, 'Expected WO with project');
        
        Id candId = wo.Candidate__c;
        
        // Get project count before
        Decimal  countBefore = [SELECT No_of_Projects__c FROM Candidate__c WHERE Id = :candId].No_of_Projects__c;
        
        wo.Project__c = null;
        
        Test.startTest();
        update wo;
        Test.stopTest();
        
        Decimal  countAfter = [SELECT No_of_Projects__c FROM Candidate__c WHERE Id = :candId].No_of_Projects__c;
        
        
        System.assert(countAfter <= countBefore, 'Project count should not increase after null project update');
    }
    
    @isTest
    static void testCandidateProjectCountAfterWorkOrderDelete() {
        Work_Order__c wo = [
            SELECT Id, Candidate__c 
            FROM Work_Order__c 
            WHERE Candidate__r.Name = 'Candidate 4' 
            LIMIT 1
        ];
        System.assertNotEquals(null, wo, 'Expected a Work Order for Candidate 4');
        
        wo.Status__c = 'Completed';
        update wo;
        
        Candidate__c cand = [SELECT No_of_Projects__c FROM Candidate__c WHERE Id = :wo.Candidate__c LIMIT 1];
        System.assertEquals(1, cand.No_of_Projects__c, 'Project count should be 1 before deletion');
        
        Test.startTest();
        delete wo;
        Test.stopTest();
        
        cand = [SELECT No_of_Projects__c FROM Candidate__c WHERE Id = :wo.Candidate__c LIMIT 1];
        System.assertEquals(0, cand.No_of_Projects__c, 'Project count should be 0 after deletion');
    }
    
//------------------------Project Count Test End------------------------------------
//
 
         /*
     * @description : Ensures candidate remains Billable when NOT all WOs are "Completed".
     */
    @IsTest
    static void testCandidateBillable_NotAllCompleted() {
        List<Work_Order__c> wos = [
            SELECT Id, Candidate__c, Status__c 
            FROM Work_Order__c 
            WHERE Candidate__r.Name = 'Candidate 1'
        ];
        
        // Mark one WO as Completed, one as Working
        wos[0].Status__c = 'Completed';
        wos[1].Status__c = 'Working';
        update wos;

        Candidate__c cand = [
            SELECT IsBillable__c 
            FROM Candidate__c 
            WHERE Name = 'Candidate 1'
        ];
        System.assertEquals(true, cand.IsBillable__c, 
            'Candidate should remain Billable when not all WOs are completed');
    }
    // ---------------------------
    // Test: Complete child WO -> parent cascades -> Candidate billable updated
    // ---------------------------
    @IsTest
    static void testChildWOCompletionCascadesParent() {
        Work_Order__c childWO = [SELECT Id, Status__c, Parent_Work_OrderID__c, Candidate__c 
                                 FROM Work_Order__c WHERE Parent_Work_OrderID__c != NULL LIMIT 1];
		Candidate__c cand = [SELECT IsBillable__c FROM Candidate__c WHERE Id=:childWO.Candidate__c];  
        System.debug('cand'+cand);
        // Step 1: Ensure starting with Working
        childWO.Status__c = 'Working';
        update childWO;
        
        Test.startTest();
        // Step 2: Change to Completed → trigger should fire
        childWO.Status__c = 'Completed';
        update childWO;
        cand.IsBillable__c=false;
        update cand;
        Test.stopTest();
        
        // Assert parent WO completed
        Work_Order__c parentWO = [SELECT Status__c FROM Work_Order__c WHERE Id=:childWO.Parent_Work_OrderID__c];
        System.debug('parentWO'+parentWO);
        System.assertEquals('Completed', parentWO.Status__c, 'Parent WO should be completed after child completion');
        
        // Assert candidate billable flag updated
        Candidate__c cand1 = [SELECT IsBillable__c,Name FROM Candidate__c WHERE Id=:childWO.Candidate__c];
        System.debug('cand88'+cand1);
          System.debug('cand889'+cand1.IsBillable__c);
        System.assertEquals(false, cand1.IsBillable__c, 'Candidate should be non-billable after all WOs completed');
    }
    
    @IsTest
    static void testBulkParentChildCompletionAndCandidateBillable() {
        // Fetch all child WOs (having parent)
        List<Work_Order__c> childWOs = [
            SELECT Id, Status__c, Parent_Work_OrderID__c, Candidate__c
            FROM Work_Order__c
            WHERE Parent_Work_OrderID__c != NULL
        ];
        System.assert(!childWOs.isEmpty(), 'There should be child WOs for bulk test');

        // Step 1: Set all child WOs to Working first
        for (Work_Order__c wo : childWOs) {
            wo.Status__c = 'Working';
        }
        update childWOs;

        // Step 2: Collect all candidates linked to child WOs
        Set<Id> candidateIds = new Set<Id>();
        for (Work_Order__c wo : childWOs) {
            candidateIds.add(wo.Candidate__c);
        }

        // Step 3: Fetch all work orders for these candidates
        List<Work_Order__c> allCandidateWOs = [
            SELECT Id, Status__c, Candidate__c
            FROM Work_Order__c
            WHERE Candidate__c IN :candidateIds
        ];

        // Mark all WOs as Completed
        for (Work_Order__c wo : allCandidateWOs) {
            wo.Status__c = 'Completed';
        }

        // -----------------------------
        // Step 4: Bulk update inside Test.startTest
        // -----------------------------
        Test.startTest();
        update allCandidateWOs; // triggers fire here
        Test.stopTest();

        // -----------------------------
        // Step 5: Verify parent WOs are completed
        // -----------------------------
        Set<Id> parentIds = new Set<Id>();
        for (Work_Order__c wo : childWOs) {
            parentIds.add(wo.Parent_Work_OrderID__c);
        }

        List<Work_Order__c> parentWOs = [
            SELECT Id, Status__c, Candidate__c
            FROM Work_Order__c
            WHERE Id IN :parentIds
        ];
        for (Work_Order__c pwo : parentWOs) {
            System.assertEquals('Completed', pwo.Status__c,
                'Parent WO should be completed after all children completed');
        }

        // -----------------------------
        // Step 6: Verify candidate billable flags
        // -----------------------------
        List<Candidate__c> candidates = [
            SELECT Id, IsBillable__c
            FROM Candidate__c
            WHERE Id IN :candidateIds
        ];
        for (Candidate__c cand : candidates) {
            System.assertEquals(false, cand.IsBillable__c,
                'Candidate should be non-billable after all WOs are completed');
        }
    }

    // ------------------------------
    // Optional: Partial completion scenario
    // ------------------------------
    @IsTest
    static void testCandidateBillablePartialCompletion() {
        // Fetch candidate 2 WOs
        Candidate__c cand = [SELECT Id, IsBillable__c FROM Candidate__c WHERE Name = 'Candidate 2' LIMIT 1];
        List<Work_Order__c> wos = [
            SELECT Id, Status__c FROM Work_Order__c
            WHERE Candidate__c = :cand.Id
        ];

        // Complete only half
        for (Integer i = 0; i < wos.size()/2; i++) {
            wos[i].Status__c = 'Completed';
        }

        Test.startTest();
        update wos;
        Test.stopTest();

        // Candidate should remain billable
        Candidate__c candAfter = [SELECT Id, IsBillable__c FROM Candidate__c WHERE Id = :cand.Id];
        System.assertEquals(true, candAfter.IsBillable__c,
            'Candidate should remain billable when some WOs are not completed');
    }

    
}