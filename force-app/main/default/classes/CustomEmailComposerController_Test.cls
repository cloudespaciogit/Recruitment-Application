@isTest
public class CustomEmailComposerController_Test {

    // Utility: create a test user (your working code)
    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

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

        return u;
    }

    // ----------------------------
    // TEST getFromAddresses()
    // ----------------------------
    @isTest
    static void testGetFromAddresses() {

        User u = createTestUser();

        System.runAs(u) {
            List<Map<String, String>> result =
                CustomEmailComposerController.getFromAddresses();

            System.assertNotEquals(0, result.size(),
                'Must at least return logged-in user email');

            Boolean foundUser = false;

            for (Map<String, String> entry : result) {
                if (entry.get('type') == 'User') {
                    foundUser = true;
                }
            }

            System.assert(foundUser,
                'User email entry must be included in getFromAddresses()');
        }
    }


    // ----------------------------
    // TEST sendEmailNow() using User Reply-To
    // ----------------------------
    @isTest
    static void testSendEmailNow_UserReplyTo() {

        User u = createTestUser();

        System.runAs(u) {

            Test.startTest();

            String result = CustomEmailComposerController.sendEmailNow(
                new List<String>{ 'to@example.com' },     // To
                new List<String>{ 'cc@example.com' },     // CC
                new List<String>{ 'bcc@example.com' },    // BCC
                'Test Subject',                           // Subject
                '<p>Body</p>',                             // HTML body
                null,                                      // No related record
                'User',                                    // fromType
                null,                                      // fromId
                'replyto@example.com'                      // fromAddress
            );

            Test.stopTest();

            System.assertEquals('Email sent successfully', result);
        }
    }


    // ----------------------------
    // TEST: No Recipients → Exception
    // ----------------------------
    @isTest
    static void testSendEmailNow_NoRecipients_ShouldThrow() {
    
        User u = createTestUser();
    
        System.runAs(u) {
    
            try {
                Test.startTest();
    
                CustomEmailComposerController.sendEmailNow(
                    null, null, null,    // no recipients
                    'Test Subject',
                    '<p>Body</p>',
                    null,
                    'User',
                    null,
                    'reply@example.com'
                );
    
                Test.stopTest();
                System.assert(false, 'Expected an AuraHandledException but none thrown');
    
            } catch (AuraHandledException e) {
                // This is enough — message cannot be reliably tested
                System.assert(true);
            }
        }
    }

    
	@isTest
    static void testSendEmailNow_OrgWideBranch() {
    
        User u = createTestUser();
    	// Fetch actual Org-Wide Email configured in the org
        OrgWideEmailAddress owd = [
            SELECT Id, Address 
            FROM OrgWideEmailAddress 
            LIMIT 1
        ];
        System.runAs(u) {
    
            Test.startTest();
    
            // NOTE: fake OrgWideEmail Id — allowed because your controller suppresses errors in try-catch
            String result = CustomEmailComposerController.sendEmailNow(
                new List<String>{ 'valid@example.com' },
                null,
                null,
                'Test OrgWide',
                '<p>Body</p>',
                null,
                'OrgWide',     // go to OrgWide branch
                owd.Id,        // pass actual org-wide email id
                null
            );
    
            Test.stopTest();
    
            System.assertEquals('Email sent successfully', result);
        }
    } 

    @isTest
    static void testSendEmailNow_WithWhatId() {
    
        User u = createTestUser();
        System.runAs(u) {
    
            // Create a dummy related record
            Account acc = new Account(Name = 'Test Acc');
            insert acc;
    
            Test.startTest();
    
            String result = CustomEmailComposerController.sendEmailNow(
                new List<String>{ 'valid@example.com' },
                null,
                null,
                'With WhatId',
                '<p>Body</p>',
                acc.Id,                  // <-- forces WhatId branch
                'User',
                null,
                'reply@test.com'
            );
    
            Test.stopTest();
    
            System.assertEquals('Email sent successfully', result);
        }
    }
	
@isTest
static void testSendEmailNow_ErrorBranch() {

    User u = createTestUser();

    System.runAs(u) {

        try {
            Test.startTest();

            // Force sendEmail() failure using invalid email format
            CustomEmailComposerController.sendEmailNow(
                new List<String>{ 'invalid-email-format' },
                null,
                null,
                'Failure Test',
                '<p>Bad Email</p>',
                null,
                'User',
                null,
                null
            );

            Test.stopTest();
            System.assert(false, 'Expected failure but method returned success');

        } catch (AuraHandledException e) {

            // Salesforce swallows real message → "Script-thrown exception"
            System.assert(true, 'Exception thrown as expected');
        }
    }
}
}