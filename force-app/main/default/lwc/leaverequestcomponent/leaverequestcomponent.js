import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createTimesheets from '@salesforce/apex/LeaveRequestController.createTimesheets';
import getNotifyConfigs from '@salesforce/apex/LeaveRequestController.getNotifyConfigs';
import getLoggedInCandidateId from '@salesforce/apex/LeaveRequestController.getLoggedInCandidateId';

export default class RequestLeave extends LightningElement {

    /* =======================
       BASIC PROPERTIES
       ======================= */
    @api recordId;

    @track showPanel = false;

    @track fromDate = '';
    @track toDate = '';
    @track totalDays = 0;
    @track leaveType = '';
    @track leaveDuration = 'Full Day Leave';
    @track reason = '';
    @track reasonError = false;
    @track durationType = 'Full Day'; // Full Day | Half Day
    @track halfDayType = ''; // FH | SH


    /* =======================
       NOTIFY SECTION STATE
       ======================= */
    @track notifyList = [];
    @track filteredNotifyList = [];
    @track selectedNotifyChips = [];   // [{ name, email }]
    @track selectedNotifyEmails = [];  // [email1, email2]
    @track showNotifyResults = false;

    /* =======================
       INIT
       ======================= */
    connectedCallback() {
        getNotifyConfigs()
            .then(data => {
                this.notifyList = data;
                this.filteredNotifyList = []; // nothing shown initially
            })
            .catch(error => {
                console.error('Notify fetch error', error);
            });
    }

    /* =======================
       GETTERS
       ======================= */
    get hasSelectedNotify() {
        return this.selectedNotifyChips.length > 0;
    }

    get leaveOptions() {
        return [
            { label: 'Sick Leave', value: 'Sick' },
            { label: 'Casual Leave', value: 'Casual' },
            { label: 'Earned Leave', value: 'Earned' }
        ];
    }
    get halfDayOptions() {
        return [
            { label: 'First Half', value: 'FH' },
            { label: 'Second Half', value: 'SH' }
        ];
    }


    get durationOptions() {

        if (!this.fromDate || !this.toDate) {
            return [];
        }

        // SINGLE DAY → Full + Half
        if (this.fromDate === this.toDate) {
            return [
                { label: 'Full Day', value: 'Full Day' },
                { label: 'Half Day', value: 'Half Day' }
            ];
        }

        // MULTI DAY → ONLY Full
        return [
            { label: 'Full Day', value: 'Full Day' }
        ];
    }
    get isHalfDaySelected() {
        return this.durationType === 'Half Day';
    }

    /* =======================
       PANEL OPEN / CLOSE
       ======================= */
    openPanel() {
        this.showPanel = true;
    }

    closePanel() {
        this.showPanel = false;
    }

    /* =======================
       DATE & LEAVE HANDLERS
       ======================= */
    handleFromChange(event) {
        this.fromDate = event.target.value;
        this.calculateDays();
    }

    handleToChange(event) {
        this.toDate = event.target.value;
        this.calculateDays();
    }

    handleLeaveType(event) {
        this.leaveType = event.target.value;
        this.calculateDays();
    }

    handleDurationChange(event) {
        this.durationType = event.target.value;

        // reset half selection if not Half Day
        if (this.durationType !== 'Half Day') {
            this.halfDayType = '';
        }

        this.calculateDays();
    }


    handleReason(event) {
        this.reason = event.target.value;
        this.reasonError = false;
    }

    calculateDays() {

        if (!this.fromDate || !this.toDate) {
            this.totalDays = 0;
            return;
        }

        const start = new Date(this.fromDate);
        const end = new Date(this.toDate);

        if (end < start) {
            this.totalDays = 0;
            return;
        }

        const diff =
            (end - start) / (1000 * 60 * 60 * 24) + 1;

        // MULTI DAY → force Full Day
        if (diff > 1) {
            this.durationType = 'Full Day';
            this.halfDayType = '';
            this.totalDays = diff;
            return;
        }

        // SINGLE DAY
        if (this.durationType === 'Half Day') {
            this.totalDays = 0.5;
        } else {
            this.totalDays = 1;
        }
    }

