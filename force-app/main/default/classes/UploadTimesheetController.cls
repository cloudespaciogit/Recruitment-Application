public with sharing class UploadTimesheetController {

    /* =========================================================
       FETCH WORK ORDERS
    ========================================================= */
    @AuraEnabled(cacheable=true)
    public static List<Work_Order__c> getProjects(Id recordId) {

        if (!Schema.sObjectType.Work_Order__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to access Work Orders.');
        }

        return [
            SELECT Id, Project__c, Project__r.Project_Name__c
            FROM Work_Order__c
            WHERE Candidate__c = :recordId
              AND Status__c = 'Working'
              AND Project__r.Active__c = true
        ];
    }

    /* =========================================================
       UPLOAD & PROCESS CSV
    ========================================================= */
    @AuraEnabled
    public static void uploadTimesheet(
        Id recordId,
        Id workOrderId,
        String fileName,
        String base64Data
    ) {
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('File data is empty.');
        }

        if (!Schema.sObjectType.Timesheet__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create Timesheets.');
        }

        // Work Order
        Work_Order__c wo = [
            SELECT Id, Project__c
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        // Candidate
        Candidate__c candidate = [
            SELECT Id, Name
            FROM Candidate__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        // Decode CSV
        Blob csvBlob = EncodingUtil.base64Decode(base64Data);
        String csvText = csvBlob.toString();
        List<String> rows = csvText.split('\n');

        // Collect Dates
        Set<Date> csvDates = collectDatesFromCSV(rows);

        // Query existing Timesheets
        Map<String, Timesheet__c> existingMap =
            queryExistingTimesheets(recordId, workOrderId, wo.Project__c, csvDates);

        // Build records (insert + update)
        List<Timesheet__c> timesheets =
            buildTimesheetsFromCSV(
                rows,
                recordId,
                workOrderId,
                wo.Project__c,
                candidate.Name,
                existingMap
            );

        if (!timesheets.isEmpty()) {
            // Only one DML; validation is bypassed
            upsert timesheets;
        }
    }

    /* =========================================================
       HELPERS
    ========================================================= */

    private static Set<Date> collectDatesFromCSV(List<String> rows) {
        Set<Date> dates = new Set<Date>();

        for (Integer i = 1; i < rows.size(); i++) {
            if (String.isBlank(rows[i])) continue;

            List<String> cols = rows[i].trim().split(',');
            if (cols.size() < 5) continue;

            dates.add(Date.valueOf(cols[0].trim()));
        }
        return dates;
    }

    private static Map<String, Timesheet__c> queryExistingTimesheets(
        Id candidateId,
        Id workOrderId,
        Id projectId,
        Set<Date> csvDates
    ) {
        Map<String, Timesheet__c> mapTs = new Map<String, Timesheet__c>();

        for (Timesheet__c ts : [
            SELECT Id, Candidate__c, Work_Order__c, Project__c, Date__c
            FROM Timesheet__c
            WHERE Candidate__c = :candidateId
              AND Work_Order__c = :workOrderId
              AND Project__c = :projectId
              AND Date__c IN :csvDates
        ]) {
            String key = ts.Candidate__c + '-' + ts.Work_Order__c + '-' +
                         ts.Project__c + '-' + ts.Date__c;
            mapTs.put(key, ts);
        }
        return mapTs;
    }

    private static List<Timesheet__c> buildTimesheetsFromCSV(
        List<String> rows,
        Id recordId,
        Id workOrderId,
        Id projectId,
        String candidateName,
        Map<String, Timesheet__c> existingMap
    ) {
        List<Timesheet__c> result = new List<Timesheet__c>();

        for (Integer i = 1; i < rows.size(); i++) {
            if (String.isBlank(rows[i])) continue;

            List<String> cols = rows[i].trim().split(',');
            if (cols.size() < 5) continue;

            Date workDate = Date.valueOf(cols[0].trim());
            Time loginTime = parseTime(cols[1].trim());
            Time logoutTime = parseTime(cols[2].trim());
            String dailyTask = cols[3].trim();
            String statusValue = cols[4].trim();

            String key = recordId + '-' + workOrderId + '-' +
                         projectId + '-' + workDate;

            Timesheet__c ts;

            // UPDATE
            if (existingMap.containsKey(key)) {
                ts = existingMap.get(key);
            }
            // INSERT
            else {
                Datetime dt = Datetime.newInstance(workDate, Time.newInstance(0, 0, 0, 0));
                String formattedDate = dt.format('EEE, dd MMM');
                String timesheetName =
                    candidateName + '-' + statusValue + '-' + formattedDate;

                ts = new Timesheet__c(
                    Name = timesheetName,
                    Candidate__c = recordId,
                    Work_Order__c = workOrderId,
                    Project__c = projectId,
                    Date__c = workDate
                );
            }

            // Common fields (update + insert)
            ts.Login_Time__c = loginTime;
            ts.Logout_Time__c = logoutTime;
            ts.Daily_Task__c = dailyTask;
            ts.Status__c = statusValue;
            ts.Bypass_Validation__c = true; // ensure validation is bypassed

            result.add(ts);
        }
        return result;
    }

    /* =========================================================
       TIME PARSER
    ========================================================= */
    private static Time parseTime(String timeString) {
        if (String.isBlank(timeString)) return null;

        timeString = timeString.trim().toUpperCase();

        Boolean isPM = timeString.endsWith('PM');
        Boolean isAM = timeString.endsWith('AM');

        if (isPM || isAM) {
            timeString = timeString.replace('AM', '').replace('PM', '').trim();
        }

        List<String> parts = timeString.split(':');
        if (parts.size() < 2) {
            throw new AuraHandledException('Invalid time format: ' + timeString);
        }

        Integer hour = Integer.valueOf(parts[0]);
        Integer minute = Integer.valueOf(parts[1]);

        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;

        return Time.newInstance(hour, minute, 0, 0);
    }
}