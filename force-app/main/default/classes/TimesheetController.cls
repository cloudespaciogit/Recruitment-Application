/**
 * @description
 * Controller class responsible for managing Timesheet operations
 * for candidates using the portal or Lightning components.
 * @author - kshitiz
 */
public with sharing class TimesheetController {
    /**
    * @description
    * Context wrapper class used to group all data required
    * for processing timesheet business logic.
    *
    * This class is used to reduce method parameter count
    * and comply with PMD rules, while keeping the logic
    * readable and maintainable.
    *
    * It holds:
    * - The existing Timesheet__c record (if any)
    * - The active Work_Order__c record
    * - The candidate Id
    * - The current processing date
    * - The current login time
    */
    private class TimesheetContext {
        Timesheet__c ts;
        Work_Order__c activeWO;
        Id candidateId;
        Date today;
        Time currentTime;
    }

    /**
    * @description
    * Creates a new timesheet entry for the given candidate or updates
    * an existing one based on current login/logout status.
    * @param candidateId
    *        Id of the Candidate__c record for which the timesheet
    *        needs to be created or updated.
    *
    * @return String
    *         Status indicating the result of the operation:
    *         SUCCESS, NO_ACTIVE_WORK_ORDER, ALREADY_EXISTS, LOGOUT_DONE
    */
    @AuraEnabled
    public static String createTimesheet(String candidateId) {

        if (String.isBlank(candidateId)) {
            throw new AuraHandledException('Candidate Id not received.');
        }

        try {
            Date today = Date.today();
            DateTime nowDt = System.now();
            Time currentTime = Time.newInstance(
                nowDt.hour(),
                nowDt.minute(),
                nowDt.second(),
                nowDt.millisecond()
            );

            Id candidateRef = (Id) candidateId;

            List<Work_Order__c> activeWOList = [
                SELECT Id, Project__c, Candidate__r.Name
                FROM Work_Order__c
                WHERE Candidate__c = :candidateRef
                AND Status__c = 'Working'
                WITH USER_MODE
                LIMIT 1
            ];

            if (activeWOList.isEmpty()) {
                return 'NO_ACTIVE_WORK_ORDER';
            }

            List<Timesheet__c> existingTimesheets = [
                SELECT Id, Login_Time__c, Logout_Time__c, Status__c
                FROM Timesheet__c
                WHERE Candidate__c = :candidateRef
                AND Date__c = :today
                WITH USER_MODE
                LIMIT 1
            ];

            TimesheetContext ctx = new TimesheetContext();
            ctx.ts = existingTimesheets.isEmpty() ? null : existingTimesheets[0];
            ctx.activeWO = activeWOList[0];
            ctx.candidateId = candidateRef;
            ctx.today = today;
            ctx.currentTime = currentTime;

            return processTimesheet(ctx);

        } catch (Exception e) {
            throw new AuraHandledException(
                'Error creating timesheet: ' + e.getMessage()
            );
        }
    }

    /**
    * @description
    * Processes timesheet logic for a candidate based on the current
    * state of an existing timesheet and active work order.
    * This method contains the core business decision logic and
    * returns status values consumed directly by the LWC.
    *
    * @param ctx
    *        Context object containing the existing timesheet (if any),
    *        active work order, candidate Id, current date, and time.
    *
    * @return String
    *         Status indicating the outcome:
    *         SUCCESS, ALREADY_EXISTS, LOGOUT_DONE
    */
        private static String processTimesheet(TimesheetContext ctx) {

        if (ctx.ts != null) {

            if (ctx.ts.Login_Time__c != null &&
                ctx.ts.Logout_Time__c == null) {
                return 'ALREADY_EXISTS';
            }

            if (ctx.ts.Status__c != null &&
                ctx.ts.Status__c != 'Working' &&
                ctx.ts.Login_Time__c == null) {

                ctx.ts.Login_Time__c = ctx.currentTime;
                ctx.ts.Work_Order__c = ctx.activeWO.Id;
                ctx.ts.Project__c = ctx.activeWO.Project__c;
                update as user ctx.ts;

                return 'SUCCESS';
            }

            if (ctx.ts.Logout_Time__c != null) {
                return 'LOGOUT_DONE';
            }
        }

        String name =
            ctx.activeWO.Candidate__r.Name +
            '-Working-' +
            System.now().format('EEE, dd MMM');

        Timesheet__c newTimesheet = new Timesheet__c(
            Name = name,
            Date__c = ctx.today,
            Login_Time__c = ctx.currentTime,
            Candidate__c = ctx.candidateId,
            Work_Order__c = ctx.activeWO.Id,
            Project__c = ctx.activeWO.Project__c,
            Status__c = 'Working'
        );

        insert as user newTimesheet;
        return 'SUCCESS';
    }

    /**
     * @description
     * Retrieves the latest timesheet created today for a given candidate.
     * Used by Lightning components to display current login/logout
     * and working hour details.
     *
     * @param candidateId
     *        Id of the Candidate__c record.
     *
     * @return Timesheet__c
     *         The most recent Timesheet__c record for today,
     *         or null if no record exists.
     */
    @AuraEnabled(cacheable=false)
    public static Timesheet__c getTodayTimesheet(String candidateId) {
        Date today = Date.today();

       List<Timesheet__c> tsList = [
            SELECT Id,
                Login_Time__c,
                Logout_Time__c,
                Total_Working_Hours__c,
                CreatedDate,
                Status__c
            FROM Timesheet__c
            WHERE Candidate__c = :candidateId
            AND Date__c = :today WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1

        ];

        return tsList.isEmpty() ? null : tsList[0];
    }

    /**
     * @description
     * Logs out an active timesheet by setting the logout time
     * if the user is currently logged in.
     *
     * This method ensures logout occurs only once and
     * does not override existing logout times.
     *
     * @param timesheetId
     *        Id of the Timesheet__c record to be logged out.
     *
     * @throws AuraHandledException
     *         If the timesheetId is null or any error occurs during update.
     */
    @AuraEnabled
    public static void signoutTimesheet(Id timesheetId) {

        if (timesheetId == null) {
            throw new AuraHandledException('Timesheet Id not received.');
        }

        try {
            Timesheet__c ts = [
                SELECT Id, Logout_Time__c, Login_Time__c
                FROM Timesheet__c
                WHERE Id = :timesheetId
                WITH USER_MODE
                LIMIT 1
            ];
            if(ts.Logout_Time__c == NULL && ts.Login_Time__c != NULL){
            ts.Logout_Time__c = System.now().time();
            update as user ts;
            }
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error logging out: ' + e.getMessage()
            );
        }
    }
}