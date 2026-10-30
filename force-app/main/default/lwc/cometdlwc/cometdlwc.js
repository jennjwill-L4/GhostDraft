import { LightningElement, track, wire, api } from 'lwc';
import { loadScript } from "lightning/platformResourceLoader";
import cometd from "@salesforce/resourceUrl/cometd";
import getSessionId from '@salesforce/apex/CometDController.getSessionId';

export default class Cometdlwc extends LightningElement {

    @api channel;

    libInitialized = false;
    @track sessionId;
    @track error;

    @wire(getSessionId)
    wiredSessionId({ error, data }) {
        if (data) {
            this.sessionId = data;
            this.error = undefined;
            loadScript(this, cometd)
            .then(() => {
                this.initializecometd()
            });
        } else if (error) {
            console.log(error);
            this.error = error;
            this.sessionId = undefined;
        }
    }

    initializecometd() {
        if (this.libInitialized) {
            return;
        }
        this.libInitialized = true;
        var lwcThisContext = this;
        var cometdlib = new window.org.cometd.CometD();
        cometdlib.configure({
            url: window.location.protocol + '//' + window.location.hostname + '/cometd/51.0/',
            requestHeaders: { Authorization: 'OAuth ' + this.sessionId},
            appendMessageTypeToURL : false,
            logLevel: 'debug'
        });
        cometdlib.websocketEnabled = false;
        cometdlib.handshake(function(status) {
            console.log('Channel Name  ', lwcThisContext.channel);
            if (status.successful) {
                cometdlib.subscribe('/event/'+ lwcThisContext.channel, function(message){
                    const selectedEvent = new CustomEvent('message', { detail: message });
                    lwcThisContext.dispatchEvent(selectedEvent);
                });
            } else {
                console.error('Error in handshaking: ' + JSON.stringify(status));
            }
        });
    }
}