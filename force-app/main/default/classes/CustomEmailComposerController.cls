public with sharing class CustomEmailComposerController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getFromAddresses() {
        List<Map<String,String>> out = new List<Map<String,String>>();

        // Org-wide addresses
        try {
            for (OrgWideEmailAddress ow : [
                SELECT Id, Address, DisplayName 
                FROM OrgWideEmailAddress 
                ORDER BY DisplayName NULLS LAST
            ]) {
                out.add(new Map<String,String>{
                    'id' => String.valueOf(ow.Id),
                    'address' => ow.Address,
                    'displayName' => (ow.DisplayName == null ? ow.Address : ow.DisplayName),
                    'type' => 'OrgWide'
                });
            }
        } catch (Exception ex) {}

        // Logged-in user email
        try {
            User u = [
                SELECT Id, Name, Email 
                FROM User 
                WHERE Id = :UserInfo.getUserId() LIMIT 1
            ];
            out.add(new Map<String,String>{
                'id' => String.valueOf(u.Id),
                'address' => u.Email,
                'displayName' => u.Name,
                'type' => 'User'
            });
        } catch (Exception ex) {}

        return out;
    }

    @AuraEnabled
    public static String sendEmailNow(
        List<String> toAddresses,
        List<String> ccAddresses,
        List<String> bccAddresses,
        String subject,
        String htmlBody,
        Id relatedRecordId,
        String fromType,
        String fromId,
        String fromAddress
    ) {
        // Validate: at least 1 recipient
        if ((toAddresses == null || toAddresses.isEmpty()) &&
            (ccAddresses == null || ccAddresses.isEmpty()) &&
            (bccAddresses == null || bccAddresses.isEmpty())) {
            throw new AuraHandledException('At least one recipient required.');
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        if (toAddresses != null && !toAddresses.isEmpty()) mail.setToAddresses(toAddresses);
        if (ccAddresses != null && !ccAddresses.isEmpty()) mail.setCcAddresses(ccAddresses);
        if (bccAddresses != null && !bccAddresses.isEmpty()) mail.setBccAddresses(bccAddresses);

        mail.setSubject(subject);
        mail.setHtmlBody(htmlBody);

        // FROM Preference: Org-Wide > User
        try {
            if (fromType == 'OrgWide' && !String.isBlank(fromId)) {
                mail.setOrgWideEmailAddressId(Id.valueOf(fromId));
            } else if (fromType == 'User' && !String.isBlank(fromAddress)) {
                mail.setReplyTo(fromAddress);
            }
        } catch (Exception e) {}

        if (relatedRecordId != null) {
            try { mail.setWhatId(relatedRecordId); } catch (Exception e) {}
        }

        Messaging.SendEmailResult[] results = Messaging.sendEmail(
            new Messaging.SingleEmailMessage[]{ mail }, false
        );

        if (results != null && results.size() > 0 && results[0].isSuccess()) {
            return 'Email sent successfully';
        } else {
            String err = '';
            if (results != null && results.size() > 0) {
                for (Messaging.SendEmailError e : results[0].getErrors()) {
                    err += e.getStatusCode() + ': ' + e.getMessage() + '\n';
                }
            }
            throw new AuraHandledException('Email failed: ' + err);
        }
    }
}