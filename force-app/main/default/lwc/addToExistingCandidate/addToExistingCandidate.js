import { LightningElement, api, track } from 'lwc';
import getMyCandidatesBySearch from '@salesforce/apex/SupplierCandidateController.getMyCandidatesBySearch';
import createInterviews from '@salesforce/apex/SupplierCandidateController.createInterviews';
import getNoticePeriodPicklistValues from '@salesforce/apex/SupplierCandidateController.getNoticePeriodPicklistValues';
import updateCandidateFields from '@salesforce/apex/SupplierCandidateController.updateCandidateFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AddToExistingCandidate extends LightningElement {
    @api recordId;

    @track candidates = [];
    @track selectedRowIds = [];

    @track showEditModal = false;

    editingCandidateId;
    editingCandidateName;
    editingNoticeValue;
    editingExpectedRate;

    noticePeriodOptions = [];

    searchKey = '';
    searchDebounce;
    error;

    columns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Email', fieldName: 'Email__c' },
        { label: 'Phone', fieldName: 'Phone__c' },
        { label: 'Skills', fieldName: 'Skills__c' },
        { label: 'Experience', fieldName: 'Experience_Year__c' },
        { label: 'Designation', fieldName: 'Designation__c' },
        { label: 'Notice Period', fieldName: 'Notice_Period__c' },
        {
            label: 'Supplier Expected Rate',
            fieldName: 'Supplier_Expected_Rate__c',
            type: 'currency',
            typeAttributes: { currencyCode: 'INR', minimumFractionDigits: 2 }
        },
        {
            type: 'button-icon',
            initialWidth: 60,
            typeAttributes: {
                iconName: 'utility:edit',
                name: 'edit_candidate',
                alternativeText: 'Edit'
            }
        }
    ];

    connectedCallback() {
        this.doSearch();
        this.loadPicklist();
    }

    /* ----------- PICKLIST ----------- */
    loadPicklist() {
        getNoticePeriodPicklistValues()
            .then(res => this.noticePeriodOptions = res)
            .catch(err => console.error(err));
    }

    /* ----------- SEARCH ----------- */
    handleSearchInput(event) {
        this.searchKey = event.target.value;
    }

    handleSearchKeyUp() {
        clearTimeout(this.searchDebounce);
        this.searchDebounce = setTimeout(() => {
            this.doSearch();
        }, 500);
    }

    doSearch() {
        getMyCandidatesBySearch({ searchKey: this.searchKey })
            .then(res => {
                this.candidates = res;
                this.error = undefined;
            })
            .catch(err => {
                this.candidates = [];
                this.error = err.body?.message || JSON.stringify(err);
            });
    }

    /* ----------- EDIT ROW ----------- */
    handleRowAction(event) {
        if (event.detail.action.name === 'edit_candidate') {
            const row = event.detail.row;
            this.editingCandidateId = row.Id;
            this.editingCandidateName = row.Name;
            this.editingNoticeValue = row.Notice_Period__c || '';
            this.editingExpectedRate = row.Supplier_Expected_Rate__c || null;
            this.showEditModal = true;
        }
    }

    handleNoticeChange(event) {
        this.editingNoticeValue = event.target.value;
    }

    handleExpectedRateChange(event) {
        this.editingExpectedRate = event.target.value ? Number(event.target.value) : null;
    }

    closeEditModal() {
        this.showEditModal = false;
    }

    saveEditChanges() {
        updateCandidateFields({
            candidateId: this.editingCandidateId,
            newNoticeValue: this.editingNoticeValue,
            newExpectedRate: this.editingExpectedRate
        })
            .then(updatedRow => {
                this.candidates = this.candidates.map(c =>
                    c.Id === updatedRow.Id ? updatedRow : c
                );

                this.showToast('Success', 'Candidate updated', 'success');
                this.closeEditModal();
            })
            .catch(err => {
                this.showToast('Error', err.body?.message || JSON.stringify(err), 'error');
            });
    }

    /* ----------- CREATE INTERVIEWS ----------- */
    handleRowSelection(event) {
        this.selectedRowIds = event.detail.selectedRows.map(r => r.Id);
    }

    get isCreateDisabled() {
        return this.selectedRowIds.length === 0;
    }

    handleCreateInterviews() {
        createInterviews({
            candidateIds: this.selectedRowIds,
            jobPositionId: this.recordId
        })
            .then(result => {
                this.showToast('Success', `${result.length} interviews created`, 'success');
                this.selectedRowIds = [];
            })
            .catch(err => {
                this.showToast('Error', err.body?.message || JSON.stringify(err), 'error');
            });
    }

    /* ----------- TOAST ----------- */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}