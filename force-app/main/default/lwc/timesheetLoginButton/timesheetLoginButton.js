import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//import { FlowNavigationFinishEvent } from 'lightning/flowSupport';
import getLoggedInCandidateId from '@salesforce/apex/CandidateDocumentService.getLoggedInCandidateId';
import createTimesheet from '@salesforce/apex/TimesheetController.createTimesheet';
import signoutTimesheet from '@salesforce/apex/TimesheetController.signoutTimesheet';
import getTodayTimesheet from '@salesforce/apex/TimesheetController.getTodayTimesheet';

export default class TimesheetAutoLogin extends LightningElement {

    /* =========================
       API / Flow
       ========================= */
    _recordId;
    _initialized = false;
    @api availableActions = [];

    /* =========================
       UI State
       ========================= */
    @track isLoading = false;
    @track showClockIn = false;
    @track showClockOut = false;
    @track workingHours;
    @track loginTime;

    /* =========================
       Clock Data
       ========================= */
    @track currentTime;
    @track currentDate;

    timesheetId;
    timer;

    /* =========================
       Lifecycle
       ========================= */
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        if (this._recordId === value) {
            return; // prevent duplicate execution
        }

        this._recordId = value;

        if (value) {
            console.log('recordId setter fired =>', value);
            this.initializeComponent();
        }
    }

   connectedCallback() {

        this.startLiveClock();

        // Portal case (recordId not injected)
        if (!this.recordId) {
            console.log('Portal context detected');
            this.resolveCandidateFromPortal();
        }
    }

    disconnectedCallback() {
        clearInterval(this.timer);
    }

    /* =========================================================
       Initialization Logic (Single Entry Point)
       ========================================================= */
    initializeComponent() {
        if (this._initialized) {
            console.log('Already initialized, skipping');
            return;
        }

        this._initialized = true;

        console.log('Initializing component with recordId =>', this.recordId);
        this.fetchTimesheet();
    }

    /* =========================================================
       Portal Candidate Resolution
       ========================================================= */
        async resolveCandidateFromPortal() {
            console.log('================ RESOLVE CANDIDATE (PORTAL) ================');

            try {
                const candidateId = await getLoggedInCandidateId();
                console.log('Resolved candidateId =>', candidateId);

                if (!candidateId) {
                    this.showToast(
                        'Error',
                        'Candidate record not found for logged-in user.',
                        'error'
                    );
                    return;
                }

                // ✅ DO NOT assign to @api property
                this._recordId = candidateId;
                this.initializeComponent();

            } catch (error) {
                console.error('Error resolving candidate:', error);

                this.showToast(
                    'Error',
                    error?.body?.message || error?.message || 'Unable to load candidate data.',
                    'error'
                );
            }
        }

    /* =========================
       Live Clock
       ========================= */
    startLiveClock() {
        this.updateClock();
        this.timer = setInterval(() => this.updateClock(), 1000);
    }

    updateClock() {
        const now = new Date();

        this.currentTime = now.toLocaleTimeString('en-IN', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hour12: true
        });

        this.currentDate = now.toLocaleDateString('en-IN', {
            weekday: 'short',
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        });
    }

    /* =========================
       Button Actions (NO UI LOGIC)
       ========================= */

    handleClockIn() {
        this.isLoading = true;

        createTimesheet({ candidateId: this.recordId })
            .then(result => {
                if (result === 'SUCCESS') {
                    this.showToast('Success', 'Clock In successful.', 'success');
                } else if (result === 'ALREADY_EXISTS') {
                    this.showToast('Info', 'Login already recorded today.', 'warning');
                } else if (result === 'NO_ACTIVE_WORK_ORDER') {
                    this.showToast('Error', 'No active Work Order found.', 'error');
                }
                 else if (result === 'LOGOUT_DONE') {
                    this.showToast('Info', 'You have already logged out for today.', 'warning');
                }
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error?.body?.message || 'Unexpected error occurred.',
                    'error'
                );
            })
            .finally(() => {
                this.isLoading = false;
                this.fetchTimesheet();   // 🔑 always re-evaluate UI
            });
    }

    handleClockOut() {
        if (!this.timesheetId) {
            this.showToast('Error', 'No active timesheet found.', 'error');
            return;
        }

        this.isLoading = true;

        signoutTimesheet({ timesheetId: this.timesheetId })
            .then(() => {
                this.showToast('Success', 'Clock Out successful.', 'success');
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error?.body?.message || 'Clock Out failed.',
                    'error'
                );
            })
            .finally(() => {
                this.isLoading = false;
                this.fetchTimesheet();   // 🔑 backend decides UI
            });
    }

    /* =========================
       Fetch Timesheet (SINGLE SOURCE OF TRUTH)
       ========================= */
    fetchTimesheet() {
        this.resetUI();

        getTodayTimesheet({ candidateId: this.recordId })
            .then(record => {
                console.log('Value received : ', record);
                if (!record?.Id) {
                    // Case 1: No timesheet today
                    this.showClockIn = true;
                    this.showClockOut = false;
                    return;
                }

                this.timesheetId = record.Id;

                // Case 3: Login + Logout completed
                if (record.Login_Time__c && record.Logout_Time__c) {                    
                    this.workingHours = record.Total_Working_Hours__c;
                    this.showClockIn = true;     
                    this.showClockOut = false;
                    return;
                }

                // Case 2: Logged in but not logged out
                if (record.Login_Time__c && !record.Logout_Time__c ) {
                    this.calculateRunningWorkingTime(record.Login_Time__c);
                    this.showClockIn = false;
                    this.showClockOut = true;
                    return;
                }

                // Fallback
                this.showClockIn = true;
                this.showClockOut = false;
            })
            .catch(error => {
                console.error('fetchTimesheet error:', error);
                this.showClockIn = true;
                this.showClockOut = false;
            });
    }

    /* =========================
       Helpers
       ========================= */

    resetUI() {
        this.showClockIn = false;
        this.showClockOut = false;
        this.loginTime = null;
        this.workingHours = null;
        this.timesheetId = null;
    }

    calculateRunningWorkingTime(loginTimeStr) {
        const now = new Date();
        const loginDt = this.buildDateFromTime(loginTimeStr);

        const diffMs = now - loginDt;
        const totalMinutes = Math.floor(diffMs / 60000);

        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;

        this.workingHours = `${hours}h ${minutes}m`;

        this.loginTime = loginDt.toLocaleTimeString('en-IN', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });
    }

    buildDateFromTime(timeInMs) {
        const now = new Date();

        const hours = Math.floor(timeInMs / (1000 * 60 * 60));
        const minutes = Math.floor((timeInMs % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((timeInMs % (1000 * 60)) / 1000);

        return new Date(
            now.getFullYear(),
            now.getMonth(),
            now.getDate(),
            hours,
            minutes,
            seconds
        );
    }

    /* =========================
       Toast Helper
       ========================= */
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}