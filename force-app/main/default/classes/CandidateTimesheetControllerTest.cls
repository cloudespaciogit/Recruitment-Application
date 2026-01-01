@IsTest
public class CandidateTimesheetControllerTest {

    @IsTest
    static void testGetTimesheetsByDateRange() {

        Candidate__c candidate =
            Recruitment_TestDataFactory.createCandidate(
                'Test Candidate',
                'test@example.com'
            );
        insert candidate;

        Project__c project =
            Recruitment_TestDataFactory.createProject('Test Project');
        insert project;

        Recruiter__c recruiter =
            Recruitment_TestDataFactory.createRecruiter(
                'Recruiter',
                'recruiter@test.com'
            );
        insert recruiter;

        Work_Order__c wo =
            Recruitment_TestDataFactory.createWorkOrder(
                candidate.Id,
                project.Id,
                recruiter.Id
            );
        insert wo;

        Date startDate = Date.today().addDays(-5);
        Date endDate   = Date.today();

        List<Timesheet__c> timesheets = new List<Timesheet__c>{
            new Timesheet__c(
                Candidate__c = candidate.Id,
                Date__c = Date.today().addDays(-2),
                Status__c = 'Working',
                Login_Time__c = Time.newInstance(10, 0, 0, 0),
                Logout_Time__c = Time.newInstance(18, 0, 0, 0)
                //Total_Working_Hours__c = 8
            ),
            new Timesheet__c(
                Candidate__c = candidate.Id,
                Date__c = Date.today().addDays(-1),
                Status__c = 'Full Day Leave',
                Reason_for_Leave__c = 'i am sick'
            ),
            new Timesheet__c(
                Candidate__c = candidate.Id,
                Date__c = Date.today(),
                Status__c = 'Half Day Leave',
                Reason_for_Leave__c = ' i have an urgent work'
            )
        };
        insert timesheets;

        Test.startTest();

        List<Timesheet__c> result =
            CandidateTimesheetController.getTimesheetsByDateRange(
                candidate.Id,
                startDate,
                endDate
            );

        Test.stopTest();

        System.assertNotEquals(
            0,
            result.size(),
            'Timesheets should be returned'
        );
        system.debug('results : ' + result.size());

        Boolean foundFullDayLeave = false;
        Boolean foundHalfDayLeave = false;

        for (Timesheet__c ts : result) {
            if (ts.Status__c == 'Full Day Leave') {
                foundFullDayLeave = true;
            }
            if (ts.Status__c == 'Half Day Leave') {
                foundHalfDayLeave = true;
            }
        }

        System.assert(
            foundFullDayLeave,
            'Full Day Leave timesheet should exist'
        );
        System.assert(
            foundHalfDayLeave,
            'Half Day Leave timesheet should exist'
        );
    }

    @IsTest
    static void testGetHolidays() {

        Date holidayDate = Date.today().addDays(-3);

        Holiday holiday = new Holiday(
            Name = 'Test Holiday',
            ActivityDate = holidayDate
        );
        insert holiday;

        Date startDate = Date.today().addDays(-10);
        Date endDate   = Date.today();

        Test.startTest();

        Map<String, String> holidayMap =
            CandidateTimesheetController.getHolidays(
                startDate,
                endDate
            );

        Test.stopTest();

        System.assertNotEquals(
            0,
            holidayMap.size(),
            'Holiday map should not be empty'
        );
        system.debug('holiday no. : ' + holidayMap.size());

        String k = String.valueOf(holidayDate);

        System.assertEquals(
            'Test Holiday',
            holidayMap.get(k),
            'Holiday name should match'
        );
        system.debug('holiday name : ' + holidayMap.get(k));
    }

    @IsTest
    static void testNullSafety() {

        Test.startTest();

        List<Timesheet__c> emptyResult =
            CandidateTimesheetController.getTimesheetsByDateRange(
                null,
                null,
                null
            );

        Map<String, String> emptyHolidayMap =
            CandidateTimesheetController.getHolidays(
                null,
                null
            );

        Test.stopTest();

        System.assertEquals(
            0,
            emptyResult.size(),
            'Should return empty list for null input'
        );

        System.assertEquals(
            0,
            emptyHolidayMap.size(),
            'Should return empty holiday map for null input'
        );
    }
}