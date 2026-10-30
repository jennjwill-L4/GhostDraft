import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

const BASE_CATEGORIES = [
    { label: 'General Assistance', value: 'General Assistance' },
    { label: 'Production Emergency', value: 'Production Emergency' },
    { label: 'Other', value: 'Other' }
];

export default class Caseintakeform extends LightningElement {
    @api isAccessApprover = false;

    // Outputs back to the flow
    @api queryCategory;
    @api subject;
    @api description;

    // Only access approvers get the "User Access" category.
    get categoryOptions() {
        const opts = [...BASE_CATEGORIES];
        if (this.isAccessApprover) {
            opts.push({ label: 'User Access', value: 'User Access' });
        }
        return opts;
    }

    handleCategory(event) {
        this.queryCategory = event.detail.value;
        this.dispatchEvent(new FlowAttributeChangeEvent('queryCategory', this.queryCategory));
    }

    handleSubject(event) {
        this.subject = event.detail.value;
        this.dispatchEvent(new FlowAttributeChangeEvent('subject', this.subject));
    }

    handleDescription(event) {
        // lightning-input-rich-text exposes the value on the element
        this.description = event.target.value;
        this.dispatchEvent(new FlowAttributeChangeEvent('description', this.description));
    }

    // Flow calls this before advancing on Next.
    @api
    validate() {
        const missing = [];
        if (!this.queryCategory) missing.push('Query Category');
        if (!this.subject) missing.push('Subject');
        if (!this.description) missing.push('Description');
        if (missing.length) {
            return { isValid: false, errorMessage: `Please complete: ${missing.join(', ')}.` };
        }
        return { isValid: true };
    }
}