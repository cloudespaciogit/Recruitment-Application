/*
*#################################################################
* Created By (Date) : Admin (26 Aug, 2025)
* Description       : Trigger Helper Class for Interview__c Object.
* Modifications Log :
* Ver   Date         Author   Modification
* 1.0   26 Aug, 2025 Admin    Initial Version
################################################################# 
*/
public class InterviewTriggerHelper {
    /*
* ==================================================================================
* Method  : handleStatusChange
* Created By (Date) : Kshitiz (26 Aug, 2025)
* Purpose : Compares Trigger.oldMap with Trigger.newMap.
*           If changes found in status field then create Chatter post of 'feedback'
*           on Candidate__c Object.
* Params  : newList - Trigger.new, oldMap - Trigger.oldMap
* Modifications Log :
* Ver   Date          Author     Modification
* 1.0   26 Aug, 2025  Kshitiz    Initial Version
* ================================================================================== 
*/
    public static void handleStatusChange(List<Interview__c> newList, Map<Id, Interview__c> oldMap) {
        
        Set<Id> interviewsToQuery = new Set<Id>();
        
        for (Interview__c newRec : newList) { 
            Interview__c oldRec = oldMap.get(newRec.Id);
            if (String.isNotBlank(newRec.Interview_Status__c) &&
                newRec.Candidate__c != null && 
                String.isNotBlank(newRec.Feedback__c) &&                  
                ((newRec.Interview_Status__c != oldRec.Interview_Status__c) || (newRec.Round__c != oldRec.Round__c))) {                    
                    interviewsToQuery.add(newRec.Id); 
                }
        }
        
        if (interviewsToQuery.isEmpty()) return;
        
        List<Interview__c> interviewlist = [
            SELECT Id, Feedback__c, Interview_Status__c, Round__c, Candidate__c, Job_Position__r.Client__r.Name, Job_Position__r.Job_Title__c
            FROM Interview__c
            WHERE Id IN :interviewsToQuery ];
        
        List<FeedItem> chatterPosts = new List<FeedItem>();
        
        for (Interview__c rec : interviewlist) {
            String clientName      = rec.Job_Position__r.Client__r.Name;
            String jobTitle        = rec.Job_Position__r.Job_Title__c;
            String interviewStatus = rec.Interview_Status__c ;
            String roundName       = rec.Round__c;
            String feedbackText    = rec.Feedback__c;
            
            FeedItem post = new FeedItem();
            post.ParentId = rec.Candidate__c;
            post.Type     = 'TextPost';
            post.IsRichText = true;
            if (roundName != null){
                post.Body = 'Interview feedback by <b>' + clientName + 
                    '</b> for <b>' + jobTitle + '</b> job ' +
                    'at the <b>' + interviewStatus + '</b> stage' +
                    ' in the <b>' + roundName + '</b> round.' +               
                    '<p>-</p>' + 
                    ' <p><b>Feedback:</b> ' + feedbackText + '</p>';	   
            }
            else if (roundName == null){
                post.Body = 'Interview feedback by <b>' + clientName + 
                    '</b> for <b>' + jobTitle + '</b> job ' +
                    'at the <b>' + interviewStatus + '</b> stage.'+
                    '<p>-</p>' +
                    ' <p><b>Feedback:</b> ' + feedbackText + '</p>';
            }
            
            chatterPosts.add(post);
        }
        
        if (!chatterPosts.isEmpty()) {
            insertrecord(chatterPosts, false);
        }    
    }
    
