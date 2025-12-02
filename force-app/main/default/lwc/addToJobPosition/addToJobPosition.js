import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJobPositions from '@salesforce/apex/AddToJobPositionController.getJobPositions';
import addCandidateToJobs from '@salesforce/apex/AddToJobPositionController.addCandidateToJobs';

export default class AddToJobPosition extends LightningElement {
    @api recordId;
    @track jobPositions = [];
    @track filteredJobPositions = [];
    @track selectedRows = [];
    searchTimeout;

    columns = [
        { label: 'Job Name', fieldName: 'Name', type: 'text' },
        { label: 'Job Title', fieldName: 'Job_Title__c', type: 'text' },
        {
            label: 'Created Date',
            fieldName: 'CreatedDate',
            type: 'date',
            typeAttributes: { day: '2-digit', month: 'short', year: 'numeric' }
        }
    ];

    connectedCallback() {
        console.log('Connected callback → candidateId:', this.recordId);
        this.loadJobPositions();
    }

    loadJobPositions(searchKey = '') {
        getJobPositions({ candidateId: this.recordId, searchKey })
            .then(result => {
                console.log('Job positions fetched from Apex:', result);
                this.jobPositions = result;
                this.filteredJobPositions = result;
            })
            .catch(error => {
                console.error('Error fetching job positions:', error);
            });
    }

    handleSearch(event) {
        const searchKey = event.target.value.trim();
        clearTimeout(this.searchTimeout);

     
        this.searchTimeout = setTimeout(() => {
            console.log('Searching jobs with key:', searchKey);
            this.loadJobPositions(searchKey);
        }, 400);
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows.map(row => row.Id);
    }

    get isButtonDisabled() {
        return this.selectedRows.length === 0;
    }

    handleAddCandidate() {
        if (this.selectedRows.length === 0) return;

        addCandidateToJobs({ candidateId: this.recordId, jobIds: this.selectedRows })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Candidate added to selected jobs successfully!',
                        variant: 'success'
                    })
                );
                this.selectedRows = [];
            })
           .catch(error => {
    let message = 'Error adding candidate to jobs';
    
    if (error && error.body && error.body.message) {
        message = error.body.message;
    }

    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'Error'
        })
    );
});
    }
}