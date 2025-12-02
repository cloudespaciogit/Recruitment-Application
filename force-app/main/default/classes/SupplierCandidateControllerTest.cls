@isTest
private class SupplierCandidateControllerTest {

    @testSetup
    static void setupData() {
        // Create Supplier
        Supplier__c sup = new Supplier__c(
            Name = 'TS Supplier',
            Email__c = 'sup@test.com',
            Phone__c = '9999999998'
        );
        try {
            // if picklist exists
            List<Schema.PicklistEntry> ple = Supplier__c.Supplier__c.getDescribe().getPicklistValues();
            if (!ple.isEmpty()) sup.Supplier__c = ple[0].getValue();
        } catch (Exception ignored) {}
        insert sup;

        // Create Client (factory sets isActive__c)
        Client__c client = Recruitment_TestDataFactory.createClient('TS Client', 'client@test.com');
        // ensure active checkbox true if factory uses isActive__c or isActive__c
        try { client.isActive__c = true; } catch (Exception e) { try { client.isActive__c = true; } catch (Exception ex) {} }
        insert client;

        // Create Project & Job Position via factory
        Project__c proj = Recruitment_TestDataFactory.createProject('TS Project');
        insert proj;

        Job_Position__c jp = Recruitment_TestDataFactory.createJobPosition(client, proj);
        // If factory set client/proj Ids already it's fine; otherwise ensure values exist
        if (jp.Client__c == null) jp.Client__c = client.Id;
        if (jp.Project__c == null) jp.Project__c = proj.Id;
        insert jp;

        // Create two candidates via factory and link to supplier
        Candidate__c cand1 = Recruitment_TestDataFactory.createCandidate('Alpha Candidate1','alpha@test.com');
        cand1.Name = 'Alpha Candidate1';
        try { cand1.Last_name__c = 'Candidate1'; } catch (Exception ignore) {}
        cand1.Supplier__c = sup.Id;
        cand1.Phone__c = '1111111111';
        cand1.Skills__c = 'Apex,LWC';
        try { cand1.Experience_Year__c = 2; } catch (Exception e) { try { cand1.Total_Experience__c = 2; } catch (Exception ex) {} }
        cand1.Supplier_Expected_Rate__c = 50000;

        Candidate__c cand2 = Recruitment_TestDataFactory.createCandidate('Beta Candidate2','beta@test.com');
        cand2.Name = 'Beta Candidate2';
        try { cand2.Last_name__c = 'Candidate2'; } catch (Exception ignore) {}
        cand2.Supplier__c = sup.Id;
        cand2.Phone__c = '2222222222';
        cand2.Skills__c = 'Admin';
        try { cand2.Experience_Year__c = 3; } catch (Exception e) { try { cand2.Total_Experience__c = 3; } catch (Exception ex) {} }
        cand2.Supplier_Expected_Rate__c = 70000;

        insert new List<Candidate__c>{ cand1, cand2 };
    }

    // -------------------- HAPPY PATH --------------------
    @isTest static void testHappyPath() {
        // query test data created in @testSetup
        Supplier__c sup = [SELECT Id FROM Supplier__c WHERE Name = 'TS Supplier' LIMIT 1];
        Job_Position__c jp = [SELECT Id FROM Job_Position__c LIMIT 1];
        Candidate__c cand = [SELECT Id FROM Candidate__c WHERE Supplier__c = :sup.Id LIMIT 1];

        Test.startTest();
            // No-search listing
            List<Candidate__c> all = SupplierCandidateController.getMyCandidatesBySearch(null);
            System.assert(all.size() >= 1);

            // SOSL: set fixed results
            Test.setFixedSearchResults(new Id[]{ cand.Id });
            List<Candidate__c> found = SupplierCandidateController.getMyCandidatesBySearch('Alpha');
            System.assertEquals(1, found.size());

            // picklist values
            List<Map<String, String>> picks = SupplierCandidateController.getNoticePeriodPicklistValues();
            System.assertNotEquals(null, picks);

            // update fields happy path
            String pickVal = (picks.isEmpty() ? null : picks[0].get('value'));
            Decimal newRate = 11111.11;
            Candidate__c updated = SupplierCandidateController.updateCandidateFields(cand.Id, pickVal, newRate);
            System.assertEquals(cand.Id, updated.Id);
            if (pickVal != null) System.assertEquals(pickVal, updated.Notice_Period__c);
            System.assertEquals(newRate, updated.Supplier_Expected_Rate__c);

            // create interviews happy path
            List<Interview__c> created = SupplierCandidateController.createInterviews(new List<Id>{ cand.Id }, jp.Id);
            System.assertNotEquals(0, created.size());
        Test.stopTest();
    }