    /*
* ==================================================================================
* Method  : createWorkOrder
* Created By (Date) : Kshitiz (02 Sep, 2025)
* Purpose : If Interview__c status is changed to Hired, it creates a Work_Order__c 
*           record automatically using details from related objects.
* Params  : newList - Trigger.new, oldMap - Trigger.oldMap
* Modifications Log :
* Ver   Date         Author     Modification
* 1.0   02 Sep, 2025 Kshitiz    Initial Version
* 1.1   06 Oct, 2025 Kshitiz 	Added mail to Workorder record owner and task creation
* ==================================================================================== 
*/        
    public static void createWorkOrder(List<Interview__c> newList, Map<Id, Interview__c> oldMap) {
        Set<Id> interviewsToQuery = new Set<Id>();
        
        for (Interview__c newRec : newList) { 
            Interview__c oldRec = oldMap.get(newRec.Id);             
            
            if ( String.isNotBlank(newRec.Interview_Status__c) &&
                (newRec.Interview_Status__c == RecruitmentApp_Constants.INTERVIEW_STATUS_HIRED) &&
                (oldRec.Interview_Status__c != newRec.Interview_Status__c)) {
                    
                    interviewsToQuery.add(newRec.Id);
                }
        }
        
        if (interviewsToQuery.isEmpty()) {
            return;
        }
        List<Interview__c> interviewList = [
            SELECT Id, Candidate__c, Job_Position__r.Project__c, OwnerId,
            Job_Position__r.Job_Title__c, Job_Position__r.Recruiter__c
            FROM Interview__c
            WHERE Id IN :interviewsToQuery
        ];
        
        Map<Integer, Id> indexToInterviewMap = new Map<Integer, Id>();
        List<Work_Order__c> workorderList = new List<Work_Order__c>();
        
        Integer index = 0;
        for (Interview__c rec : interviewList) {
            if (rec.Candidate__c != null) {
                Work_Order__c wo = new Work_Order__c();
                wo.Candidate__c       = rec.Candidate__c;
                wo.Project__c         = rec.Job_Position__r.Project__c;
                wo.Start_Date__c      = Date.today();
                wo.Status__c          = RecruitmentApp_Constants.WORKORDER_STATUS_NEW;
                wo.Role_on_Project__c = rec.Job_Position__r.Job_Title__c;
                workorderList.add(wo);
                indexToInterviewMap.put(index, rec.Id);
                index++;
            }
        }
        
        if (!workorderList.isEmpty()) {
            Database.SaveResult[] srList = insertrecord(workorderList, true);
            Map<Id, Id> finalRecordMap = new Map<Id, Id>();
            
            for (Integer i = 0; i < srList.size(); i++) {
                if (srList[i].isSuccess()) {
                    Id interviewId = indexToInterviewMap.get(i);
                    finalRecordMap.put(interviewId, srList[i].getId());
                }
            }
            
            List<Id> workOrderIds = new List<Id>();
            List<Id> interviewIds = new List<Id>();
            
            for (Id interId : finalRecordMap.keySet()) {
                workOrderIds.add(finalRecordMap.get(interId));
                interviewIds.add(interId);
            }
            
            if (!workOrderIds.isEmpty() && !interviewIds.isEmpty()) {
                emailToOwner(workOrderIds, interviewIds);
            }
        }
    }
    
    /*
* Description: This method is used for record insertion 
*/
    public static Database.SaveResult[] insertrecord(List<SObject> recordsForInsert, Boolean boolval) {
        Database.SaveResult[] srList = Database.insert(recordsForInsert, boolval);
        
        for (Database.SaveResult sr : srList) {
            if (sr.isSuccess()) {
                System.debug('Inserted record Id: ' + sr.getId());
            } else {
                System.debug('Failed to insert record: ' + sr.getErrors()[0].getMessage());
            }
        }
        return srList;
    }
    
    /*
* ==================================================================================
* Method  : emailToOwner
* Purpose : This method will send email to newly created workorder record owner's
* Params  : workOrderIds - List<Id> , interviewIds - List<Id> 
* ================================================================================== 
*/
    public static void emailToOwner(List<Id> workOrderIds, List<Id> interviewIds) {
        Map<Id, Work_Order__c> woMap = new Map<Id, Work_Order__c>(
            [SELECT Id, Name, Status__c, Owner.Email, Owner.Name, OwnerId, Candidate__c
             FROM Work_Order__c 
             WHERE Id IN :workOrderIds]
        );
        
        Map<Id, Interview__c> intMap = new Map<Id, Interview__c>(
            [SELECT Id, Candidate__c, Candidate__r.Name,
             Job_Position__r.Project__c, Job_Position__r.Job_Title__c,
             Job_Position__r.Client__r.Name
             FROM Interview__c
             WHERE Id IN :interviewIds]
        );
        
        Organization orgInfo = [
            SELECT Name 
            FROM Organization 
            LIMIT 1
        ];
        String orgName = orgInfo.Name;
        String baseUrl = String.valueOf(URL.getOrgDomainUrl());
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Task> tasks = new List<Task>();
        
        for (Id woId : workOrderIds) {
            Work_Order__c wo = woMap.get(woId);
            Interview__c interview = intMap.get(interviewIds[workOrderIds.indexOf(woId)]);            
            String clientName = interview.Job_Position__r.Client__r.Name;
            String candidateName = interview.Candidate__r.Name;
            String jobPosition = interview.Job_Position__r.Job_Title__c;
            String woName = wo.Name;
            String ownerName = wo.Owner.Name;
            String ownerEmail = wo.Owner.Email;
            String workOrderLink = baseUrl + '/' + wo.Id;
            
            String emailBody = WorkOrderEmailBody(
                ownerName, candidateName, clientName, jobPosition, woName, workOrderLink, orgName
            );
            String emailSubject = 'Collect signed agreement from candidate: ' + candidateName;
            
            if (String.isNotBlank(ownerEmail)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { ownerEmail });
                mail.setSubject(emailSubject);
                mail.setHtmlBody(emailBody);
                emails.add(mail);
            }
            
            Task newTask = new Task();
            newTask.Subject = emailSubject;
            newTask.Description = 'Collect signed agreement from the candidate and upload it to the system.';
            newTask.ActivityDate = Date.today().addDays(2);
            newTask.OwnerId = wo.OwnerId;
            newTask.WhatId = wo.Id;
            newTask.Candidate__c = wo.Candidate__c;
            tasks.add(newTask);
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
        if (!tasks.isEmpty()) {
            Database.insert(tasks, true);
        }
    }
    
