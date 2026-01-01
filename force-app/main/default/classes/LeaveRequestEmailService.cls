public class LeaveRequestEmailService {

    public static void notifyIfRequired(TimesheetContext ctx) {

        if (ctx.input.notifyEmails == null ||
            ctx.input.notifyEmails.isEmpty()) {
            return;
        }

        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();

        mail.setToAddresses(ctx.input.notifyEmails);
        mail.setSubject('Leave Request Submitted');
        mail.setPlainTextBody(
            'Candidate: ' + ctx.candidate.Name +
            '\nFrom: ' + ctx.input.fromDate +
            '\nTo: ' + ctx.input.toDate +
            '\nLeave: ' + ctx.input.leaveDuration +
            '\nReason: ' + ctx.input.reason
        );

        mail.setOrgWideEmailAddressId(
            LeaveRequestEmailUtil.getOrgWideEmailId()
        );

        Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ mail }
        );
    }
}