    handleHalfDayChange(event) {
        this.halfDayType = event.target.value;
        this.calculateDays();
    }


    /* =======================
       NOTIFY SEARCH
       ======================= */
    handleNotifySearch(event) {
        const key = event.target.value.toLowerCase();

        if (!key) {
            this.filteredNotifyList = [];
            this.showNotifyResults = false;
            return;
        }

        this.filteredNotifyList = this.notifyList.filter(
            item =>
                item.Name__c.toLowerCase().includes(key) ||
                item.Email__c.toLowerCase().includes(key)
        );

        this.showNotifyResults = this.filteredNotifyList.length > 0;
    }

    /* =======================
       SELECT NOTIFY USER
       ======================= */
    selectNotifyUser(event) {
        const email = event.currentTarget.dataset.email;
        const name = event.currentTarget.dataset.name;

        // prevent duplicates
        if (this.selectedNotifyEmails.includes(email)) {
            return;
        }

        this.selectedNotifyChips = [
            ...this.selectedNotifyChips,
            { name, email }
        ];

        this.selectedNotifyEmails = [
            ...this.selectedNotifyEmails,
            email
        ];

        // remove from results
        this.filteredNotifyList =
            this.filteredNotifyList.filter(
                item => item.Email__c !== email
            );

        this.showNotifyResults = false;

        // clear search input
        const input = this.template.querySelector(
            'lightning-input[type="search"]'
        );
        if (input) {
            input.value = '';
        }
    }

    /* =======================
       REMOVE CHIP
       ======================= */
    removeNotifyChip(event) {
        const email = event.currentTarget.dataset.email;

        this.selectedNotifyChips =
            this.selectedNotifyChips.filter(
                chip => chip.email !== email
            );

        this.selectedNotifyEmails =
            this.selectedNotifyEmails.filter(
                e => e !== email
            );
    }


    resetForm() {
        this.fromDate = '';
        this.toDate = '';
        this.totalDays = 0;
        this.leaveType = '';
        this.leaveDuration = 'Full Day Leave';
        this.reason = '';
        this.reasonError = false;

        // Notify reset
        this.filteredNotifyList = [];
        this.selectedNotifyChips = [];
        this.selectedNotifyEmails = [];
        this.showNotifyResults = false;
        this.durationType = 'Full Day';
        this.halfDayType = '';
        // Clear search input if present
        const searchInput = this.template.querySelector(
            'lightning-input[type="search"]'
        );
        if (searchInput) {
            searchInput.value = '';
        }
    }


    /* =======================
       SUBMIT
       ======================= */
    async handleSubmit() {
        if (this.durationType === 'Half Day' && !this.halfDayType) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please select First Half or Second Half.',
                    variant: 'error'
                })
            );
            return;
        }

        if (!this.reason || !this.reason.trim()) {
            this.reasonError = true;
            return;
        }

        try {

            let candidateId = this.recordId;

            if (!candidateId) {
                candidateId = await getLoggedInCandidateId();
            }

            if (!candidateId) {
                throw new Error('Candidate not found');
            }
            let finalLeaveDuration = 'Full Day Leave';

            if (this.durationType === 'Half Day') {
                finalLeaveDuration =
                    this.halfDayType === 'FH'
                        ? 'Half Day - FH'
                        : 'Half Day - SH';
            }
            const payload = {
                candidateId: candidateId,
                fromDate: this.fromDate,
                toDate: this.toDate,
                leaveType: this.leaveType,
                leaveDuration: finalLeaveDuration,
                reason: this.reason,
                notifyEmails: this.selectedNotifyEmails
            };

            console.log('Payload JSON =>', JSON.stringify(payload));

            await createTimesheets({
                payloadJson: JSON.stringify(payload)
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Leave request submitted successfully.',
                    variant: 'success'
                })
            );

            this.resetForm();
            this.closePanel();

        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || error.message,
                    variant: 'error'
                })
            );
        }
    }

}