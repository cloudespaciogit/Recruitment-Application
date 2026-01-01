/**
 * @description Apex controller for LWC/Flow to integrate Salesforce with LinkedIn.
 *              Generates LinkedIn job posts dynamically using job data.
 * @author AJAY Kaurav
 * @since 2025-09-26
 */
public without sharing class LinkedInService {
    /**
     * @description Fetches job details required for generating a LinkedIn post.
     * @param jobId Id of Job_Position__c record
     * @return Job_Position__c Job position record containing skills and qualifications
     */
    @AuraEnabled(cacheable=true)
    public static Job_Position__c getJobDetailsForLinkedin(Id jobId) {
        return [
            SELECT Skills_Required__c, Employment_Type__c, Mode__c, Work_Mode__c,
                    Job_Title__c, Shift_Time__c, Qualification__c,
                    Experience_Required__c, Soft_skills__c, Aditional_Skills__c
            FROM Job_Position__c WHERE Id = :jobId WITH SECURITY_ENFORCED LIMIT 1
        ];   
    }
    /**
     * @description Retrieves the company name from the Salesforce Organization object.
     * @return String Company name
     */
    @AuraEnabled(cacheable=true)
    public static String getCompanyName() { 
        //return [SELECT Name FROM Organization WITH SECURITY_ENFORCED LIMIT 1].Name;
          return UserInfo.getOrganizationName();
    }
    /**
     * @description Creates a LinkedIn post using the provided content text.
     * @param content Text content to be published on LinkedIn
     * @return String LinkedIn API response body as JSON string
     */
    @AuraEnabled
    public static String createPost(String content) { 
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Linkedin_Named/v2/ugcPosts'); // Salesforce Named Credential
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            String body = JSON.serialize(new Map<String, Object>{
                'author' => 'urn:li:person:gllxQyVs6B',
                'lifecycleState' => 'PUBLISHED',
                'specificContent' => new Map<String, Object>{
                    'com.linkedin.ugc.ShareContent' => new Map<String, Object>{
                        'shareCommentary' => new Map<String, Object>{ 'text' => content },
                        'shareMediaCategory' => 'NONE'
                    }
                },
                'visibility' => new Map<String, Object>{
                    'com.linkedin.ugc.MemberNetworkVisibility' => 'PUBLIC'
                }
            });
            req.setBody(body);
            Http http = new Http();
            HttpResponse res = http.send(req);
            return res.getBody();
        }
        catch (CalloutException ex) {
            throw new AuraHandledException('LinkedIn call failed. Please try later!');
        }  
    }
}