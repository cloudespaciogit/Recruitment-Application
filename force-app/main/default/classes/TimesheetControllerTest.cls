@IsTest
public class TimesheetControllerTest {

    /* =========================================================
       Test Setup (Aligned with ATSController_Test pattern)
       ========================================================= */
    @TestSetup
    static void setupData() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'Test',
            LastName = 'Owner',
            Alias = 'tuser',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            CommunityNickname = 'testuser' + System.currentTimeMillis(),
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        // Base Timesheet from Factory (reused & reassigned per test)
        Timesheet__c baseTs = Recruitment_TestDataFactory.createTimesheet('timesheettestclass');
        insert baseTs;

        Project__c project = Recruitment_TestDataFactory.createProject('Timesheet Project');
        insert project;

        List<Candidate__c> candidates = new List<Candidate__c>();
        for (Integer i = 0; i < 10; i++) {
            Candidate__c c = Recruitment_TestDataFactory.createCandidate(
                'TS Candidate ' + i,
                'ts' + i + '@test.com'
            );
            candidates.add(c);
        }
        insert candidates;

        List<Work_Order__c> workOrders = new List<Work_Order__c>();
        for (Candidate__c c : candidates) {
            workOrders.add(new Work_Order__c(
                Candidate__c = c.Id,
                Project__c = project.Id,
                Status__c = 'Working'
            ));
        }
        insert workOrders;
    }

    /* =========================================================
       createTimesheet Tests
       ========================================================= */

    @IsTest
    static void testCreateTimesheetBlankCandidateId() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        try {
            TimesheetController.createTimesheet(null);
            System.assert(false, 'Exception expected');
        } catch (AuraHandledException e) {
		    System.assert(true, 'AuraHandledException thrown as expected');
        }
        Test.stopTest();
    }
    }

    @IsTest
    static void testCreateTimesheetNoActiveWorkOrder() {

        Candidate__c caaan = Recruitment_TestDataFactory.createCandidate('Testdatatestcandidate',
                'Candidatetststs@test.com');
		insert caaan;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        String result = TimesheetController.createTimesheet(caaan.Id);
        Test.stopTest();

        System.assertEquals('NO_ACTIVE_WORK_ORDER', result);
    }
    }

    @IsTest
    static void testCreateTimesheetAlreadyExists() {

        Candidate__c c = [SELECT Id FROM Candidate__c LIMIT 1];
        Work_Order__c wo = [
            SELECT Id, Project__c
            FROM Work_Order__c
            WHERE Candidate__c = :c.Id
            LIMIT 1
        ];

        Timesheet__c ts = [
            SELECT Id
            FROM Timesheet__c
            WHERE Name = 'timesheettestclass'
            LIMIT 1
        ];
        ts.Candidate__c = c.Id;
        ts.Work_Order__c = wo.Id;
        ts.Project__c = wo.Project__c;
        ts.Date__c = Date.today();
        ts.Login_Time__c = System.now().time();
        ts.Logout_Time__c = null;
        ts.Status__c = 'Working';
        update ts;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        String result = TimesheetController.createTimesheet(c.Id);
        Test.stopTest();

        System.assertEquals(
            'ALREADY_EXISTS',
            result,
            'Timesheet exists with Login_Time__c but no Logout_Time__c'
        );
    }
    }

    @IsTest
    static void testCreateTimesheetStatusOther() {

        Candidate__c c = [SELECT Id FROM Candidate__c LIMIT 1];
        Timesheet__c ts = [
            SELECT Id
            FROM Timesheet__c
            WHERE Name = 'timesheettestclass'
            LIMIT 1
        ];
        ts.Candidate__c = c.Id;
        ts.Date__c = Date.today();
        ts.Status__c = 'Holiday';
        update ts;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        String result = TimesheetController.createTimesheet(c.Id);
        Test.stopTest();

        System.assertEquals(
            'SUCCESS',
            result,
            'Timesheet exists with  no Login_Time__c but other status'
        );
    }
    }

    @IsTest
    static void testCreateTimesheetLogoutDone() {

        Candidate__c c = [SELECT Id FROM Candidate__c LIMIT 1 OFFSET 1];
        Work_Order__c wo = [
            SELECT Id, Project__c
            FROM Work_Order__c
            WHERE Candidate__c = :c.Id
            LIMIT 1
        ];

        Timesheet__c ts = [
            SELECT Id
            FROM Timesheet__c
            WHERE Name = 'timesheettestclass'
            LIMIT 1
        ];
        ts.Candidate__c = c.Id;
        ts.Work_Order__c = wo.Id;
        ts.Project__c = wo.Project__c;
        ts.Date__c = Date.today();
        ts.Login_Time__c = System.now().time();
        ts.Logout_Time__c = System.now().time(); // ✅ REQUIRED
        ts.Status__c = 'Working';
        update ts;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        String result = TimesheetController.createTimesheet(c.Id);
        Test.stopTest();

        System.assertEquals('LOGOUT_DONE', result);
    }
    }

    @IsTest
    static void testCreateTimesheetSuccess() {

        Candidate__c c = [SELECT Id FROM Candidate__c LIMIT 1 OFFSET 2];
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        String result = TimesheetController.createTimesheet(c.Id);
        Test.stopTest();

        System.assertEquals('SUCCESS', result);

        Timesheet__c ts = [
            SELECT Login_Time__c
            FROM Timesheet__c
            WHERE Candidate__c = :c.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, ts.Login_Time__c);
    }
    }
    /* =========================================================
       getTodayTimesheet Tests
       ========================================================= */

   @IsTest
    static void testGetTodayTimesheetFound() {

        Timesheet__c ts = [
            SELECT Id, Candidate__c
            FROM Timesheet__c
            WHERE Name = 'timesheettestclass'
            LIMIT 1
        ];
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
         System.runAs(u) {
        Test.startTest();
        Timesheet__c result = TimesheetController.getTodayTimesheet(ts.Candidate__c);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(ts.Id, result.Id);
    }
    }

    @IsTest
    static void testGetTodayTimesheetNotFound() {

         Candidate__c c = [SELECT Id FROM Candidate__c LIMIT 1 OFFSET 1];
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        Timesheet__c ts = TimesheetController.getTodayTimesheet(c.Id);
        Test.stopTest();

        System.assertEquals(null, ts);
    }
    }

    /* =========================================================
       signoutTimesheet Tests
       ========================================================= */

    @IsTest
    static void testSignoutTimesheetNullId() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        try {
            TimesheetController.signoutTimesheet(null);
            System.assert(false, 'Exception expected');
        } catch (AuraHandledException e) {
                System.assert(true, 'AuraHandledException thrown as expected');
        }
        Test.stopTest();
    }
    }

    @IsTest
    static void testSignoutTimesheetSuccess() {

        Candidate__c c = [SELECT Id FROM Candidate__c LIMIT 1 OFFSET 3];
        Work_Order__c wo = [
            SELECT Id, Project__c
            FROM Work_Order__c
            WHERE Candidate__c = :c.Id
            LIMIT 1
        ];

        Timesheet__c ts = [
            SELECT Id
            FROM Timesheet__c
            WHERE Name = 'timesheettestclass'
            LIMIT 1
        ];
        ts.Candidate__c = c.Id;
        ts.Work_Order__c = wo.Id;
        ts.Project__c = wo.Project__c;
        ts.Date__c = Date.today();
        ts.Login_Time__c = System.now().time();
        ts.Logout_Time__c = null;
        ts.Status__c = 'Working';
        update ts;
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        TimesheetController.signoutTimesheet(ts.Id);
        Test.stopTest();

        Timesheet__c updated = [
            SELECT Login_Time__c, Logout_Time__c
            FROM Timesheet__c
            WHERE Id = :ts.Id
        ];

        System.assertNotEquals(null, updated.Logout_Time__c);
        System.assert(
            updated.Logout_Time__c > updated.Login_Time__c,
            'Logout time must be later than login time'
        );
        }
    }

	@IsTest
    static void testSignoutTimesheetCatchBlock() {

        // Fake but valid Timesheet Id (record does NOT exist)
        Id fakeTimesheetId = 'a0B000000000001AAA';
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        try {
            TimesheetController.signoutTimesheet(fakeTimesheetId);
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
            // Assert exception type only (best practice)
            System.assert(true, 'Catch block executed successfully');
        }
        Test.stopTest();
    }
    }

    @IsTest
    static void createTimesheetCatchBlock() {

        // Invalid Id format → causes runtime exception
        String invalidCandidateId = 'INVALID_ID';
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        System.runAs(u) {
        Test.startTest();
        try {
            TimesheetController.createTimesheet(invalidCandidateId);
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
            System.assert(true, 'Catch block executed successfully');
        }
        Test.stopTest();
    }
    }
}