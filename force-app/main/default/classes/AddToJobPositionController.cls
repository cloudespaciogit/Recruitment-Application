/**
* @File Name : AddToJobPositionController.cls
* @Author : Dixit Anand
* @Last Modified By :
* @Last Modified On :November 26, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 25, 2025 |   | Initial Version
**/


public with sharing class AddToJobPositionController {
    
    @AuraEnabled(cacheable=true)
    public static List<Job_Position__c> getJobPositions(Id candidateId, String searchKey) {
        
        List<Job_Position__c> resultJobs = new List<Job_Position__c>();
         
        if (!String.isBlank(searchKey)) {
            String likeKey = '%' + searchKey + '%';
            resultJobs = [
                SELECT Id, Name, Job_Title__c, CreatedDate, Skills_Required__c
                FROM Job_Position__c
                WHERE Name LIKE :likeKey OR Job_Title__c LIKE :likeKey
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            
            return resultJobs;
        }
        
        
        if (candidateId == null) {
            
            return [
                SELECT Id, Name, Job_Title__c, CreatedDate, Skills_Required__c
                FROM Job_Position__c
                ORDER BY CreatedDate DESC
            ];
        }
        
        
        Candidate__c cand = [
            SELECT Id, Designation__c, Skills__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];
        
        
        Set<String> candidateSkills = new Set<String>();
        if (!String.isBlank(cand.Skills__c)) {
            for (String skill : cand.Skills__c.split('[,;]')) {
                if (!String.isBlank(skill)) {
                    candidateSkills.add(skill.trim().toLowerCase());
                }
            }
        }
        
        
        
        List<Job_Position__c> allJobs = [
            SELECT Id, Name, Job_Title__c, CreatedDate, Skills_Required__c
            FROM Job_Position__c
            ORDER BY CreatedDate DESC
        ];
        
        
        
        for (Job_Position__c job : allJobs) {
            Boolean titleMatch = false;
            Boolean skillMatch = false;
            
            
            if (!String.isBlank(job.Job_Title__c) && !String.isBlank(cand.Designation__c)) {
                String jobTitleNorm = job.Job_Title__c.toLowerCase().replaceAll('\\s+', ' ').trim();
                String candDesigNorm = cand.Designation__c.toLowerCase().replaceAll('\\s+', ' ').trim();
                titleMatch = jobTitleNorm.contains(candDesigNorm);
            }
            
            
            Set<String> jobSkills = new Set<String>();
            if (!String.isBlank(job.Skills_Required__c)) {
                for (String skill : job.Skills_Required__c.split('[,;]')) {
                    if (!String.isBlank(skill)) {
                        jobSkills.add(skill.trim().toLowerCase());
                    }
                }
            }
            
            
            for (String skill : candidateSkills) {
                if (jobSkills.contains(skill)) {
                    skillMatch = true;
                    break;
                }
            }
            
            if (titleMatch || skillMatch) {
                resultJobs.add(job);
            }
        }
        
        
        if (resultJobs.isEmpty()) {
            resultJobs = allJobs;
        }
        
        
        return resultJobs;
    }
    
    @AuraEnabled
    public static void addCandidateToJobs(Id candidateId, List<Id> jobIds) {
        
        if (candidateId == null || jobIds == null || jobIds.isEmpty()) {
            return;
        }
        
        
        Map<Id, String> alreadyAssignedJobs = new Map<Id, String>();
        
        for (Interview__c intr : [
            SELECT Id, Job_Position__r.Name, Job_Position__c
            FROM Interview__c 
            WHERE Candidate__c = :candidateId 
            AND Job_Position__c IN :jobIds
        ]) {
            alreadyAssignedJobs.put(intr.Job_Position__c, intr.Job_Position__r.Name);
        }
        
        
        List<Interview__c> interviewsToInsert = new List<Interview__c>();
        for (Id jobId : jobIds) {
            if (!alreadyAssignedJobs.containsKey(jobId)) {
                interviewsToInsert.add(new Interview__c(
                    Candidate__c = candidateId,
                    Job_Position__c = jobId
                ));
            }
        }
        
        
        if (interviewsToInsert.isEmpty() && !alreadyAssignedJobs.isEmpty()) {
            String msg = 'Candidate already assigned to: ' +
                String.join(new List<String>(alreadyAssignedJobs.values()), ', ');
            
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
            
        }
        
        
        insert interviewsToInsert;
        
   
        
        if (!alreadyAssignedJobs.isEmpty()) {
            String msg = 'Some Job Positions were already assigned: ' +
                String.join(new List<String>(alreadyAssignedJobs.values()), ', '); 
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
            
        }
    }
    
}