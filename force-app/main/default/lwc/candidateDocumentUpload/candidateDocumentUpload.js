import { LightningElement, track, api } from 'lwc';
import uploadFileToDrive from '@salesforce/apex/CandidateDocumentService.uploadFileToDrive';
import getFiles from '@salesforce/apex/CandidateDocumentService.getFiles';
import deleteFileFromDrive from '@salesforce/apex/CandidateDocumentService.deleteFileFromDrive';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateResumeLink from '@salesforce/apex/CandidateDocumentService.updateResumeLink';

export default class CandidateDocumentUpload extends LightningElement {
    @track selectedDocType = '';
    @track otherDocName = '';
    @track fileList = [];
    @api recordId;

    @track isUploading = false;
    @track isDeleting = false;

    docTypeOptions = [
        { label: 'Candidate Photo', value: 'Candidate Photo' },
        { label: 'Resume', value: 'Resume' },
        { label: '10th Marksheet', value: '10th Marksheet' },
        { label: '12th Marksheet', value: '12th Marksheet' },
        { label: 'Degree', value: 'Degree' },
        { label: 'Aadhaar Card', value: 'Aadhaar Card' },
        { label: 'PAN Card', value: 'PAN Card' },
        { label: 'Educational Certificates', value: 'Educational Certificates' },
        { label: 'Others', value: 'Others' }
    ];

