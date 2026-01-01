public class LeaveRequestDmlService {

    public static void persist(TimesheetContext ctx) {

        if (!ctx.toInsert.isEmpty()) {
            ensureCreateAccess();
            insert ctx.toInsert;
        }

        if (!ctx.toUpdate.isEmpty()) {
            ensureUpdateAccess();
            update ctx.toUpdate;
        }
    }

    private static void ensureCreateAccess() {
        if (!Schema.sObjectType.Timesheet__c.isCreateable()) {
            throw new AuraHandledException(
                'You do not have permission to create Timesheets.'
            );
        }
    }

    private static void ensureUpdateAccess() {
        if (!Schema.sObjectType.Timesheet__c.isUpdateable()) {
            throw new AuraHandledException(
                'You do not have permission to update Timesheets.'
            );
        }
    }
}