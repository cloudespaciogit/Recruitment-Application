import { LightningElement, api, track, wire } from 'lwc';
import fetchSkills from '@salesforce/apex/LightcastSkillService.fetchSkills';
import { CurrentPageReference } from 'lightning/navigation';
import getCandidateSkills from '@salesforce/apex/SkillQuickActionController.getCandidateSkills';
import updateCandidateSkills from '@salesforce/apex/SkillQuickActionController.updateCandidateSkills';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class SkillQuickActionComponent extends LightningElement {

    debounceTimeout;
    @api recordId;
    @track currentObject;
    @track currentId;

    @track skillInput = '';
    @track softSkillInput = '';
    @track skillSuggestions = [];
    @track softSkillSuggestions = [];
    @track skills = [];
    @track softSkills = [];

    // ------------------------------------------------------------
    // UNIVERSAL RECORD + OBJECT DETECTION
    // ------------------------------------------------------------
    @wire(CurrentPageReference)
    getPageRef(pageRef) {
        console.log("=== getPageRef triggered ===");
        console.log("PageRef full object:", JSON.stringify(pageRef));

        if (!pageRef) return;

        // Extract recordId from all possible locations  
        const rec1 = pageRef?.state?.recordId;
        const rec2 = pageRef?.attributes?.recordId;
        const rec3 = this.recordId; // Quick Action auto

        this.currentId = rec1 || rec2 || rec3;
        console.log("Extracted recordId =", this.currentId);

        // Detect object if Quick Action used
        const apiName = pageRef.attributes?.apiName;
        console.log("Detected apiName =", apiName);

        if (apiName === "Candidate__c.Add_Skills") {
            this.currentObject = "Candidate";
            console.log("🎯 Detected Quick Action → Candidate");
        }
        else if (apiName === "Job_Position__c.Add_Skills") {
            this.currentObject = "Job Position";
            console.log("🎯 Detected Quick Action → Job Position");
        }

        // Fallback: Detect object by recordId prefix (Community case)
        if (!this.currentObject && this.currentId) {
            console.log("⚠️ apiName unavailable → using recordId prefix fallback");

            if (this.currentId.startsWith("a03")) {
                this.currentObject = "Candidate";
            } 
            else if (this.currentId.startsWith("a01")) {
                this.currentObject = "Job Position";
            }
        }

        console.log("Final currentObject =", this.currentObject);

        if (this.currentId && this.currentObject) {
            console.log("🔁 Calling loadCandidateSkills() for:", this.currentId);
            this.loadCandidateSkills();
        } else {
            console.warn("⚠️ No currentId or currentObject found. Skipping load.");
        }
    }

    // ------------------------------------------------------------
    // LOAD SKILLS
    // ------------------------------------------------------------
    loadCandidateSkills() {
        console.log("--- loadCandidateSkills() called ---");
        console.log("currentId =", this.currentId);
        console.log("currentObject =", this.currentObject);

        getCandidateSkills({
            candidateId: this.currentId,
            objName: this.currentObject
        })
        .then(result => {
            console.log("✅ getCandidateSkills result =", JSON.stringify(result));
            this.skills = result.skills || [];
            this.softSkills = result.softSkills || [];
            console.log("skills set =", this.skills);
            console.log("softSkills set =", this.softSkills);
        })
        .catch(error => {
            console.error("❌ Error loading candidate skills:", error);
        });
    }

    // ------------------------------------------------------------
    // AUTOCOMPLETE
    // ------------------------------------------------------------
    handleSkillTyping(event) {
        this.skillInput = event.target.value;
        console.log("🧠 handleSkillTyping =", this.skillInput);
        this.getSuggestions(this.skillInput, "skill");
    }

    handleSoftSkillTyping(event) {
        this.softSkillInput = event.target.value;
        console.log("🧠 handleSoftSkillTyping =", this.softSkillInput);
        this.getSuggestions(this.softSkillInput, "soft");
    }

    getSuggestions(query, type) {
        console.log(`🔍 getSuggestions(${query}, ${type})`);

        if (!query || query.length < 2) {
            console.log("⛔ Query too short → Clearing suggestions");
            if (type === "skill") this.skillSuggestions = [];
            if (type === "soft") this.softSkillSuggestions = [];
            return;
        }

        fetchSkills({ query })
        .then(result => {
            console.log("fetchSkills result =", JSON.stringify(result));
            if (type === "skill") this.skillSuggestions = result;
            if (type === "soft") this.softSkillSuggestions = result;
        })
        .catch(err => console.error("Error in fetchSkills:", err));
    }

    // ------------------------------------------------------------
    // SELECT SUGGESTION
    // ------------------------------------------------------------
    handleSkillSelect(event) {
        const selected = event.target.dataset.value;
        console.log("Selected skill =", selected);
        if (selected && !this.skills.includes(selected)) {
            this.skills = [...this.skills, selected];
        }
        this.skillInput = '';
        this.skillSuggestions = [];
    }

    handleSoftSkillSelect(event) {
        const selected = event.target.dataset.value;
        console.log("Selected soft skill =", selected);
        if (selected && !this.softSkills.includes(selected)) {
            this.softSkills = [...this.softSkills, selected];
        }
        this.softSkillInput = '';
        this.softSkillSuggestions = [];
    }

    // ------------------------------------------------------------
    // ENTER KEY
    // ------------------------------------------------------------
    handleSkillKeyPress(event) {
        if (event.key === "Enter") {
            const val = event.target.value.trim();
            console.log("Enter Skill =", val);
            if (val && !this.skills.includes(val)) this.skills = [...this.skills, val];
            this.skillInput = '';
            this.skillSuggestions = [];
        }
    }

    handleSoftSkillKeyPress(event) {
        if (event.key === "Enter") {
            const val = event.target.value.trim();
            console.log("Enter Soft Skill =", val);
            if (val && !this.softSkills.includes(val)) this.softSkills = [...this.softSkills, val];
            this.softSkillInput = '';
            this.softSkillSuggestions = [];
        }
    }

    // ------------------------------------------------------------
    // REMOVE TAG
    // ------------------------------------------------------------
    removeSkill(event) {
        const val = event.target.dataset.value;
        console.log("Removing skill =", val);
        this.skills = this.skills.filter(s => s !== val);
    }

    removeSoftSkill(event) {
        const val = event.target.dataset.value;
        console.log("Removing soft skill =", val);
        this.softSkills = this.softSkills.filter(s => s !== val);
    }

    // ------------------------------------------------------------
    // SAVE
    // ------------------------------------------------------------
    handleSave() {
        console.log("💾 handleSave()");
        console.log("currentId =", this.currentId);
        console.log("currentObject =", this.currentObject);

        const req = {
            recordId: this.currentId,
            objName: this.currentObject,
            skills: this.skills,
            softSkills: this.softSkills
        };

        console.log("Sending wrapper:", JSON.stringify(req));

        updateCandidateSkills({ req: req })   
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Success",
                        message: "Skills updated successfully",
                        variant: "success"
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                console.error("❌ Error updating skills:", error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Error",
                        message: error?.body?.message || "Failed to update skills",
                        variant: "error"
                    })
                );
            });
    }


    handleCancel() {
        console.log("🚪 handleCancel()");
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}