    columns = [
        { label: 'File Name', fieldName: 'name', type: 'text' },
        { label: 'Type', fieldName: 'type', type: 'text' },
        { label: 'Size', fieldName: 'size', type: 'text' },
        {
            label: 'Created Date',
            fieldName: 'createdTime',
            type: 'date',
            typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }
        },
        {
            label: 'View',
            type: 'button-icon',
            initialWidth: 60,
            typeAttributes: {
                iconName: 'utility:preview',
                name: 'view',
                title: 'View File',
                alternativeText: 'View File',
                variant: 'bare'
            }
        },
        {
            label: 'Delete',
            type: 'button-icon',
            initialWidth: 60,
            typeAttributes: {
                iconName: 'utility:delete',
                name: 'delete',
                title: 'Delete File',
                alternativeText: 'Delete File',
                variant: 'bare'
            }
        }
    ];

    connectedCallback() {
        this.loadUploadedFiles();
    }

    async loadUploadedFiles() {
        if (!this.recordId) return;
        try {
            const files = await getFiles({ recordId: this.recordId });
            const mappedFiles = files.map(file => {
                let sizeInKB = (file.size / 1024).toFixed(2) + " KB";
                let extension = file.name && file.name.includes('.')
                    ? file.name.split('.').pop()
                    : (file.mimeType ? file.mimeType.split('/').pop() : '');
                return { ...file, size: sizeInKB, type: extension };
            });
            // Sort by createdTime descending
            mappedFiles.sort((a, b) => new Date(b.createdTime) - new Date(a.createdTime));
             // update local list (single source of truth)
            this.fileList = [...mappedFiles];
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message || 'Failed to fetch candidate files.', 'error');
        }
    }

    get hasFiles() {
        return this.fileList && this.fileList.length > 0;
    }

    get isOtherSelected() {
        return this.selectedDocType === 'Others';
    }

    get uploadDocLabel() {
        return this.isOtherSelected ? this.otherDocName : this.selectedDocType;
    }

    get shouldShowUpload() {
        return this.selectedDocType && (!this.isOtherSelected || (this.isOtherSelected && this.otherDocName.trim() !== ''));
    }

    get isUploadDisabled() {
        return !this.shouldShowUpload;
    }

    get uploadDisabledClass() {
        return this.isUploadDisabled ? 'disabled' : '';
    }

    get uploadBoxClass() {
        return 'upload-box ' + (this.isUploadDisabled ? 'disabled' : '');
    }

    get trackedDocs() {
        return this.docTypeOptions
            .filter(doc => doc.value !== 'Others')
            .map(doc => {
                const uploaded = this.fileList?.some(file => file.name.startsWith(doc.value));
                return { label: doc.label, value: doc.value, uploaded: uploaded, cssClass: uploaded ? 'doc-box uploaded' : 'doc-box pending' };
            });
    }


    handleDocTypeChange(event) {
        this.selectedDocType = event.detail.value;
    }

    handleOtherDocNameChange(event) {
        this.otherDocName = event.detail.value;
    }

    openFilePicker() {
        if (this.isUploadDisabled) return;
        this.template.querySelector(".hidden-file-input").click();
    }

    handleDragOver(event) {
        if (this.isUploadDisabled) return;
        event.preventDefault();
        event.currentTarget.classList.add('drag-over');
    }

    handleDragLeave(event) {
        event.currentTarget.classList.remove('drag-over');
    }

    handleDrop(event) {
        if (this.isUploadDisabled) return;
        event.preventDefault();
        event.currentTarget.classList.remove('drag-over');
        const file = event.dataTransfer.files[0];
        if (file) this.uploadFile(file);
    }

    handleFileUpload(event) {
        const file = event.target.files[0];
        if (file) this.uploadFile(file);
    }

    async uploadFile(file) {
        const maxSize = 1048576;
        if (file.size > maxSize) {
            this.showToast('Error', 'File size cannot exceed 1 MB.', 'error');
            return;
        }
        this.isUploading = true;
        const reader = new FileReader();
        reader.onload = async () => {
            const base64 = reader.result.split(',')[1];
            try {
                await uploadFileToDrive({
                    fileName: this.uploadDocLabel,
                    base64Data: base64,
                    mimeType: file.type,
                    recordId: this.recordId

                });

                this.showToast('Success', 'File uploaded successfully!', 'success');
                await this.loadUploadedFiles();
                // update resume link using the freshly-loaded local fileList
                if (this.selectedDocType === 'Resume') {
                    await this.updateLatestResumeLink();
                }
                this.selectedDocType = '';
                this.otherDocName = '';
                this.template.querySelector(".hidden-file-input").value = '';

            } catch (error) {
                this.showToast('Error', error.body?.message || error.message || 'File upload failed.', 'error');
            }
            this.isUploading = false;
        };
        reader.readAsDataURL(file);
    }

    async deleteFile(fileId,fileName) {
        this.isDeleting = true;
        try {
            await deleteFileFromDrive({ fileId });
            this.showToast('Success', 'File deleted successfully!', 'success');
            await this.loadUploadedFiles();
            // if deleted file was a Resume, update candidate's resume link using local fileList
            if (fileName && fileName.startsWith('Resume')) {
                await this.updateLatestResumeLink();
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message || 'File deletion failed.', 'error');
        }
        this.isDeleting = false;
    }
    // ----------------------------
    // Update latest resume link USING LOCAL fileList (no extra server call)
    // ----------------------------
    async updateLatestResumeLink() {
        try {
            // Use local this.fileList (already sorted by createdTime desc in loadUploadedFiles)
            const resumes = (this.fileList || []).filter(f => f.name && f.name.startsWith('Resume'));

            // fileList already sorted; but ensure latest-by-date just in case:
            resumes.sort((a, b) => new Date(b.createdTime) - new Date(a.createdTime));

            const latest = resumes.length > 0 ? resumes[0] : null;
            await updateResumeLink({ candidateId: this.recordId, driveFileId: latest ? latest.id : null });
        } catch (error) {
             this.showToast(
            'Error',
            error.body?.message || error.message || 'Failed to update resume link.',
            'error'
            );
            //console.error('Failed to update latest resume link:', error);
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view') {
            const url = `https://drive.google.com/file/d/${row.id}/view`;
            window.open(url, '_blank');
        } else if (actionName === 'delete') {
            this.deleteFile(row.id,row.name);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}