import { LightningElement , track, wire, api} from 'lwc';
import {
    subscribe,
    unsubscribe,
    onError,
    setDebugFlag,
    isEmpEnabled,
} from 'lightning/empApi';
import { loadScript } from "lightning/platformResourceLoader";
import cometd from "@salesforce/resourceUrl/cometd";
import getSessionId from '@salesforce/apex/CometDController.getSessionId';
export default class TestComponent extends LightningElement {

    // channelName = '/event/FeedItem__e';

    // renderSection = false;
   
    // connectedCallback(){
    //     //call the handle sub on
    //     this.handleSubscription();
    // }


    //     // Handles subscribe button click
    // handleSubscription() {
    //     // Callback invoked whenever a new event message is received
    //     console.log( 'testcomponent in subs');
    //     const messageCallback = function (response) {
             
    //         console.log('New message received: ', JSON.stringify(response));    
    //         console.log( response);
            
    //         this.renderSection = true;
    //         // Response contains the payload of the new message received
    //     };


    //     // Invoke subscribe method of empApi. Pass reference to messageCallback
    //     subscribe(this.channelName, -2, messageCallback.bind(this)).then((response) => {
    //         // Response contains the subscription information on subscribe call
    //         console.log(
    //             'Subscription request sent to: ',
    //             JSON.stringify(response.channel)
    //         );           
    //     });
    // }
    //@api channel;

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
            console.log('Channel Name  ');
            if (status.successful) {
                cometdlib.subscribe('/event/FeedItem__e', function(message){
                    // const selectedEvent = new CustomEvent('message', { detail: message });
                    // lwcThisContext.dispatchEvent(selectedEvent);
                    console.log('successss'+message);
                });
            } else {
                console.error('Error in handshaking: ' + JSON.stringify(status));
            }
        });
    }
}