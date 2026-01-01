import { LightningElement, api, track } from 'lwc';
import getTimesheetsByDateRange from '@salesforce/apex/CandidateTimesheetController.getTimesheetsByDateRange';
import getHolidays from '@salesforce/apex/CandidateTimesheetController.getHolidays';
import getLoggedInCandidateId from '@salesforce/apex/CandidateTimesheetController.getLoggedInCandidateId';

export default class timesheetListView extends LightningElement {

    @api recordId; // Candidate__c recordId
    // Resolved Candidate Id (record page OR portal)
    @track candidateId;
    @track timesheets = [];
    @track filters = [];

    selectedFilter;

    connectedCallback() {
        console.log('record id can : ' , this.recordId);

        this.buildFilters();
        if (this.recordId) {
            // Candidate record page
            this.candidateId = this.recordId;
            this.loadTimesheets();
        } else {
            // Experience Cloud / Portal
            this.fetchLoggedInCandidate();
        }     
    }

    /* =========================================================
       FETCH LOGGED-IN CANDIDATE (PORTAL FALLBACK)
       ========================================================= */

    fetchLoggedInCandidate() {
        getLoggedInCandidateId()
            .then(result => {
                console.log('CandidateId from logged-in user:', result);

                if (result) {
                    this.candidateId = result;
                    this.loadTimesheets();
                } else {
                    console.warn('No Candidate mapped to logged-in user');
                    this.timesheets = [];
                }
            })
            .catch(error => {
                console.error('Error fetching logged-in candidate:', error);
                this.timesheets = [];
            });
    }

    /* ---------------- FILTER BUTTONS ---------------- */

    buildFilters() {
        const today = new Date();
        const filters = [];

        filters.push({
            label: '30 DAYS',
            type: 'ROLLING',
            isActive: true,
            className: 'filter-btn active'
        });

        for (let i = 1; i <= 6; i++) {
            const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
            filters.push({
                label: d.toLocaleString('default', { month: 'short' }).toUpperCase(),
                type: 'MONTH',
                month: d.getMonth() + 1,
                year: d.getFullYear(),
                isActive: false,
                className: 'filter-btn'
            });
        }

        this.filters = filters;
        this.selectedFilter = filters[0];
    }

    handleFilterClick(event) {
        const index = event.currentTarget.dataset.index;

        this.filters = this.filters.map((f, i) => ({
            ...f,
            isActive: i == index,
            className: i == index ? 'filter-btn active' : 'filter-btn'
        }));

        this.selectedFilter = this.filters[index];
        this.loadTimesheets();
    }

    /* ---------------- TITLE LABEL(MONTH/YEAR) ---------------- */

    get selectedRangeLabel() {
        if (this.selectedFilter.type === 'ROLLING') {
            return 'Last 30 Days';
        }

        const d = new Date(
            this.selectedFilter.year,
            this.selectedFilter.month - 1,
            1
        );

        return d.toLocaleString('default', {
            month: 'long',
            year: 'numeric'
        });
    }

    /* ---------------- DATE RANGE ---------------- */

    getDateRange() {
        const today = new Date();
        let startDate, endDate;

        if (this.selectedFilter.type === 'ROLLING') {
            startDate = new Date();
            startDate.setDate(today.getDate() - 30);
            endDate = today;
        } else {
            startDate = new Date(
                this.selectedFilter.year,
                this.selectedFilter.month - 1,
                1
            );
            endDate = new Date(
                this.selectedFilter.year,
                this.selectedFilter.month,
                0
            );
        }

        return { startDate, endDate };
    }

    /* ---------------- DATA LOAD ---------------- */

