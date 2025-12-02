import { LightningElement, track, api } from 'lwc';
import getcandidate from '@salesforce/apex/PdfSaveController.getcandidate';
import uploadPdfToWorkOrder from '@salesforce/apex/PdfSaveController.sendpdf';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import jsPDFResource from '@salesforce/resourceUrl/jsPDF';
//import SignaturePadResource from '@salesforce/resource_url/signature_pad';

export default class AgreementForm extends LightningElement {
    @api recordId;

    // UI flags
    @track viewMode = true;
    @track isEditMode = false;
    @track isPreviewMode = false;

    // editor content
    @track editableContent = '';

    // data placeholders
    @track candidateName = '';
    @track client = '';
    @track address = '';
    @track phone_Number = '';
    @track email_Address = '';
    @track website_URL = '';
    @track companyName = '';
    @track director_Name = '';
    @track role = '';
    @track wo_Number = '';
    @track manager_Name = '';
    @track location = '';
    @track registration_Number = '';
    @track todaydate = '';

    // logo (replace with your actual resource or URL)
    logo_URL = "https://cloudespaciosoftwareprivat5-dev-ed--c.develop.vf.force.com/resource/1762952017000/Cloudespacio_Logo?";

    // libs & signature
    signaturePad;
    jsLoaded = false;

    // -----------------------------
    // lifecycle: load libs & initialize
    // -----------------------------
    renderedCallback() {
        if (this.jsLoaded) return;

        // try common file paths for jsPDF and signature_pad inside static resource
        const tryLoad = async () => {
            try {
                // try UMD path first (common)
                await loadScript(this, jsPDFResource + '/jspdf.umd.min.js');
            } catch (e1) {
                try {
                    // fallback to root resource (maybe you uploaded single file)
                    await loadScript(this, jsPDFResource);
                } catch (e2) {
                    console.error('Failed to load jsPDF resource from both paths', e1, e2);
                    throw new Error('jsPDF load failed');
                }
            }

            /* SignaturePad - try typical filename inside static resource, else try root
            try {
                await loadScript(this, SignaturePadResource + '/signature_pad.js');
            } catch (s1) {
                try {
                    await loadScript(this, SignaturePadResource);
                } catch (s2) {
                    // don't throw here — signature pad optional but we'll warn
                    console.warn('SignaturePad failed to load from common paths', s1, s2);
                }
            }*/
        };

        tryLoad()
            .then(() => {
                this.jsLoaded = true;
                // init signature pad if canvas present and lib loaded
                const canvas = this.template.querySelector('canvas.signature-pad');
                if (canvas && window.SignaturePad) {
                    // set pixel size for crispness
                    canvas.width = 520;
                    canvas.height = 180;
                    this.signaturePad = new window.SignaturePad(canvas);
                } else if (canvas && !window.SignaturePad) {
                    console.warn('SignaturePad library not found on window');
                }
            })
            .catch(err => {
                console.error('❌ jsPDF/SignaturePad load error:', err);
                this.showToast('Error', 'Failed to load PDF libraries', 'error');
            });
    }

    // -----------------------------
    // fetch data
    // -----------------------------
    connectedCallback() {
        if (this.recordId) {
            this.fetchCandidateData();
        } else {
            // wait for recordId if not present immediately
            const check = setInterval(() => {
                if (this.recordId) {
                    clearInterval(check);
                    this.fetchCandidateData();
                }
            }, 200);
        }
    }

    async fetchCandidateData() {
        try {
            const result = await getcandidate({ woId: this.recordId });
            if (result) {
                this.candidateName = result?.Candidate__r?.Name || '';
                this.client = result?.Project__r?.Client__r?.Name || '';
                this.phone_Number = result?.Project__r?.Client__r?.Phone__c || '';
                this.email_Address = result?.Project__r?.Client__r?.Email__c || '';
                this.website_URL = result?.Project__r?.Client__r?.Website__c || '';

                const client = result?.Project__r?.Client__r;
                const addressParts = [
                    client?.Address__Street__s,
                    client?.Address__City__s,
                    client?.Address__StateCode__s,
                    client?.Address__PostalCode__s,
                    client?.Address__CountryCode__s
                ].filter(Boolean);
                this.address = addressParts.join(', ');
                // you can set other fields similarly if available
            } else {
                this.showToast('Info', 'No Work Order details found.', 'info');
            }
        } catch (err) {
            console.error('Apex error', err);
            this.showToast('Error', 'Failed to fetch Work Order details.', 'error');
        }
    }

    // -----------------------------
    // Edit flow (Step 1 -> Step 2)
    // -----------------------------
    openEditor() {
        // Get the rendered HTML (from view mode) and push into editor
        const htmlBlock = this.template.querySelector('.agreement-html');
        if (!htmlBlock) {
            this.showToast('Error', 'Agreement block not found', 'error');
            return;
        }

        // copy innerHTML into rich text field
        this.editableContent = htmlBlock.innerHTML || '';
        this.viewMode = false;
        this.isEditMode = true;
        this.isPreviewMode = false;
    }

