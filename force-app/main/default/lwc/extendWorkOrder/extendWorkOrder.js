import { api, LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllFieldsValue from '@salesforce/apex/ExtendWorkOrderController.getAllFieldsValue';
import markWorkOrderAsExtended from '@salesforce/apex/ExtendWorkOrderController.markWorkOrderAsExtended';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';

export default class ExtendWorkOrder extends NavigationMixin(LightningElement) {
    @api recordId;  // The Id of the current Work Order record from where this action is triggered

    /*
     * This method is called when the Quick Action (or invoked action) is executed.
     * It fetches required field values from the existing Work Order,
     * marks it as "Extended", and navigates to a new Work Order creation page
     * with default field values prefilled.
     */

    @api
    invoke() {
        // Step 1: Fetch existing Work Order details from Apex
        getAllFieldsValue({ recordId: this.recordId })
            .then(result => {
                // Step 2: Prepare the default field values for the new Work Order

                const defaultValues = encodeDefaultFieldValues({
                    Candidate__c: result.Candidate__c,
                    Project__c: result.Project__c,
                    Role_on_Project__c: result.Role_on_Project__c,
                    Recruiter__c: result.Recruiter__c,
                    Renewed__c: true,
                    Parent_Work_OrderId__c: this.recordId
                });

                // Step 3: Mark the current Work Order as Extended via Apex

                return markWorkOrderAsExtended({ recordId: this.recordId })
                    .then(() => {
                        // Step 4: Navigate to the "New Work Order" page
                        this[NavigationMixin.Navigate]({
                            type: 'standard__objectPage',
                            attributes: {
                                objectApiName: 'Work_Order__c',
                                actionName: 'new'
                            },
                            state: {
                                defaultFieldValues: defaultValues
                            }
                        });
                    });
            })
            .catch(error => {
                let message = 'Unexpected error occurred while extending Work Order.';

                if (error.body) {
                    if (error.body.message) {
                        message = error.body.message;
                    } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                        message = error.body.pageErrors[0].message;
                    } else if (error.body.fieldErrors) {
                        const fieldErrorKeys = Object.keys(error.body.fieldErrors);
                        if (fieldErrorKeys.length > 0) {
                            message = error.body.fieldErrors[fieldErrorKeys[0]][0].message;
                        }
                    }
                } else if (error.message) {
                    message = error.message;
                }

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: message,
                        variant: 'error'
                    })
                );
            });

    }
}