/*
##################################################### 
# Created By (Date)   : Admin (22 Jul, 2025)
# Description         : This is a Data Factory class for test classes.
# Modifications Log   : 
* Ver    Date              Author         Modification
* 1.0    22 Jul, 2025      Admin          Initial Version
#####################################################
*/

@isTest
public class Recruitment_TestDataFactory {
    
/**
* @description  : Return a Candidate__c record with Name and Email.
* @param name   - Candidate name
* @param email  - Candidate email
* @return Candidate__c instance (not inserted)
*/
    public static Candidate__c createCandidate(String name, String email) {
        return new Candidate__c(
            Last_name__c = name,
            Email__c = email,
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            Phone__c = '1234567890',
            Current_Location__c = 'New York',
            Total_Experience__c = 5,
            Highest_Qualification__c = 'B.Tech',
            IsBillable__c=true
        );
    }
    
/**
* @description  : Return a Project__c record with Description.
* @param description - Project description
* @return Project__c instance (not inserted)
*/
    public static Project__c createProject(String description) {
        return new Project__c(
            Description__c = description,
            No_of_employees__c = 10,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30),
            Budget__c = 50000,
            Actual_Cost__c = 20000,
            Active__c = true
        );
    }
    
/**
* @description  : Return a Recruiter__c record with Name and Email.
* @param name   - Recruiter name
* @param email  - Recruiter email
* @return Recruiter__c instance (not inserted)
*/
    public static Recruiter__c createRecruiter(String lastName, String email) {
        return new Recruiter__c(
            Name = lastName,
            Email__c = email,
            Phone__c = '9876543210',
            Alternate_number__c = '8765432109'
        );
    }
    
/**
* @description  : Return a Work_Order__c record with related Candidate, Project, and Recruiter.
* @param Id   - candidate Id
* @param Id   - project Id
* @param Id   - recruiter Id
* @return Work_Order__c instance (not inserted)
*/
    
    public static Work_Order__c createWorkOrder(Id candidateId, Id projectId, Id recruiterId) {
        return new Work_Order__c(
            Candidate__c = candidateId,
            Project__c = projectId,
            Role_on_Project__c = 'Developer', 
            Recruiter__c = recruiterId,
            Renewed__c = false,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(6),
            Status__c = 'Working', 
            Salary_Offered__c = 50000
        );
    }
    
/**
* @author (date): Admin (20 Aug, 2025)
* @description  : Return a Client__c record with sample data.
* @param name: Name for Client.
* @param email: Email for Client.
* @return Client__c instance (not inserted).
*/
    public static Client__c createClient(String name, String email) {
        return new Client__c(
            Name = name,
            Phone__c = '9999999999',
            Email__c = email,
            isActive__c = true
        );
    }
    
/**
* @author (date): Admin (20 Aug, 2025)
* @description  : Return a Job_Position__c record with sample data.
* @param client   - Related Client__c record (required).
* @param Project  - Related Project__c record (required).
* @return Job_Position__c instance (not inserted).
*/
    public static Job_Position__c createJobPosition(Client__c client, Project__c proj) {
        return new Job_Position__c(
            Job_Title__c = 'Salesforce Developer',
            Client__c = client.Id,
            Employment_Type__c = 'Full-Time',
            Skills_Required__c = 'Salesforce Developer',
            Project__c = proj.Id
       
        );
    }
    
/**
* @author (date): Admin (20 Aug, 2025)
* @description  : Return an Interview__c record with sample data.
* @param candidate - Related Candidate__c record (required).
* @param jobPos    - Related Job_Position__c record (required).
* @return Interview__c instance (not inserted).
*/
    public static Interview__c createInterview(Candidate__c candidate, Job_Position__c jobPos) {
        return new Interview__c(
            Candidate__c = candidate.Id,
            Job_Position__c = jobPos.Id,                   
            Interview_Status__c = 'New',
            Feedback__c = 'Initial feedback'
        );
    }
    
/**
* @author (date): Admin (20 Aug, 2025)
* @description  : Return an Interview__c record with sample data.
* @param candidate - Related Candidate__c record (required).
* @param jobPos    - Related Job_Position__c record (required).
* @return Interview__c instance (not inserted).
*/
    public static Interview__c createInterviewWithoutRound(Candidate__c candidate, Job_Position__c jobPos) {
        return new Interview__c(
            Candidate__c = candidate.Id,
            Job_Position__c = jobPos.Id,                    
            Interview_Status__c = 'New',
            Feedback__c = 'Initial feedback'
        );
    }

/** 
* @author (date): Admin (20 Aug, 2025)
* @description  : Return an Client__c record with sample data.
* @param candidate - Related Candidate__c record (required).
* @param jobPos    - Related Job_Position__c record (required).
* @return Client__c instance.
*/
    public static Client__c createFlexClient(String name, String email) {
        return new Client__c(
            Name = name,
            Phone__c = '9999999999',
            Email__c = email,
            isActive__c = true
        );
    }
 
/* @author (date): Admin (20 Aug, 2025)
* @description  : Return an Job_Position__c record with sample data.
* @return Job_Position__c instance.
*/     
    public static Job_Position__c createFlexJobPosition() {
        return new Job_Position__c(
            Job_Title__c = 'Salesforce Developer',        
            Employment_Type__c = 'Full-Time',
            Skills_Required__c = 'Salesforce, Admin',       
            Status__c = 'Open'          
        );
    }
      public static CustomSetting__c getValidationBypassSetting() {
        CustomSetting__c cs = CustomSetting__c.getOrgDefaults();
        if (cs == null) {
            cs = new CustomSetting__c(
                SetupOwnerId = UserInfo.getOrganizationId()
            );
        }
        return cs;
    }
    
    
     /**
     * @author (date): Admin (9 september, 2025)
     * @description  : Returns an Event record with sample data related to the given Candidate__c.
     * @param candidate - Related Candidate__c record (required).
     * @return Event instance.
     */
    
    public static Event createEvent(Candidate__c candidate,Job_Position__c job) {
        return new Event(
            Subject = 'Team Meeting',
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1),
            	WhatId=job.id,
          
            DurationInMinutes = 60,
          	Candidate__c=candidate.Id,
            Location = 'Conference Room',
            Description = 'Discussion about project status'
        );
    }
}