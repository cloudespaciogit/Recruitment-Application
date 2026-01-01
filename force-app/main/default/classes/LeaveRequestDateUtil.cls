public class LeaveRequestDateUtil {

    public static List<Date> getWeekdays(Date fromDate, Date toDate) {

        List<Date> weekdays = new List<Date>();

        if (fromDate == null || toDate == null) {
            return weekdays;
        }

        if (fromDate > toDate) {
            Date t = fromDate;
            fromDate = toDate;
            toDate = t;
        }

        Date d = fromDate;
        while (d <= toDate) {
            Integer day = Integer.valueOf(
                Datetime.newInstance(d, Time.newInstance(0,0,0,0))
                    .format('u')
            );
            if (day <= 5) {
                weekdays.add(d);
            }
            d = d.addDays(1);
        }
        return weekdays;
    }
}