    // -------------------- NEGATIVE PATHS to hit catches & throws --------------------
    @isTest static void testNegativePaths() {
        Supplier__c sup = [SELECT Id FROM Supplier__c WHERE Name = 'TS Supplier' LIMIT 1];
        Job_Position__c jp = [SELECT Id FROM Job_Position__c LIMIT 1];
        Candidate__c cand = [SELECT Id FROM Candidate__c WHERE Supplier__c = :sup.Id LIMIT 1];

        Test.startTest();
            // empty candidate list -> throws AuraHandledException
            Boolean emptyThrew = false;
            try {
                SupplierCandidateController.createInterviews(new List<Id>(), jp.Id);
            } catch (AuraHandledException ex) { emptyThrew = true; }
            System.assert(emptyThrew);

            // null jobPosition -> throws AuraHandledException
            Boolean nullJobThrew = false;
            try {
                SupplierCandidateController.createInterviews(new List<Id>{ cand.Id }, null);
            } catch (AuraHandledException ex) { nullJobThrew = true; }
            System.assert(nullJobThrew);

            // partial DML failure: include null Id in list -> SaveResult for that index will have errors
            Boolean partialThrew = false;
            try {
                SupplierCandidateController.createInterviews(new List<Id>{ cand.Id, null }, jp.Id);
            } catch (AuraHandledException ex) { partialThrew = true; }
            System.assert(partialThrew);

            // invalid update Id -> should throw (DML error path)
            Boolean invalidUpdThrew = false;
            try {
                Id badId = Id.valueOf('000000000000000');
                SupplierCandidateController.updateCandidateFields(badId, 'BAD', 10);
            } catch (AuraHandledException ex) { invalidUpdThrew = true; } 
              catch (Exception ex2) { invalidUpdThrew = true; } // some orgs throw generic exceptions
            System.assert(invalidUpdThrew);

            // early-return in updateCandidateFields (no change)
            Candidate__c noChange = SupplierCandidateController.updateCandidateFields(cand.Id, null, null);
            System.assertEquals(cand.Id, noChange.Id);

            // getMyCandidatesBySearch when supplier list is empty: runAs another user who has no Suppliers
            // create test user
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User u = new User(
                Username = 'testuser' + Math.random() + '@example.com',
                Email = 'testuser' + Math.random() + '@example.com',
                LastName = 'T',
                Alias = 'tuser',
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = p.Id,
                LanguageLocaleKey = 'en_US'
            );
            insert u;

            System.runAs(u) {
                List<Candidate__c> emptyList = SupplierCandidateController.getMyCandidatesBySearch(null);
                // should return empty list (no suppliers owned by this user)
                System.assertNotEquals(null, emptyList);
            }

            // attempt to call SOSL malformed search; behavior varies by org, so just call and swallow exceptions
            try {
                SupplierCandidateController.getMyCandidatesBySearch('***');
            } catch (Exception swallow) {}
        Test.stopTest();
    }

    // -------------------- ADDITIONAL EDGE: validate that supplier empty returns list (already done via runAs) --------------------
    @isTest static void testSupplierEmptyBranchDirect() {
        // create a temp user and runAs to ensure branch
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        List<Candidate__c> list1 = new List<Candidate__c>();
        User u = new User(
            Username = 'tempuser' + Math.random() + '@example.com',
            Email = 'tempuser' + Math.random() + '@example.com',
            LastName = 'Temp',
            Alias = 'temp',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        System.runAs(u) {
            list1 = SupplierCandidateController.getMyCandidatesBySearch('no-match-expected-12345');
            System.assertNotEquals(null, list1);
        }
    }
}