    public static String WorkOrderEmailBody ( String recipientName, String candidateName, String clientName, String jobPosition, String workOrderName,
                                             String workOrderLink, String orgName) {
                                                 String emailBody = ''
                                                     + '<p>Hello ' + recipientName + ',</p>'
                                                     + '<p>A new work order has been successfully created and requires your prompt action to proceed. '
                                                     + 'Please review the details below:</p>'
                                                     + '<p>'
                                                     + '<b>Candidate Name:</b> ' + candidateName + '<br/>'
                                                     + '<b>Client Name:</b> ' + clientName + '<br/>'
                                                     + '<b>Job Position:</b> ' + jobPosition + '<br/>'
                                                     + '<b>Work Order:</b> <a href="' + workOrderLink + '" target="_blank">' + workOrderName + '</a>'
                                                     + '</p>'
                                                     + '<p><b>Next Action Required:</p></b>'
                                                     + '<p>Please obtain the signed agreement from the candidate to move forward with this work order.</p>'
                                                     + '<p><b>Important Instructions:</b></p>'
                                                     + '<ul>'
                                                     + '<li>Ensure the signed agreement is collected and uploaded to the candidate’s record in the system.</li>'
                                                     + '<li>Once the agreement is uploaded, you may manually update the Work Order status from <b>New → Working</b> to initiate further processing.</li>'
                                                     + '<li>Timely action will help us maintain seamless workflow and client satisfaction. '
                                                     + 'If you encounter any issues during this process, please reach out to the operations team for assistance.</li>'
                                                     + '</ul>'
                                                     + '<p>Thank you for your prompt attention to this matter.</p>'
                                                     + '<p>Best regards,<br/>' + orgName + '</p>';
                                                 
                                                 return emailBody;
                                             }
    