    loadTimesheets() {
        if (!this.candidateId) {
            console.warn('CandidateId not available yet');
            return;
        }

        const { startDate, endDate } = this.getDateRange();

        Promise.all([
            getTimesheetsByDateRange({
                candidateId: this.candidateId,
                startDate: startDate.toISOString().split('T')[0],
                endDate: endDate.toISOString().split('T')[0]
            }),
            getHolidays({
                startDate: startDate.toISOString().split('T')[0],
                endDate: endDate.toISOString().split('T')[0]
            })
        ])
        .then(([timesheetData, holidayMap]) => {
            this.processTimesheets(timesheetData, holidayMap, startDate, endDate);
        })
        .catch(error => {
            console.error('Error loading timesheets:', error);
            this.timesheets = [];
        });
    }

    /* ---------------- PROCESS & FILL MISSING DAYS ---------------- */

    processTimesheets(data, holidayMap, startDate, endDate) {
        const map = {};
        data.forEach(r => map[r.Date__c] = r);

        const rows = [];

        for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
            const dateKey = d.toISOString().split('T')[0];
            const record = map[dateKey];

            const isWeekend = [0, 6].includes(d.getDay());
            const holidayName = holidayMap[dateKey];

            const dateLabel = d
                .toLocaleDateString('en-GB', { weekday: 'short', day: '2-digit', month: 'short' })
                .replace(/^(\w+)/, '$1,');

            /* HOLIDAY */
            if (holidayName) {
                rows.push({
                    id: dateKey,
                    dateLabel,
                    badgeText: holidayName,
                    badgeClass: 'holiday-badge',
                    displayText: 'Holiday',
                    rowClass: 'row holiday'
                });
                continue;
            }

            /* FULL DAY LEAVE */
            if (record?.Status__c === 'Full Day Leave') {
                rows.push({
                    id: dateKey,
                    dateLabel,
                    badgeText: 'LEAVE',
                    badgeClass: 'leave-badge',
                    displayText: 'Full Day Leave',
                    rowClass: 'row leave'
                });
                continue;
            }

            /* HALF DAY (FH / SH) */
            const isHalfDay =
                record?.Status__c === 'Half Day - FH' ||
                record?.Status__c === 'Half Day - SH';

            if (isHalfDay) {
                rows.push({
                    id: dateKey,
                    dateLabel,
                    badgeText: 'H-DAY',
                    badgeClass: 'leave-badge',
                    login: this.getLogin(record),
                    logout: this.getLogout(record),
                    total: this.getTotal(record),
                    showPenalty: record?.Penalty__c === true,
                    rowClass: 'row'
                });
                continue;
            }

            /* WEEKLY OFF */
            if (isWeekend) {
                rows.push({
                    id: dateKey,
                    dateLabel,
                    badgeText: 'W-OFF',
                    badgeClass: 'woof-badge',
                    displayText: 'Full day Weekly-off',
                    rowClass: 'row weekend'
                });
                continue;
            }

            /* WORKING */
            rows.push({
                id: dateKey,
                dateLabel,
                login: this.getLogin(record),
                logout: this.getLogout(record),
                total: this.getTotal(record),
                showPenalty: record?.Penalty__c === true,
                rowClass: 'row'
            });
        }

        this.timesheets = rows.reverse();
    }

    /* ================= HELPERS ================= */

    getLogin(record) {
        if (!record) {
            return 'No entries logged in';
        }

        if (record.Login_Time__c == null) {
            return '—';
        }

        return this.formatTime(record.Login_Time__c);
    }

    getLogout(record) {
        if (!record) {
            return 'No entries logged out';
        }

        if (record.Logout_Time__c == null) {
            return '—';
        }

        return this.formatTime(record.Logout_Time__c);
    }

    getTotal(record) {
        if (!record || record.Total_Working_Hours__c == null) {
            return '—';
        }

        return record.Total_Working_Hours__c;
    }


    /* ---------------- TIME FORMAT ---------------- */

    formatTime(ms) {
        if (ms === null || ms === undefined) {
            return 'No entries logged in';
        }
        const mins = Math.floor(ms / 60000);
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        return `${h.toString().padStart(2, '0')}:${m
            .toString()
            .padStart(2, '0')}`;
    }
}