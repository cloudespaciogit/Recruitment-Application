/**
 * @File Name          : InterviewCleanupAndReminderBatch.cls
 * @Description        : Batch and schedulable Apex class that deletes old Interview__c records 
 *                       and sends reminder emails/notifications to owners before cleanup. 
 *                       Uses values from RecruitmentAutomationVariable__mdt for configuration.
 * @Author             : Dixit
 * @Created On         : 09-september-2025
 * @Last Modified On   : 15-october-2025
 * ==============================================================================
 * Ver | Date         | Author        | Modification
 * ==============================================================================
 * 1.0 | Oct 15, 2025  |              | Initial Version
 */

global class InterviewCleanupAndReminderBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {
    
    @TestVisible private static Set<Id> ownerIds = new Set<Id>();
    
    @TestVisible    private Integer reminderDays;
    @TestVisible   private Integer cleanupDays;
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        RecruitmentAutomationVariable__mdt config = RecruitmentAutomationVariable__mdt.getInstance('Sender_Email');
        if (config == null) {
            reminderDays = 80; 
            cleanupDays = 90; 
        } else {
            reminderDays = (Integer) config.Reminder_Days_Before_Cleanup__c;
            cleanupDays = (Integer) config.Cleanup_Age_in_Days__c;
        }
        Date reminderDate = System.today().addDays(-reminderDays);
        Date cleanupDate = System.today().addDays(-cleanupDays);
        return Database.getQueryLocator([
            SELECT Id, OwnerId, CreatedDate
            FROM Interview__c
            WHERE CreatedDate <= :cleanupDate
            OR CreatedDate <= :reminderDate
        ]);
    }
    global void execute(Database.BatchableContext bc, List<Interview__c> interviews) {
        Date reminderDate = System.today().addDays(-reminderDays);
        Date cleanupDate = System.today().addDays(-cleanupDays);
        List<Interview__c> toDeleteList = new List<Interview__c>();
        Set<Id> reminderOwnerIds = new Set<Id>();
        for (Interview__c i : interviews) {
            Date createdDateOnly = i.CreatedDate.date();
            
            if (i.OwnerId != null) ownerIds.add(i.OwnerId);
            
            
            if (createdDateOnly <= cleanupDate) {
                toDeleteList.add(i);
            }
            if (i.OwnerId != null && createdDateOnly <= reminderDate) { 
                reminderOwnerIds.add(i.OwnerId);
            }
        }
        
        if (!reminderOwnerIds.isEmpty()) {
            sendReminderEmailsAndNotifications(reminderOwnerIds);
        }
        if (!toDeleteList.isEmpty()) {
            try{
                delete toDeleteList;
            }
            catch (Exception e) {
                System.debug('Error inserting events: ' + e.getMessage());
            }
        }
    }
    global void finish(Database.BatchableContext bc) {
        if (ownerIds.isEmpty()) return;
        System.debug('ownerIds'+ownerIds);
        List<User> users = [
            SELECT Id, Email
            FROM User
            WHERE Id IN :ownerIds
            AND IsActive = true
        ];
        System.debug('users'+users);
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND Id IN :ownerIds
        ];
        System.debug('queues'+queues);
        Set<String> emailAddressesSet = new Set<String>();
        for (User u : users) {     
            if (u.Email != null) emailAddressesSet.add(u.Email);
        }
        if (!queues.isEmpty()) {
            List<GroupMember> members = [
                SELECT UserOrGroupId, GroupId
                FROM GroupMember
                WHERE GroupId IN :queues
            ];
            Set<Id> userIdsFromQueues = new Set<Id>();
            for (GroupMember gm : members) {
                if (gm.UserOrGroupId.getSObjectType() == User.sObjectType) {//checksobject
                    userIdsFromQueues.add(gm.UserOrGroupId);
                }
            }
            if (!userIdsFromQueues.isEmpty()) {
                for (User u : [SELECT Email FROM User WHERE Id IN :userIdsFromQueues AND IsActive = true]) {
                    if (u.Email != null) emailAddressesSet.add(u.Email);
                }
            }
        }
        if (!emailAddressesSet.isEmpty()) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>(emailAddressesSet));
            mail.setSubject('Interview Cleanup Completed');
            mail.setPlainTextBody('Interview records older than ' + cleanupDays + ' days have been deleted successfully.');
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }
    }
    
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new InterviewCleanupAndReminderBatch(), 200);
    }
    
    @TestVisible
    private void sendReminderEmailsAndNotifications(Set<Id> ownerIds) {
        if (ownerIds.isEmpty()) return;
        List<User> users = [
            SELECT Id, Email
            FROM User
            WHERE Id IN :ownerIds
            AND IsActive = true
        ];
        
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND Id IN :ownerIds
        ];
        
        Set<String> emailAddressesSet = new Set<String>();
        for (User u : users) {
            if (u.Email != null) emailAddressesSet.add(u.Email);
        }
        if (!queues.isEmpty()) {
            List<GroupMember> members = [
                SELECT UserOrGroupId, GroupId
                FROM GroupMember
                WHERE GroupId IN :queues
            ];
            Set<Id> userIdsFromQueues = new Set<Id>();
            for (GroupMember gm : members) {
               
                if (gm.UserOrGroupId.getSObjectType() == User.sObjectType) {
                    userIdsFromQueues.add(gm.UserOrGroupId);
                }
            }
            if (!userIdsFromQueues.isEmpty()) {
                for (User u : [SELECT Email FROM User WHERE Id IN :userIdsFromQueues AND IsActive = true]) {
                    if (u.Email != null) emailAddressesSet.add(u.Email);
                }
            }
        }
        if (!emailAddressesSet.isEmpty()) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>(emailAddressesSet));
            mail.setSubject('Reminder: Upcoming Deletion/Archival of Interview Records');
              String body = 'Hi Team,\n\n' +
                      'This is a reminder that interview records older than 3 months will be automatically deleted as part of our regular data cleanup process.\n\n' +
                      'Details:\n' +
                      'Scheduled Date: ' + System.today().addDays(reminderDays) + '\n' +
                      'Scope: All interview records created before ' + System.today().addDays(-cleanupDays) + '\n\n' +
                      'Action Required: Review and retain any records you still need before the scheduled date.\n\n' +
                      'After this process runs, the affected data will no longer be available in the active system.\n\n' +
                      'Please ensure that any important information is backed up or flagged for retention. If you have any questions or need assistance, please contact the System Administrator.\n\n' +
                      'Thank you for your cooperation.\n\n' +
                      'Best regards,\nSystem Notification – Salesforce Recruitment Portal';
            
              mail.setPlainTextBody(body);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }
        if (!users.isEmpty()) {
            CustomNotificationType notifType = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = 'Interview_Cleanup_Reminder'
                LIMIT 1
            ];
            if (notifType != null) {
                for (User u : users) {
                    Messaging.CustomNotification cn = new Messaging.CustomNotification();
                   cn.setTitle('Upcoming Data Cleanup');
                cn.setBody('⚠️ Upcoming Data Cleanup: Interview records older than 3 months will be deleted on ' 
                           + System.today().addDays(reminderDays) 
                           + '. Review records if you wish to retain them. Contact your Salesforce Administrator for details.');
                    cn.setNotificationTypeId(notifType.Id);
                    cn.setSenderId(UserInfo.getUserId());
                    cn.setTargetId(u.Id);
                    cn.send(new Set<String>{ u.Id });
                }
            }
        }
    }
}