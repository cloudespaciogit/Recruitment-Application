public class TimesheetContext {
    public LeaveRequestDTO input;
    public Candidate__c candidate;
    public List<Date> weekdays;
    public Map<Date, Timesheet__c> existing;
    public List<Timesheet__c> toInsert = new List<Timesheet__c>();
    public List<Timesheet__c> toUpdate = new List<Timesheet__c>();
}