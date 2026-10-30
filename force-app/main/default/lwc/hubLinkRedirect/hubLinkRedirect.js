import { LightningElement, api } from "lwc";
import getHubAccountId from "@salesforce/apex/HubLinkRedirectController.getHubAccountId";

// Hostname fragments used by Experience Builder and Preview.
// The live site runs on *.my.site.com, so none of these match there.
const EDITOR_HOST_MARKERS = [
    "builder.salesforce-experience.com",
    "live-preview.salesforce-experience.com",
    "sitepreview",
    "livepreview"
];

export default class HubLinkRedirect extends LightningElement {
    @api destinationUrl = "https://hub.ghostdraft.com/godocs";
    @api paramName = "org";
    @api disableRedirect = false;

    targetUrl;
    isLoading = true;
    isEditor = false;
    errorMessage;

    _started = false;

    connectedCallback() {
        if (this._started) {
            return;
        }
        this._started = true;
        this.isEditor = this.detectEditor();
        this.loadAndRedirect();
    }

    get showPreview() {
        return this.isEditor || this.disableRedirect;
    }

    get previewMessage() {
        return this.isEditor
            ? "The redirect is skipped in Experience Builder and Preview. On the live site, this page sends users to:"
            : "The redirect is paused. Turn off Pause Redirect to send users to:";
    }

    async loadAndRedirect() {
        let hubId = "";
        try {
            hubId = (await getHubAccountId()) || "";
        } catch (error) {
            // Most likely cause: the community profile lacks access to the Apex class.
            console.error("hubLinkRedirect: could not load the Hub Account ID", error);
            this.errorMessage = "Your account details couldn\u2019t be loaded. You can still continue to Knowledge Articles.";
        }

        const base = (this.destinationUrl || "").trim();
        if (!base) {
            this.errorMessage = "No destination URL is set for this page.";
            this.isLoading = false;
            return;
        }

        this.targetUrl = this.buildUrl(base, hubId);
        this.isLoading = false;

        if (!this.showPreview && !this.errorMessage) {
            // replace() keeps this page out of browser history, so Back does not loop.
            window.location.replace(this.targetUrl);
        }
    }

    buildUrl(base, hubId) {
        const param = (this.paramName || "org").trim();
        const separator = base.includes("?") ? "&" : "?";
        return `${base}${separator}${encodeURIComponent(param)}=${encodeURIComponent(hubId)}`;
    }

    detectEditor() {
        try {
            const host = (window.location.hostname || "").toLowerCase();
            return EDITOR_HOST_MARKERS.some((marker) => host.includes(marker));
        } catch (e) {
            return false;
        }
    }
}