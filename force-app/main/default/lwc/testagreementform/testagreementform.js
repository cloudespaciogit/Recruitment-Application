import { LightningElement, api, track, wire } from 'lwc';
import getLetterData from '@salesforce/apex/LetterController.getLetterData';
import createPdfAndSendEmail from '@salesforce/apex/LetterController.createPdfAndSendEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LetterTemplate extends LightningElement {
    @api recordId;

    @track showView = true;
    @track showEdit = false;

    @track dynamicHtml = '';
    @track editedHtml = '';

    dataLoaded = false; // NEW FLAG

    // Load data from Apex
    @wire(getLetterData, { recordId: '$recordId' })
    wiredData({ data, error }) {
        if (data) {
            this.dynamicHtml = data.templateText;
            this.dataLoaded = true;

            // Render HTML after data arrives
            this.renderHtml();
        } else if (error) {
            console.error('Error:', error);
        }
    }

    renderedCallback() {
        // Prevent blank initial load — only render after data arrives
        if (this.dataLoaded) {
            this.renderHtml();
        }
    }

    renderHtml() {
        const container = this.template.querySelector('.letter-container');
        if (container) {
            container.innerHTML = this.dynamicHtml;
        }
    }

    // Switch to edit mode
    handleEdit() {
        this.editedHtml = this.dynamicHtml;
        this.showView = false;
        this.showEdit = true;
    }

    // Save updated text and show preview
    handleSaveUpdates() {
        this.dynamicHtml = this.editedHtml;
        this.showEdit = false;
        this.showView = true;

        // Re-render updated HTML
        this.renderHtml();
    }

    handleEditorChange(event) {
        this.editedHtml = event.target.value;
    }

    // Final Save -> generate PDF + email
    async handleFinalSave() {
        try {
            const response = await createPdfAndSendEmail({
                htmlContent: this.dynamicHtml,
                recordId: this.recordId
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'PDF generated and email sent successfully.',
                    variant: 'success'
                })
            );
        } catch (err) {
            console.error(err);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Something went wrong.',
                    variant: 'error'
                })
            );
        }
    }
}