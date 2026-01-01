public class LeaveRequestContextBuilder {

    public static TimesheetContext build(String payloadJson) {

        LeaveRequestDTO input =
            (LeaveRequestDTO) JSON.deserialize(payloadJson, LeaveRequestDTO.class);

        if (input == null || input.candidateId == null) {
            throw new AuraHandledException('Candidate not found.');
        }

        List<Date> weekdays =
            LeaveRequestDateUtil.getWeekdays(input.fromDate, input.toDate);

        if (weekdays.isEmpty()) {
            throw new AuraHandledException(
                'Selected dates fall on weekend. Leave can be applied only for weekdays.'
            );
        }

        Candidate__c candidate = [
            SELECT Id, Name
            FROM Candidate__c
            WHERE Id = :input.candidateId
            WITH USER_MODE
            LIMIT 1
        ];

        Map<Date, Timesheet__c> existing = new Map<Date, Timesheet__c>();
        for (Timesheet__c ts : [
            SELECT Id, Date__c, Status__c
            FROM Timesheet__c
            WHERE Candidate__c = :input.candidateId
            AND Date__c IN :weekdays
            WITH USER_MODE
        ]) {
            existing.put(ts.Date__c, ts);
        }

        TimesheetContext ctx = new TimesheetContext();
        ctx.input = input;
        ctx.weekdays = weekdays;
        ctx.candidate = candidate;
        ctx.existing = existing;

        return ctx;
    }
}