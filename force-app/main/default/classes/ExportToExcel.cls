public with sharing class ExportToExcel {
    
    @AuraEnabled(cacheable=false)
    public static String exportCandidatesToExcel(List<Id> candidateIds) {
        if (candidateIds == null || candidateIds.isEmpty()) {
            throw new AuraHandledException('No records available for export.');
        }

        // Query candidate fields
        List<Candidate__c> candidates = [
            SELECT Id, Name, Email__c, Phone__c, Total_Experience__c, 
                    Source__c, CreatedDate
            FROM Candidate__c
            WHERE Id IN :candidateIds
        ];

        if (candidates.isEmpty()) {
            throw new AuraHandledException('No candidate data found.');
        }

        // Build CSV-style string (Excel can open .csv easily)
        String header = 'Candidate Name,Email,Phone Number,Experience,Source,Created Date\n';
        String rows = '';
        for (Candidate__c c : candidates) {
            rows += '"' + c.Name + '","' + c.Email__c + '","' + c.Phone__c + '","' +
                    c.Total_Experience__c  + '","' +
                    c.Source__c + '","' + String.valueOf(c.CreatedDate) + '"\n';
        }
        String csvContent = header + rows;

        // Encode content to Base64 for download
        Blob csvBlob = Blob.valueOf(csvContent);
        return EncodingUtil.base64Encode(csvBlob);
    }
}