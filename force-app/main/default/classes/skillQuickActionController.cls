/**
* @File Name : skillQuickActionController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : October 6, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 6, 2025 |   | Initial Version
**/

public with sharing class skillQuickActionController {
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getCandidateSkills(Id candidateId, String objName) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate Id is required.');
        }

        Map<String, List<String>> mainResult = new Map<String, List<String>>();

        if (objName == 'Candidate') {
            Candidate__c cand = [
                SELECT Id, Skills__c, Soft_Skills__c
                FROM Candidate__c
                WHERE Id = :candidateId
                WITH USER_MODE
                LIMIT 1
                
            ];

            mainResult = buildSkillMap(cand.Skills__c, cand.Soft_Skills__c);
            System.debug('Cand RESULT --> ' + mainResult);
        } 
        else if (objName == 'Job Position') {
            Job_Position__c jp = [ 
                SELECT Id, Skills_Required__c, Soft_Skills__c
                FROM Job_Position__c 
                WHERE Id = :candidateId
                WITH USER_MODE
                LIMIT 1
                
            ];

            mainResult = buildSkillMap(jp.Skills_Required__c, jp.Soft_Skills__c);
            System.debug('JP RESULT --> ' + mainResult);
        }
        else {
            System.debug('Invalid objName passed: ' + objName);
        }

        return mainResult;
    }

    @AuraEnabled
    public static void updateCandidateSkills(Id candidateId, String objName, List<String> skills, List<String> softSkills) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate Id is required.');
        }
        if(objName == 'Candidate'){
            Candidate__c cand = new Candidate__c(Id = candidateId);
            cand.Skills__c = (skills != null && !skills.isEmpty()) ? String.join(skills, ', ') : null;
            cand.Soft_Skills__c = (softSkills != null && !softSkills.isEmpty()) ? String.join(softSkills, ', ') : null;

 
            
            try {
                Database.update(cand, AccessLevel.USER_MODE);
            }
            catch (Exception e) {
                throw new AuraHandledException(e.getMessage());                
            } 
            //update cand;
            //update as user cand;
            
        }
        else if(objName == 'Job Position'){
            Job_Position__c jp = new Job_Position__c(Id = candidateId);
            jp.Skills_Required__c = (skills != null && !skills.isEmpty()) ? String.join(skills, ', ') : null;
            jp.Soft_Skills__c = (softSkills != null && !softSkills.isEmpty()) ? String.join(softSkills, ', ') : null;

            try {
                Database.update(jp, AccessLevel.USER_MODE);
            }
            catch (Exception e) {
                throw new AuraHandledException(e.getMessage());                
            } 
            //update jp;
            //update as user jp;
        }
        else {
            throw new AuraHandledException('Invalid object name provided.');
        }
        
    }


    // ---------------- Helper Method ----------------
    private static Map<String, List<String>> buildSkillMap(String skills, String softSkills) {
        Map<String, List<String>> result = new Map<String, List<String>>();
        result.put('skills', new List<String>());
        result.put('softSkills', new List<String>());

        if (String.isNotBlank(skills)) {
            for (String s : skills.split(',')) {
                if (String.isNotBlank(s)) {
                    result.get('skills').add(s.trim());
                }
            }
        }

        if (String.isNotBlank(softSkills)) {
            for (String s : softSkills.split(',')) {
                if (String.isNotBlank(s)) {
                    result.get('softSkills').add(s.trim());
                }
            }
        }

        return result;
    }
}