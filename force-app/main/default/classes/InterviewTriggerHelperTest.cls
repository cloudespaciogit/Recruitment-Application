/*
############################################################################   
# Created By (Date)   : Admin (26 Aug, 2025)
# Description         : Test class to verify InterviewTriggerHelper logic.
# Modifications Log   : 
* Ver    Date              Author         Modification
* 1.0    26 Aug, 2025      Admin          Updated for revised helper methods
#############################################################################
*/

@IsTest
public class InterviewTriggerHelperTest {    
    
    @testSetup
    static void setupData() {
        
        
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        // Insert test user
        User u = new User(
            FirstName = 'Test',
            LastName = 'Owner',
            Alias = 'tuser',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            CommunityNickname = 'testuser' + System.currentTimeMillis(),
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        
        
        Client__c client = Recruitment_TestDataFactory.createClient('Test Client', 'client@example.com');
        Project__c project = Recruitment_TestDataFactory.createProject('Test Project');
        Candidate__c cand = Recruitment_TestDataFactory.createCandidate('Test Candidate', 'candidate@example.com');
        Candidate__c cand1 = Recruitment_TestDataFactory.createCandidate('Test Candidate1', 'candidate2@example.com');
        Candidate__c cand2 = Recruitment_TestDataFactory.createCandidate('Test Candidate2', 'candidate1@example.com');
        insert new List<SObject>{ client, project, cand,cand1,cand2 };
            
            
            
            
            Job_Position__c job = Recruitment_TestDataFactory.createJobPosition(client, project);
        job.Client__c = client.Id; 
        insert job;
        
        //  Event ev=Recruitment_TestDataFactory.createEvent('a03dM000014Fc5NQAS',job);
        //insert ev;
        Interview__c inter = Recruitment_TestDataFactory.createInterview(cand, job);
        inter.Interview_Date__c = DateTime.now().addDays(1);  
        inter.Interview_Mode__c = 'Online';                     
        insert inter;
        
        
        Interview__c todayInterview = Recruitment_TestDataFactory.createInterview(cand1, job);
        todayInterview.OwnerId = u.Id;
        todayInterview.Interview_Date__c = System.now().addDays(1);
        insert todayInterview;
        System.debug('todayInterview'+todayInterview);
        
        Interview__c oldInterview = Recruitment_TestDataFactory.createInterview(cand2, job);
        oldInterview.OwnerId = u.Id;
        insert oldInterview;
        Test.setCreatedDate(oldInterview.Id, System.now().addMonths(-4));
        
        System.debug('todayInterview: ' + todayInterview);
        System.debug('oldInterview: ' + oldInterview);
        
      
        
        
        
        
        
        
        
        
        
        
        
    }
   
    
    
    
    /*
* @description : test HandleStatusChange Method : Ensures chatter post is NOT created if status or round is unchanged.
*/
    @IsTest
    static void testHandleStatusChange_NoChange_NoPost() {
        Interview__c interview = [
            SELECT Id, Candidate__c, Feedback__c, Round__c, Interview_Status__c 
            FROM Interview__c LIMIT 1
        ];
        
        Test.startTest();
        interview.Feedback__c = 'Test Feedback No Change';
        update interview;
        Test.stopTest();
        
        List<FeedItem> posts = [
            SELECT Id
            FROM FeedItem
            WHERE ParentId = :interview.Candidate__c
        ];
        System.assertEquals(0, posts.size(), 'No chatter post should be created if status and round are unchanged.');
    }
    
    /*
* @description : test HandleStatusChange Method : Ensures chatter post is created when status changes and feedback is provided.
*/
    @IsTest
    static void testHandleStatusChange_ChangeStatus() {
        Interview__c interview = [
            SELECT Id, Candidate__c, Round__c, Interview_Status__c 
            FROM Interview__c LIMIT 1
        ];
        
        Test.startTest();
        interview.Interview_Status__c = RecruitmentApp_Constants.INTERVIEW_STATUS_INTERVIEWING;
        interview.Feedback__c = 'Candidate showed good communication skills.';
        update interview;
        Test.stopTest();
        
        List<FeedItem> posts = [
            SELECT Id, Body, ParentId
            FROM FeedItem
            WHERE ParentId = :interview.Candidate__c
        ];
        System.assertEquals(1, posts.size(), 'Chatter post should be created when status changes.');
        System.assert(posts[0].Body.contains('Feedback:'), 'Chatter body should include Feedback text.');
    }
    
    /*
* @description : test HandleStatusChange Method :Ensures "Chatter post" are created when no interview-"round" value is provided.
*/
    @IsTest
    static void testHandleStatusChange_roundvaluenull() { 
        Job_Position__c jobpos = [
            SELECT Id
            FROM Job_Position__c
            LIMIT 1
        ]; 
        System.debug('jobpos'+jobpos);
        Candidate__c newcand = Recruitment_TestDataFactory.createCandidate('NewTestCandidate', 'NewTestCandidate@example.com');
        newcand.Phone__c = '9234567891';
        insert newcand;
        System.debug('newcand'+newcand);
        Interview__c rec = Recruitment_TestDataFactory.createInterviewWithoutRound(newcand, jobpos);
        insert rec;
        
        Test.startTest();
        rec.Interview_Status__c = RecruitmentApp_Constants.INTERVIEW_STATUS_INTERVIEWING;
        rec.Feedback__c = 'Candidate showed good communication skills.';
        update rec;
        Test.stopTest();
        
        List<FeedItem> posts = [
            SELECT Id, Body, ParentId
            FROM FeedItem
            WHERE ParentId = :rec.Candidate__c
        ];
        System.assertEquals(1, posts.size(), 'Chatter post should be created when status changes.');
        System.assert(posts[0].Body.contains('Feedback:'), 'Chatter body should include Feedback text.');
    }
    
    /*
* @description : test HandleStatusChange Method :Ensures no Work Order is created when feedback is exceeding feed character limit.
*/
    @isTest
    private static void testhandleStatusChange_BodyTooLong() {
        Interview__c interview = [
            SELECT Id, Candidate__c, Job_Position__r.Project__c, Job_Position__r.Job_Title__c
            FROM Interview__c LIMIT 1
        ];
        String largeFeedback = String.valueOf('X').repeat(11000);
        
        Test.startTest();
        interview.Interview_Status__c = RecruitmentApp_Constants.INTERVIEW_STATUS_OFFERED;
        interview.Feedback__c = largeFeedback;
        update interview;     
        Test.stopTest();
        
        List<FeedItem> posts = [
            SELECT Id
            FROM FeedItem
            WHERE ParentId = :interview.Candidate__c
        ];
        System.assertEquals(0, posts.size(), 'Chatter post should fail due to body length');
    }
    
    /*
* @description : test CreateWorkOrder Method :Ensures a new "Work Order" is created when status changes to Hired.
*/
    @IsTest
    static void testCreateWorkOrder_Success() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Interview__c interview = [
            SELECT Id, Candidate__c, Job_Position__r.Project__c, Job_Position__r.Job_Title__c 
            FROM Interview__c LIMIT 1
        ];
        
        System.runAs(u) {
            Test.startTest();
            interview.Interview_Status__c = RecruitmentApp_Constants.INTERVIEW_STATUS_HIRED;
            interview.Feedback__c = 'Hired for the project role.';
            update interview;
            Test.stopTest();
        }
        
        List<Work_Order__c> workOrders = [
            SELECT Candidate__c, Project__c, Status__c, Role_on_Project__c
            FROM Work_Order__c
            WHERE Candidate__c = :interview.Candidate__c
        ];
        
        System.assertEquals(1, workOrders.size(), 'One work order should be created upon hiring.');
        System.assertEquals(
            RecruitmentApp_Constants.WORKORDER_STATUS_NEW, 
            workOrders[0].Status__c, 
            'Work Order status should be New.'
        );
    }
    
