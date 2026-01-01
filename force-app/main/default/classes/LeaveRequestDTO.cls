public class LeaveRequestDTO {
    public Id candidateId;
    public Date fromDate;
    public Date toDate;
    public String leaveType;
    public String leaveDuration;
    public String reason;
    public List<String> notifyEmails;
}