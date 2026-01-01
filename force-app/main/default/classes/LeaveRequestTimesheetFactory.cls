public class LeaveRequestTimesheetFactory {

    public static Timesheet__c build(
        TimesheetContext ctx,
        Date d
    ) {
        Datetime dt = Datetime.newInstance(d, Time.newInstance(0,0,0,0));

        return new Timesheet__c(
            Name =
                ctx.candidate.Name + '-' +
                ctx.input.leaveDuration + '-' +
                dt.format('EEE') + ', ' +
                dt.format('dd MMM'),
            Candidate__c = ctx.input.candidateId,
            Date__c = d,
            Status__c = ctx.input.leaveDuration,
            Reason_for_Leave__c = ctx.input.reason,
            Daily_Task__c = 'Leave',
            Manager_Approved__c = false
        );
    }
}