/**
* @File Name : LinkedInService.cls
* @Description : Apex class works as a controller for LWC/Flow to integrate Salesforce with LinkedIn.
*                Generates LinkedIn Job Post dynamically using provided Job data.
* @Author : AJAY Kaurav
* @Last Modified By : AJAY Kaurav
* @Last Modified On : November 24, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 26, 2025 | AJAY Kaurav | Initial Version
**/

public with sharing class LinkedInService {

    /**
    * @Author : AJAY Kaurav
    * @Created On : September 26, 2025
    * @Description : Fetch Job Details (Skills, Qualification etc.) for generating LinkedIn post.
    * @Params : jobId (Job_Position__c Record Id)
    * @Return : Job_Position__c record
    */
    @AuraEnabled(cacheable=true)
    public static Job_Position__c getJobDetailsForLinkedin(Id jobId) {
        
            return [
                SELECT Skills_Required__c, Employment_Type__c, Mode__c, Work_Mode__c,
                       Job_Title__c, Shift_Time__c, Qualification__c,
                       Experience_Required__c, Soft_skills__c, Aditional_Skills__c
                FROM Job_Position__c WHERE Id = :jobId LIMIT 1
            ];
       
    }


    /**
    * @Author : AJAY Kaurav
    * @Created On : September 26, 2025
    * @Description : Gets Company Name from Salesforce Organization object.
    * @Return : Company Name as String
    */
    @AuraEnabled(cacheable=true)
    public static String getCompanyName() {
        
            return [SELECT Name FROM Organization LIMIT 1].Name;
        
    }


    /**
    * @Author : AJAY Kaurav
    * @Created On : September 26, 2025
    * @Description : Creates a LinkedIn post using provided content text.
    * @Params : String content -> Post Text to publish on LinkedIn
    * @Return : LinkedIn API Response Body (JSON String)
    */
    @AuraEnabled
    public static String createPost(String content) {
        try {
            System.debug('Content Received For Post: ' + content);

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
            System.debug('LinkedIn Callout Error: ' + ex.getMessage());
            throw new AuraHandledException('LinkedIn call failed. Please try later!');
        }
        
    }
}