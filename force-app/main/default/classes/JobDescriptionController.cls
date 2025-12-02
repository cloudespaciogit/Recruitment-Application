/**
* @File Name : JobDescriptionController.cls
* @Description : Apex class works as a controller for LWC/Flow to integrate Salesforce with OpenAI (ChatGPT) for generating job descriptions dynamically.
* @Author : AJay Kaurav
* @Last Modified By :
* @Last Modified On : September 25, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 25, 2025 |   | Initial Version
**/

public with sharing class JobDescriptionController {
    
    @AuraEnabled(cacheable=true)
    public static Job_Position__c getJobDetails(Id jobId) {
        return [SELECT Id, Skills_Required__c, Job_description__c, Aditional_Skills__c, Qualification__c, Experience_Required__c, Soft_skills__c FROM Job_Position__c WHERE Id = :jobId LIMIT 1];
    }

    @AuraEnabled
    public static String generateJobDescription(Id jobId, String skillsData, String additional, String qualification, Decimal experience, String soft, String tone, String length, String lengthsize) {
        Job_Position__c job = [SELECT Skills_Required__c, Job_description__c, Aditional_Skills__c, Qualification__c, Experience_Required__c, Soft_skills__c FROM Job_Position__c WHERE Id = :jobId LIMIT 1];
        String skills         = (skillsData   != null) ? skillsData   : job.Skills_Required__c;
        String additionalskill= (additional   != null) ? additional   : job.Aditional_Skills__c;
        String qualifications = (qualification!= null) ? qualification: job.Qualification__c;
        Decimal experiences   = (experience   != null) ? experience : job.Experience_Required__c;
        String softskill      = (soft         != null) ? soft         : job.Soft_skills__c;

        String prompt = 'You are a recruiter assistant. Generate a professional job description for the following skills: ' + skills +
        '. additionalskill: ' + additionalskill +
        '. qualification: ' + qualifications +
        '. Experience: ' + experiences +
        '. softskill: ' + softskill +
        '. Tone: ' + tone +
        '. Length: ' + length +
		'. Lengthsize: ' + lengthsize +
        '. Only include these sections, each on a new line: ' +
        'Job Description:, Key Responsibilities:, Qualifications:, ' +
        'and at the end include: "At Cloudespacio Software Private Limited, we value diversity and are dedicated to fostering an inclusive workplace where every employee can thrive". ' +
        'Do NOT include company overview, "How to apply" section, or any other content.'+ 'Do NOT include any Markdown, bold, asterisks, or other formatting.';
        return OpenAIService.generateJobDescription(prompt);
    }

    @AuraEnabled
    public static void saveJobDescription(Id jobId, String description ) {
		
      try {
        if (jobId == null) {
            throw new AuraHandledException('Job Id is required.');
        }

        Job_Position__c job = new Job_Position__c(
            Id = jobId,
            Job_Description__c = description 
        );

        update job;
    } catch (Exception ex) {
        // Developer debug log
        System.debug('Error in saveJobDescription: ' + ex.getMessage());

        // Return a clean error to LWC/Flow
        throw new AuraHandledException('Failed to save job description: ' + ex.getMessage());
    }
}
}