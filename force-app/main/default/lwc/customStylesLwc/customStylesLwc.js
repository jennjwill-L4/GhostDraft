import { LightningElement } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

export default class CustomStylesLwc extends LightningElement {
    basePath = window.location.origin;
    userId;

    connectedCallback() {
        // Salesforce provides an easy way to check for user session via CurrentPageReference
        this.checkUserSession();
    }

    checkUserSession() {
        // Salesforce's UserInfo object provides the current user's Id directly in LWC without Apex
        this.userId = this.getUserId();
    }

    getUserId() {
        // This method returns the current user's Id if available, else returns null
        return (document.cookie.includes('sid') && UserInfo.userId) ? UserInfo.userId : null;
    }

    get knowledgeCenterUrl() {
        return `${this.basePath}/s/knowledge-center`;
    }

    get downloadCenterUrl() {
        return `${this.basePath}/s/contentdocument/ContentDocument/All`;
    }

    get submitTicketUrl() {
        return `${this.basePath}/s/supportcenter`;
    }

    get myTicketsUrl() {
        return `${this.basePath}/s/case/Case/00Bj00000033qtYEAQ`;
    }

    navigateToPage(event) {
        event.preventDefault();
        const url = event.currentTarget.getAttribute('href');

        if (this.userId) {
            // User is logged in, navigate to the URL
            window.location.href = url;
        } else {
            // No session, redirect to login
            window.location.href = '/s/';
        }
    }
}