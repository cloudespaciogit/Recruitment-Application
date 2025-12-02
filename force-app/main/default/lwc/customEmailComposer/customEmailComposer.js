import { LightningElement, api, track } from 'lwc';
import getFromAddresses from '@salesforce/apex/CustomEmailComposerController.getFromAddresses';
import sendEmailNow from '@salesforce/apex/CustomEmailComposerController.sendEmailNow';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CustomEmailComposer extends LightningElement {
    @api recordId;
    @track showModal = false;

    // FROM
    @track fromOptions = [];
    @track selectedFrom = null;
    @track showFromPopup = false;

    // RECIPIENTS
    @track toInput = '';
    @track ccInput = '';
    @track bccInput = '';
    @track toChips = [];
    @track ccChips = [];
    @track bccChips = [];
    showCc = false;
    showBcc = false;

    // SUBJECT & BODY
    @track subject = '';
    @track htmlBody = '';
    @track sendLabel = 'Send';

    // ATTACHMENTS
    //@track fileList = [];
    //@track selectedFiles = [];
    selectedFileIds = new Set();

    // RELATED TO & JOB
    @track relatedToId = null;
    @track relatedToName = '';
    @track jobId = null;
    @track jobTitle = '';
    @track jobLocation = '';
    @track jobType = '';
    @track jobDescription = '';

    connectedCallback() {
        this.loadFromAddresses();
    }

    /* ---------------------------
       FROM ADDRESS LOGIC
    ---------------------------- */
    get selectedFromDisplay() {
        return this.selectedFrom
            ? `${this.selectedFrom.displayName} <${this.selectedFrom.address}>`
            : 'Select From Address';
    }

    loadFromAddresses() {
        getFromAddresses()
            .then(res => {
                this.fromOptions = res || [];
                const org = this.fromOptions.find(f => f.type === 'OrgWide');
                this.selectedFrom = org || this.fromOptions[0] || null;
            })
            .catch(err => {
                // eslint-disable-next-line no-console
                console.error(err);
            });
    }

    toggleFromPopup() {
        this.showFromPopup = !this.showFromPopup;
    }

    handleFromSelect(e) {
        const id = e.currentTarget.dataset.id;
        this.selectedFrom = this.fromOptions.find(x => x.id === id);
        this.showFromPopup = false;
    }

    /* ---------------------------
       INPUT HANDLERS
    ---------------------------- */
    focusToInput() {
        const input = this.template.querySelector('.pill-input');
        if (input) {
            input.focus();
        }
    }

    handleToInputChange(e) {
        this.toInput = e.target.value;
    }
    handleCcInputChange(e) {
        this.ccInput = e.target.value;
    }
    handleBccInputChange(e) {
        this.bccInput = e.target.value;
    }

    handleToInputKeyUp(e) {
        if (e.key === 'Enter' || e.key === ',') {
            this.addChips('to');
        }
    }
    handleCcInputKeyUp(e) {
        if (e.key === 'Enter' || e.key === ',') {
            this.addChips('cc');
        }
    }
    handleBccInputKeyUp(e) {
        if (e.key === 'Enter' || e.key === ',') {
            this.addChips('bcc');
        }
    }

    addChips(type) {
        let raw =
            type === 'to' ? this.toInput :
            type === 'cc' ? this.ccInput :
            this.bccInput;

        if (!raw || !raw.trim()) return;

        const emails = raw
            .split(/[,;]+/)
            .map(e => e.trim())
            .filter(e => e);

        if (type === 'to') {
            this.toChips = [
                ...this.toChips,
                ...emails.filter(e => !this.toChips.includes(e))
            ];
            this.toInput = '';
        } else if (type === 'cc') {
            this.ccChips = [
                ...this.ccChips,
                ...emails.filter(e => !this.ccChips.includes(e))
            ];
            this.ccInput = '';
        } else if (type === 'bcc') {
            this.bccChips = [
                ...this.bccChips,
                ...emails.filter(e => !this.bccChips.includes(e))
            ];
            this.bccInput = '';
        }
    }

    removeChip(e) {
        const type = e.currentTarget.dataset.type;
        const value = e.currentTarget.dataset.value;

        if (type === 'to') {
            this.toChips = this.toChips.filter(c => c !== value);
        } else if (type === 'cc') {
            this.ccChips = this.ccChips.filter(c => c !== value);
        } else if (type === 'bcc') {
            this.bccChips = this.bccChips.filter(c => c !== value);
        }
    }

    toggleCc() {
        this.showCc = !this.showCc;
    }
    toggleBcc() {
        this.showBcc = !this.showBcc;
    }

    handleSubjectChange(e) {
        this.subject = e.target.value;
    }

    handleBodyChange(e) {
        this.htmlBody = e.detail?.value || e.target.value;
    }

    /* ---------------------------
       FILE ATTACHMENTS
    ---------------------------- */
    /*toggleFileSelect(e) {
        const id = e.target.value;
        if (e.target.checked) {
            this.selectedFileIds.add(id);
        } else {
            this.selectedFileIds.delete(id);
        }
    }*/

    /*addSelectedFiles() {
        this.selectedFileIds.forEach(id => {
            const file = this.fileList.find(x => x.Id === id);
            if (file && !this.selectedFiles.some(f => f.Id === id)) {
                this.selectedFiles = [...this.selectedFiles, file];
            }
        });
    }*/

    /*removeAttachment(e) {
        const id = e.currentTarget.dataset.id;
        this.selectedFiles = this.selectedFiles.filter(f => f.Id !== id);
    }*/

    /* ---------------------------
       PREFILL FROM PARENT
    ---------------------------- */
    @api
    openWithPrefill(prefill = {}) {
        this.resetForm(false);

        if (prefill.toAddresses) {
            const arr =
                typeof prefill.toAddresses === 'string'
                    ? prefill.toAddresses.split(/[,;]+/).map(e => e.trim())
                    : prefill.toAddresses;
            this.toChips = arr;
        }

        if (prefill.subject) this.subject = prefill.subject;
        if (prefill.htmlBody) this.htmlBody = prefill.htmlBody;

        if (prefill.relatedToId) this.relatedToId = prefill.relatedToId;
        if (prefill.relatedToName) this.relatedToName = prefill.relatedToName;

        this.jobId = prefill.jobId || null;
        this.jobTitle = prefill.jobTitle || '';
        this.jobLocation = prefill.jobLocation || '';
        this.jobType = prefill.jobType || '';
        this.jobDescription = prefill.jobDescription || '';

        this.showModal = true;
    }

    /* ---------------------------
       RESET & CLOSE
    ---------------------------- */
    closeModal() {
        this.showModal = false;
        this.resetForm();
    }

    resetForm(resetFrom = true) {
        this.toInput = '';
        this.ccInput = '';
        this.bccInput = '';
        this.toChips = [];
        this.ccChips = [];
        this.bccChips = [];

        this.subject = '';
        this.htmlBody = '';

        //this.selectedFiles = [];
        //this.selectedFileIds = new Set();

        if (resetFrom) {
            this.selectedFrom =
                this.fromOptions.find(f => f.type === 'OrgWide') ||
                this.fromOptions[0] ||
                null;
        }

        this.showFromPopup = false;
        this.showCc = false;
        this.showBcc = false;

        this.relatedToId = null;
        this.relatedToName = '';
    }

    /* ---------------------------
       SEND EMAIL
    ---------------------------- */
    handleSend() {
        this.addChips('to');
        this.addChips('cc');
        this.addChips('bcc');

        if (!this.toChips.length && !this.ccChips.length && !this.bccChips.length) {
            this.toast('Error', 'Please add at least one recipient', 'error');
            return;
        }

       // const docIds = this.selectedFiles.map(f => f.Id);

        sendEmailNow({
            toAddresses: this.toChips,
            ccAddresses: this.ccChips,
            bccAddresses: this.bccChips,
            subject: this.subject,
            htmlBody: this.htmlBody,
            relatedRecordId: this.relatedToId,
            fromType: this.selectedFrom?.type,
            fromId: this.selectedFrom?.id,
            fromAddress: this.selectedFrom?.address
        })
            .then(res => {
                this.toast('Success', res || 'Email sent', 'success');
                this.closeModal();
            })
            .catch(err => {
                this.toast('Error', err?.body?.message || err.message, 'error');
            });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}