    /*
* @description : test CreateWorkOrder Method :Ensures no Work Order is created when status changes to other values except "Hired".
*/
    @IsTest
    static void testCreateWorkOrder_NoWorkOrder() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Interview__c interview = [
            SELECT Id, Candidate__c, Job_Position__r.Project__c, Job_Position__r.Job_Title__c 
            FROM Interview__c LIMIT 1
        ];
        
        System.runAs(u) {
            Test.startTest();
            interview.Interview_Status__c = RecruitmentApp_Constants.INTERVIEW_STATUS_OFFERED;
            interview.Feedback__c = 'Offered for the project role.';
            update interview;
            Test.stopTest();
        }
        List<Work_Order__c> workOrders = [
            SELECT Candidate__c, Project__c, Status__c, Role_on_Project__c
            FROM Work_Order__c
            WHERE Candidate__c = :interview.Candidate__c
        ];
        
        System.assertEquals(0, workOrders.size(), 'No work order should be created upon offering.');        
    }
    
    /*
* @description : test EventUpdated Method : Ensures that when Interview is updated, 
*               the related Event record’s StartDateTime, EndDateTime, and Location 
*               are updated accordingly.
*/
    
    
    @IsTest
    static void testEventUpdated() {
        Interview__c interview = [SELECT Id, Candidate__c, Job_Position__c, Interview_Date__c, Interview_Mode__c FROM Interview__c LIMIT 1];
        System.debug('interview'+interview);
        
        
        
        Test.startTest();
        
        DateTime newDate = interview.Interview_Date__c != null ? interview.Interview_Date__c.addDays(2) : DateTime.now().addDays(2);
        interview.Interview_Date__c = newDate;
        System.debug('newDate12'+interview.Interview_Date__c);
        interview.Interview_Mode__c = 'Online';
        update interview;
        Event updated = [SELECT Id, Candidate__c,StartDateTime, EndDateTime, Location  FROM Event WHERE Candidate__c = :interview.Candidate__c];
        Test.stopTest();
        
        
        System.assertEquals(newDate, updated.StartDateTime, 'Event StartDateTime should be updated');
        System.assertEquals(newDate.addHours(1), updated.EndDateTime, 'Event EndDateTime should be updated');
        System.assertEquals('Online', updated.Location, 'Event Location should be updated');
    }
    


    @IsTest
    static void testInterviewConflictCoverage() {
        
        Interview__c existingInterview = [
            SELECT Id,
            Candidate__c,
            Job_Position__c,
            Job_Position__r.Client__r.Id,
            Job_Position__r.Project__r.Id
            FROM Interview__c
            LIMIT 1
        ];
        
      
        Job_Position__c anotherJob = Recruitment_TestDataFactory.createJobPosition(
            existingInterview.Job_Position__r.Client__r,
            existingInterview.Job_Position__r.Project__r
        );
        insert anotherJob;
        
        
        DateTime startDT = DateTime.now().addDays(1).addHours(10);
        DateTime endDT = startDT.addHours(1);
        Event conflictingEvent = new Event(
            WhatId = anotherJob.Id,
            Candidate__c = existingInterview.Candidate__c,
            Subject = 'Conflicting Interview',
            StartDateTime = startDT,
            EndDateTime = endDT
        );
        insert conflictingEvent;
        
        
        existingInterview.Interview_Date__c = startDT;
        
        Test.startTest();
        try {
            update existingInterview;
        } catch (Exception e) {
            System.debug('Expected conflict caught: ' + e.getMessage());
        }
        Test.stopTest();
    }
    


    
}