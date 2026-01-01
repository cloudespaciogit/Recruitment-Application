public class LeaveRequestProcessor {

    public static void process(TimesheetContext ctx) {

        for (Date d : ctx.weekdays) {
            if (ctx.existing.containsKey(d)) {
                handleExisting(ctx, ctx.existing.get(d));
            } else {
                ctx.toInsert.add(
                    LeaveRequestTimesheetFactory.build(ctx, d)
                );
            }
        }

        if (ctx.toInsert.isEmpty() && ctx.toUpdate.isEmpty()) {
            throw new AuraHandledException(
                'Leave already applied for selected dates.'
            );
        }
    }

    private static void handleExisting(
        TimesheetContext ctx,
        Timesheet__c ts
    ) {
        if (ctx.input.leaveDuration == 'Half Day - SH'
            && ts.Status__c == 'Half Day - SH') {
            throw new AuraHandledException(
                'Second Half leave already applied for this date.'
            );
        }

        if (ctx.input.leaveDuration == 'Half Day - SH') {
            ts.Status__c = 'Half Day - SH';
            ts.Reason_for_Leave__c = ctx.input.reason;
            ts.Daily_Task__c = 'Leave';
            ctx.toUpdate.add(ts);
        }
    }
}