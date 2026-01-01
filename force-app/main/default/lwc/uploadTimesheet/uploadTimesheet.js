import { LightningElement, api, track } from 'lwc';
import getProjects from '@salesforce/apex/UploadTimesheetController.getProjects';
import uploadTimesheet from '@salesforce/apex/UploadTimesheetController.uploadTimesheet';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class UploadTimesheet extends LightningElement {

    @api recordId;

    @track isModalOpen = false;
    @track currentStep = 1;
    @track projectOptions = [];
    @track selectedFileName;

    selectedProject; // Work_Order__c Id
    fileName;
    base64Data;

    get isStepOne() {
        return this.currentStep === 1;
    }

    get isStepTwo() {
        return this.currentStep === 2;
    }

    /* ================= MODAL ================= */

    openModal() {
        this.isModalOpen = true;
        this.currentStep = 1;

        getProjects({ recordId: this.recordId })
            .then(result => {
                this.projectOptions = result.map(wo => ({
                    label: wo.Project__r.Project_Name__c,
                    value: wo.Id
                }));
            })
            .catch(error => {
                console.error(error);
                this.showToast('Error', 'Failed to load projects', 'error');
            });
    }

    closeModal() {
        this.isModalOpen = false;
        this.currentStep = 1;
        this.selectedProject = null;
        this.fileName = null;
        this.base64Data = null;
        this.selectedFileName = null;
    }

    /* ================= STEP 1 ================= */

    handleProjectChange(event) {
        this.selectedProject = event.detail.value;
    }

    handleNext() {
        if (!this.selectedProject) {
            this.showToast('Error', 'Please select a project', 'error');
            return;
        }
        this.currentStep = 2;
    }

    /* ================= STEP 2 ================= */

    handleFilesChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        const ext = file.name.split('.').pop().toLowerCase();
        if (ext !== 'csv') {
            this.showToast('Invalid File', 'Only CSV files are allowed', 'error');
            event.target.value = null;
            return;
        }

        this.fileName = file.name;
        this.selectedFileName = file.name;

        const reader = new FileReader();
        reader.onload = () => {
            this.base64Data = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    handleUpload() {
        if (!this.base64Data) {
            this.showToast('Error', 'Please upload a CSV file', 'error');
            return;
        }

        uploadTimesheet({
            recordId: this.recordId,
            workOrderId: this.selectedProject,
            fileName: this.fileName,
            base64Data: this.base64Data
        })
        .then(() => {
            this.showToast('Success', 'Timesheet uploaded successfully', 'success');
            this.closeModal();
        })
        .catch(error => {
            const msg = error?.body?.message || 'Upload failed';
            this.showToast('Error', msg, 'error');
            console.error(error);
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}