    handleTextChange(event) {
        this.editableContent = event.target.value;
    }

    cancelEdit() {
        // cancel returns to view
        this.isEditMode = false;
        this.viewMode = true;
        this.isPreviewMode = false;
    }

    // Save from editor -> go to PREVIEW (Step 3)
    saveEditedText() {
        if (!this.editableContent || this.editableContent.trim() === '') {
            this.showToast('Error', 'Edited content cannot be empty', 'error');
            return;
        }

        // update the view-mode HTML so that the preview & view both reflect change
        const htmlBlock = this.template.querySelector('.agreement-html');
        if (htmlBlock) {
            htmlBlock.innerHTML = this.editableContent;
        }

        // show preview page
        this.isEditMode = false;
        this.isPreviewMode = true;
        this.viewMode = false;

        // render into preview container (lwc:dom="manual")
        // setTimeout ensures DOM is ready
        setTimeout(() => {
            const preview = this.template.querySelector('.preview-container');
            if (preview) {
                preview.innerHTML = this.editableContent;
            }
        }, 0);
    }

    // back to edit from preview
    backToEdit() {
        this.isPreviewMode = false;
        this.isEditMode = true;
        this.viewMode = false;
    }

    // -----------------------------
    // Final submit -> generate PDF & upload (from Preview)
    // -----------------------------
    async finalSavePDF() {
        try {
            if (!this.jsLoaded || !window.jspdf || !window.jspdf.jsPDF) {
                this.showToast('Error', 'PDF library not loaded', 'error');
                return;
            }

            // Use the preview container's innerText to preserve readable formatting
            // If you want more visual fidelity (fonts/styles) you'll need html2canvas → but that can introduce CORS issues
            const preview = this.template.querySelector('.preview-container');
            const textContent = preview ? preview.innerText : this.editableContent || '';

            if (!textContent || textContent.trim() === '') {
                this.showToast('Error', 'Agreement content is empty!', 'error');
                return;
            }

            // Create PDF using jsPDF UMD
            const jsPDFConstructor = window.jspdf && window.jspdf.jsPDF ? window.jspdf.jsPDF : (window.jsPDF || null);
            if (!jsPDFConstructor) {
                this.showToast('Error', 'jsPDF constructor not found', 'error');
                return;
            }

            const doc = new jsPDFConstructor('p', 'mm', 'a4');

            const marginLeft = 12;
            const marginTop = 12;
            const usableHeight = doc.internal.pageSize.getHeight() - 24;
            const lineHeight = 7;
            const pageWidthForText = doc.internal.pageSize.getWidth() - (marginLeft * 2);

            // split text into lines that fit width
            const lines = doc.splitTextToSize(textContent, pageWidthForText);

            let y = marginTop;
            let page = 1;
            doc.setFontSize(12);

            for (let i = 0; i < lines.length; i++) {
                if (y + lineHeight > usableHeight) {
                    // footer
                    doc.setFontSize(10);
                    doc.text(`Page ${page}`, doc.internal.pageSize.getWidth() - 20, usableHeight + 10);
                    // new page
                    doc.addPage();
                    page++;
                    y = marginTop;
                    doc.setFontSize(12);
                }
                doc.text(lines[i], marginLeft, y);
                y += lineHeight;
            }

            /* add signature image if present
            if (!this.signaturePad || this.signaturePad.isEmpty()) {
                this.showToast('Warning', 'Please sign before saving PDF', 'warning');
                return;
            }

            const sigData = this.signaturePad.toDataURL('image/png');*/

            if (y + 40 > usableHeight) {
                doc.addPage();
                y = marginTop;
                page++;
            }
            doc.setFontSize(12);
            doc.text('Signature:', marginLeft, y + 10);
            doc.addImage(sigData, 'PNG', marginLeft + 35, y, 60, 30);
            y += 45;

            // footer on last page
            doc.setFontSize(10);
            doc.text(`Page ${page}`, doc.internal.pageSize.getWidth() - 20, usableHeight + 10);

            // export base64
            const pdfBase64 = doc.output('datauristring').split(',')[1];

            // call Apex to upload - adjust param names as in your Apex
            await uploadPdfToWorkOrder({
                woId: this.recordId,
                pdfData: pdfBase64,
                fileName: 'AgreementForm.pdf'
            });

            this.showToast('Success', 'PDF generated and uploaded successfully', 'success');

            // return to view mode
            this.isPreviewMode = false;
            this.viewMode = true;

        } catch (err) {
            console.error('finalSavePDF error', err);
            this.showToast('Error', 'Failed to generate/upload PDF', 'error');
        }
    }

    // -----------------------------
    clearSignature() {
        if (this.signaturePad) this.signaturePad.clear();
    }

    showToast(title, message, variant = 'info') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}