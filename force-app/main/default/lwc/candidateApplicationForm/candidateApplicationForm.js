import { LightningElement, track } from 'lwc';
import submitCandidateForm from '@salesforce/apex/CandidatePublicController.submitCandidateForm';

export default class CandidateApplicationForm extends LightningElement {
    @track formData = {
        
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        experienceYears: null,
        skills: '',
        currentCompany: '',
        jobTitle: '',
        expectedSalary: null,
        noticePeriod: ''
    };

    @track resume = {
        fileName: '',
        contentType: '',
        base64Body: ''
    };

    @track isSubmitting = false;
    @track errorMessage = '';
    @track showSuccess = false;

    noticeOptions = [
        { label: 'Immediate Joiner', value: 'Immediate Joiner' },
        { label: '7 Days', value: '7 Days' },
        { label: '15 days or less', value: '15 days or less' },
        { label: '45 Days', value: '45 Days' },
        { label: '1 month', value: '1 month' },
        { label: '2 month', value: '2 month' },
        { label: '3 month', value: '3 month' }
    ];

    handleInputChange(event) {
        const field = event.target.name;
        let value = event.target.value;

        if (field === 'experienceYears' || field === 'expectedSalary') {
            value = value ? Number(value) : null;
        }

        this.formData = {
            ...this.formData,
            [field]: value
        };
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        this.resume.fileName = file.name;
        this.resume.contentType = file.type;

        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            this.resume.base64Body = base64
            console.log('RESUME LOADED, base64 length = ', this.resume.base64Body.length);
        };
        reader.readAsDataURL(file);
    }

    validateClientSide() {
        this.errorMessage = '';

        // simple required checks
        if (
            !this.formData.firstName ||
            !this.formData.lastName ||
            !this.formData.email ||
            !this.formData.phone) {
            this.errorMessage = 'Name, First Name, Last Name, Email, and Phone are required.';
            return false;
        }

        // email format
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(this.formData.email)) {
            this.errorMessage = 'Please enter a valid email address.';
            return false;
        }

        // phone basic check (you can adjust as needed)
        const phoneDigits = this.formData.phone.replace(/\D/g, '');
        if (phoneDigits.length < 10) {
            this.errorMessage = 'Please enter a valid phone number.';
            return false;
        }

        return true;
    }

    async handleSubmit(event) {
        event.preventDefault();

        if (!this.validateClientSide()) {
            return;
        }

        console.log('RESUME BEFORE SUBMIT: ', JSON.stringify(this.resume));

        this.isSubmitting = true;
        this.errorMessage = '';

        try {
            const res = await submitCandidateForm({
                firstName: this.formData.firstName,
                lastName: this.formData.lastName,
                email: this.formData.email,
                phone: this.formData.phone,
                experienceYears: this.formData.experienceYears,
                skills: this.formData.skills,
                currentCompany: this.formData.currentCompany,
                jobTitle: this.formData.jobTitle,
                expectedSalary: this.formData.expectedSalary,
                noticePeriod: this.formData.noticePeriod,
                recaptchaToken: null,    // or your real token
                // resume fields passed as separate params:
                resumeFileName: this.resume.fileName,
                resumeContentType: this.resume.contentType,
                resumeBase64Body: this.resume.base64Body
            });

            if (res && res.success) {
                this.showSuccess = true;
                // while testing on record page, you can comment this out:
                // window.location.href = '/thank-you';
            } else {
                this.errorMessage = (res && res.message)
                    ? res.message
                    : 'Something went wrong. Please try again.';
            }
        } catch (error) {
            this.errorMessage = 'We could not submit your application right now. Please try again later.';
            // console.error(JSON.stringify(error));
        } finally {
            this.isSubmitting = false;
        }
    }
}