global class JobPositionEmailHandler implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope env) {

        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        // Parse subject + body
        String subject = email.subject != null ? email.subject : '';
        String body = email.plainTextBody != null ? email.plainTextBody : '';

        Map<String, String> parsed = parseEmail(body);

        // Extract required fields
        String jobTitle = parsed.get('job title');
        String employmentType = parsed.get('employment type');
        String skillsRequired = parsed.get('skills required');
        String clientName = parsed.get('client');

        // Validate essential fields
        if(String.isBlank(jobTitle) || String.isBlank(employmentType) || String.isBlank(clientName)) {
            System.debug('❌ Required field missing in email.');
            return result;
        }

        // Find Client record by Name
        Id clientId;
        try {
            clientId = [
                SELECT Id 
                FROM Client__c 
                WHERE Name = :clientName 
                LIMIT 1
            ].Id;
        } catch(Exception e) {
            System.debug('❌ Client not found: ' + clientName);
            return result;
        }

        // Create Job Position record
        Job_Position__c jp = new Job_Position__c();
        jp.Job_Title__c = jobTitle;
        jp.Employment_Type__c = employmentType;
        jp.Skills_Required__c = skillsRequired;
        jp.Client__c = clientId;

        insert jp;

        System.debug('✅ Job Position created: ' + jp.Id);

        return result;
    }

    // Helper parser
    private static Map<String, String> parseEmail(String body) {
        Map<String, String> data = new Map<String, String>();
        List<String> lines = body.split('\n');

        for(String line : lines) {
            if(line.contains(':')) {
                List<String> parts = line.split(':', 2);
                String key = parts[0].trim().toLowerCase();
                String value = parts[1].trim();
                data.put(key, value);
            }
        }
        return data;
    }
}