    /**
* @author (date): Dixit (09 Sep, 2025)
* @description  : Handles insert/update of Interview__c records by creating corresponding Event records.  
*                 Ensures no duplicate events exist for the same Candidate__c.  
*                 Event details are derived from Interview, Candidate, Job Position, and Client data.  
* @param newList - List of newly inserted Interview__c records.  
* @return void - Inserts Event records into the system if required.  
*/

    
    public static void handleInterviewEvents(List<Interview__c> newList, Map<Id, Interview__c> oldMap) {
        List<Event> eventsToInsert = new List<Event>();
        List<Event> eventsToUpdate = new List<Event>();
        Set<Id> interviewIds = new Set<Id>();
        
        
        Boolean isInsert = (oldMap == null);
        
        
        for (Interview__c i : newList) {
            if (isInsert) {
                interviewIds.add(i.Id);
            } else {
                Interview__c oldRec = oldMap.get(i.Id);
                if (i.Interview_Date__c != oldRec.Interview_Date__c ||
                    i.Interview_Mode__c != oldRec.Interview_Mode__c) {
                        interviewIds.add(i.Id);
                    }
            }
        }
        
        if (interviewIds.isEmpty()) return;
        
        
        Map<Id, Interview__c> interviewMap = new Map<Id, Interview__c>([
            SELECT Id,
            Interview_Date__c,
            Interview_Mode__c,
            Candidate__c,
            Candidate__r.Name,
            Job_Position__c,
            Job_Position__r.Job_Title__c,
            Job_Position__r.Client__r.Name
            FROM Interview__c
            WHERE Id IN :interviewIds
        ]);
        
        // Candidate Ids
        Set<Id> candidateIds = new Set<Id>();
        for (Interview__c i : interviewMap.values()) {
            if (i.Candidate__c != null) candidateIds.add(i.Candidate__c);
        }
        
        // Existing Events for candidates
        Map<Id, List<Event>> candidateToEvents = new Map<Id, List<Event>>();
        if (!candidateIds.isEmpty()) {
            for (Event ev : [
                SELECT Id, Candidate__c, StartDateTime, EndDateTime, Location, Subject, WhatId
                FROM Event
                WHERE Candidate__c IN :candidateIds
            ]) {
                if (!candidateToEvents.containsKey(ev.Candidate__c)) {
                    candidateToEvents.put(ev.Candidate__c, new List<Event>());
                }
                candidateToEvents.get(ev.Candidate__c).add(ev);
            }
        }
        
        // Loop through interviews
        for (Interview__c interview : newList) {
            if (!interviewIds.contains(interview.Id)) continue;
            if (interview.Candidate__c == null) continue;
            
            Interview__c fullInterview = interviewMap.get(interview.Id);
            if (fullInterview == null || fullInterview.Interview_Date__c == null) continue;
            
            DateTime startDT = fullInterview.Interview_Date__c;
            DateTime endDT   = startDT.addHours(1);
            
            // Conflict check
            Boolean hasConflict = false;
            List<Event> evsForCandidate = candidateToEvents.get(interview.Candidate__c);
            Event associatedEvent;
            if (evsForCandidate != null) {
                for (Event ev : evsForCandidate) {
                    
                    system.debug('isInsert@@@@'+isInsert);
                    system.debug('ev.WhatId@@@@'+ev.WhatId);
                    system.debug('fullInterview.Job_Position__c@@@@'+fullInterview.Job_Position__c);
                    if (!isInsert && ev.WhatId == fullInterview.Job_Position__c) {
                        associatedEvent = ev;
                        continue;                    
                        
                    }
                    
                    system.debug('ev@@@@'+ev);
                    system.debug('ev.StartDateTime@@@@'+ev.StartDateTime);
                    system.debug('ev.EndDateTime@@@@'+ev.EndDateTime);
                    if (ev.StartDateTime != null && ev.EndDateTime != null) {
                        if ((startDT < ev.EndDateTime) && (endDT > ev.StartDateTime)) {
                            hasConflict = true;
                            break;
                        }
                    }
                }
            }
            
            if (hasConflict) {
                interview.addError('This candidate already has another interview scheduled in this time slot.');
                continue;
            }
            
            String candidateName = (fullInterview.Candidate__r != null) ? fullInterview.Candidate__r.Name : 'Unknown Candidate';
            String clientName = (fullInterview.Job_Position__r != null && fullInterview.Job_Position__r.Client__r != null) 
                ? fullInterview.Job_Position__r.Client__r.Name : 'Unknown Client';
            String jobTitle   = (fullInterview.Job_Position__r != null) ? fullInterview.Job_Position__r.Job_Title__c : 'Unknown Job';
            
            
            if (isInsert) {
                System.debug('interview.Interview_Mode__c'+interview.Interview_Mode__c);
                 System.debug('fullInterview.Interview_Mode__c'+fullInterview.Interview_Mode__c);
                
               
                Event ev = new Event(
                    WhatId = fullInterview.Job_Position__c,
                    StartDateTime = startDT,
                    EndDateTime = endDT,
                    Subject = 'Interview: ' + candidateName,
                    Description = candidateName + ' (' + jobTitle + ') for ' + clientName,
                    Location = fullInterview.Interview_Mode__c,
                    Candidate__c = fullInterview.Candidate__c,
                    DurationInMinutes = Integer.valueOf((endDT.getTime() - startDT.getTime()) / (1000 * 60)),
                    ActivityDate = startDT.date()
                );
                eventsToInsert.add(ev);
            } else if (associatedEvent != null) {
               
                associatedEvent.StartDateTime = startDT;
                associatedEvent.EndDateTime   = endDT;
                associatedEvent.Location      = fullInterview.Interview_Mode__c;
                associatedEvent.Subject       = 'Interview: ' + candidateName;
                eventsToUpdate.add(associatedEvent);
            }
        }
        
        if (!eventsToInsert.isEmpty()) {
            try {
                insert eventsToInsert;
            } catch (Exception e) {
                System.debug('Error inserting events: ' + e.getMessage());
            }
        }
        if (!eventsToUpdate.isEmpty()) {
            try {
                update eventsToUpdate;
            } catch (Exception e) {
                System.debug('Error updating events: ' + e.getMessage());
            }
        }
        
        
        
        
        
    }
}