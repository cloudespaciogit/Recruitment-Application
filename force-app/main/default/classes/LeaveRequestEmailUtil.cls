public class LeaveRequestEmailUtil {

    public static Id getOrgWideEmailId() {

        OrgWideEmailAddress owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :UserInfo.getUserEmail()
            //WITH USER_MODE
            LIMIT 1
        ];
        return owea.Id;
    }
}