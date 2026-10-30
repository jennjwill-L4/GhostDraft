import { LightningElement, api, wire ,track} from 'lwc';

import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import createFeedItem from '@salesforce/apex/CaseCommunicationController.createFeedItem';
import getFeedItems from '@salesforce/apex/CaseCommunicationController.getFeedItems';
import networkId from '@salesforce/community/Id';
import basePath from '@salesforce/community/basePath';
import Id from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import UserNameFIELD from '@salesforce/schema/User.Name';
import userEmailFIELD from '@salesforce/schema/User.Email';
import userIsActiveFIELD from '@salesforce/schema/User.IsActive';
import userAliasFIELD from '@salesforce/schema/User.Alias';
import { generateUrl } from "lightning/fileDownload";
import { loadStyle } from 'lightning/platformResourceLoader';
import fileSelectorStyle from '@salesforce/resourceUrl/fileSelectorStyle';
import CASE_STATUS_FIELD from '@salesforce/schema/Case.Status';

export default class CaseCommunicationFeed extends NavigationMixin(LightningElement)  {
    
    @api recordId;
    @track isClosed = false;
    // Add to your JS
@track isPosting = false;
    
    communications;
     wiredResult;
    filteredCommunications;
    error;
    @track showAttachments=true;
    isCase = true;
    loading = true;
    filterType = '';
    startDate = '';
    endDate = '';
    sortOrder = 'mostRecent';
    @track newComment;
    @track uploadedFiles = [];
    @track uploadedFileIds=[];
    @track modal;
    @track clickedFile;
    showPreviewModal;
    showImage;
    showIframe;
    createdCaseText='created this case';
    @api channelName = '/event/FeedItem__e';
    @track error;
    @track userId = Id;
    @track currentUserName;
    @track currentUserEmail;
    @track currentIsActive;
    @track currentUserAli
    message;
    subscription = {};
    @track pendingImages = [];

    richTextFormats = [
    'bold',
    'italic',
    'underline',
    'strike',
    'list',
    'link',
    'emoji',
    'clean'
];
    

    filterOptions = [
        { label: 'All', value: 'All' },
        { label: 'Only Comment', value: 'OnlyComment' },
        { label: 'Comments With Attachments', value: 'CommentsWithAttachments' }
        
    ];

    sortOptions = [
        { label: 'Most Recent', value: 'mostRecent' },
        { label: 'Oldest', value: 'oldest' }
    ];

   

    @wire(getRecord, { recordId: Id, fields: [UserNameFIELD, userEmailFIELD, userIsActiveFIELD, userAliasFIELD ]}) 
    currentUserInfo({error, data}) {
        if (data) {
            this.currentUserName = data.fields.Name.value;
            this.currentUserEmail = data.fields.Email.value;
            this.currentIsActive = data.fields.IsActive.value;
            this.currentUserAlias = data.fields.Alias.value;

        } else if (error) {
            this.error = error ;
        }
    }

    //new wire to get case status
    @wire(getRecord, { recordId: '$recordId', fields: [CASE_STATUS_FIELD] })
caseInfo({ error, data }) {
    if (data) {
        const closedStatuses = ['Closed', 'Closed - Deflected'];
        this.isClosed = closedStatuses.includes(data.fields.Status.value);
    } else if (error) {
        this.error = error;
    }
} 

connectedCallback() {
        this.refreshFeed();
        loadStyle(this, fileSelectorStyle);

        // Document-level capture — fires before Quill's own shadow-root listener.
        this._boundPaste = this.handlePaste.bind(this);
        document.addEventListener('paste', this._boundPaste, true);
    }

    disconnectedCallback() {
        if (this._refreshIntervalId) {
            clearInterval(this._refreshIntervalId);
        }
        if (this._boundPaste) {
            document.removeEventListener('paste', this._boundPaste, true);
        }
    }

    refreshFeed() {
    this._refreshIntervalId = setInterval(() => {
        refreshApex(this.wiredResult)
            .catch((error) => {
                console.error('Error refreshing data:', error);
            });
    }, 60 * 1000);
    }


// Pull base64 <img> tags out of the rich text and replace them with placeholders.
    // Returns { cleanBody, images[] }
    extractInlineImages(html) {
        const images = [];
        if (!html) return { cleanBody: '', images };

        let cleanBody = html;
        const imgRegex = /<img[^>]+src=["']data:([^;]+);base64,([^"']+)["'][^>]*>/gi;
        let match;

        while ((match = imgRegex.exec(html)) !== null) {
            const mimeType = match[1];                 // image/png
            const base64Data = match[2];
            const ext = (mimeType.split('/')[1] || 'png').toLowerCase();
            const fileName = `pasted-image-${Date.now()}-${images.length + 1}.${ext}`;

            images.push({ base64Data, mimeType, fileName });
            cleanBody = cleanBody.replace(match[0], `<p>[Image: ${fileName}]</p>`);
        }

        return { cleanBody, images };
    }

    handlePaste(event) {
        if (!this._rteFocused) return;

        const items = event.clipboardData && event.clipboardData.items;
        if (!items) return;

        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (item.type && item.type.indexOf('image') !== -1) {
                if (item.type === 'image/svg+xml') {
                    event.preventDefault();
                    this.showToast('Not supported', 'SVG images cannot be pasted.', 'error');
                    return;
                }
                event.preventDefault();
                event.stopPropagation();
                const file = item.getAsFile();
                if (file) this.readPastedImage(file);
                return;
            }
        }
    }

    handleRteFocusIn()  { this._rteFocused = true;  }
    handleRteFocusOut() { this._rteFocused = false; }

    readPastedImage(file) {
        const MAX_BYTES = 5 * 1024 * 1024;
        if (file.size > MAX_BYTES) {
            this.showToast('Too large', 'Pasted images must be under 5 MB.', 'error');
            return;
        }

        const reader = new FileReader();
        reader.onload = () => {
            const dataUrl = reader.result;
            const mimeType = dataUrl.substring(5, dataUrl.indexOf(';'));
            const base64Data = dataUrl.substring(dataUrl.indexOf(',') + 1);
            const ext = (mimeType.split('/')[1] || 'png').toLowerCase();
            const fileName = `pasted-image-${Date.now()}-${this.pendingImages.length + 1}.${ext}`;

            this.pendingImages = [...this.pendingImages, { base64Data, mimeType, fileName }];
            this.updateAttachmentPreview();   // show it to the user
        };
        reader.onerror = () => {
            this.showToast('Error', 'Could not read the pasted image.', 'error');
        };
        reader.readAsDataURL(file);
    }



    @wire(getFeedItems, { recordId: '$recordId' })
    wiredCommunications( result) {
        this.wiredResult = result; 
        const { error, data } = result;
        if (data) {
            const before_ = `${basePath}`.substring(0, `${basePath}`.indexOf('/s')+1);       
            const communityUrl = `https://${location.host}${before_}`;
            this.communications = data.map((item, index) => ({
                ...item, 
                currentUser: item.feedItem.CreatedBy.Name == this.currentUserName,        
                caseCreated: item.feedItem.Type == 'CreateRecordEvent',
                createdDate: this.formatDateTime(item.feedItem.CreatedDate),              
                attachments: item.contentVersions ? item.contentVersions.map(att => ({
                    id: att.Id,
                    contentDocumentId: att.ContentDocumentId,
                    title: att.Title,
                    size: att.ContentSize,
                    type: att.FileType,
                    Url: `${communityUrl}sfc/servlet.shepherd/version/download/${att.Id}`
                }))
                : []
            
            }));

            this.error = undefined;
            this.filterAndSortCommunications();
        } else if (error) {
            this.error = error;
            this.communications = undefined;
        }
        this.loading = false;
    }

    formatDateTime(date) {
        if (!date) {
            return '';
        }

        const d = new Date(date);
        const pad = (num) => (num < 10 ? '0' + num : num);

        const month = pad(d.getMonth() + 1);
        const day = pad(d.getDate());
        const year = d.getFullYear();
        const hours = pad(d.getHours());
        const minutes = pad(d.getMinutes());
        const seconds = pad(d.getSeconds());

        return `${month}/${day}/${year} ${hours}:${minutes}:${seconds}`;
    }


    handleFilterChange(event) {
        this.filterType = event.detail.value;
        this.filterAndSortCommunications();
    }

    handleSortChange(event) {
        this.sortOrder = event.detail.value;
        this.filterAndSortCommunications();
    }

    filterAndSortCommunications() {


        if (!this.communications) {
            this.filteredCommunications = [];
            return;
        }

        let filtered = this.communications;

        if (this.filterType=='OnlyComment') {
            this.showAttachments=false;
            filtered=this.communications.filter(item => !item.caseCreated);
        }
        else if (this.filterType=='CommentsWithAttachments'){
            this.showAttachments=true;
            filtered=this.communications.filter(item => item.attachments && item.attachments.length > 0);
            
        }
        else if(this.filterType=='All'){
            this.showAttachments=true;
        }

        if (this.sortOrder === 'mostRecent') {
            filtered = filtered.sort((a, b) => new Date(b.createdDate) - new Date(a.createdDate));
        } else if (this.sortOrder === 'oldest') {
            filtered = filtered.sort((a, b) => new Date(a.createdDate) - new Date(b.createdDate));
        }

        this.filteredCommunications = filtered;
    }

    handleCommentChange(event){
        this.newComment = event.detail.value;

    }

async postComment() {
        if (this.isClosed) {
            this.showToast('Not allowed', 'This case is closed for commenting.', 'error');
            return;
        }

        const { cleanBody, images } = this.extractInlineImages(this.newComment);
        const allImages = [...this.pendingImages, ...images];   // CHANGED

        //temp debug
        console.log('pendingImages:', this.pendingImages.length,
                    'extracted:', images.length,
                    'total:', allImages.length);

        const plainText = cleanBody
            ? cleanBody.replace(/<[^>]+>/g, '').replace(/&nbsp;/g, '').trim()
            : '';

        const hasAttachments =
            (this.uploadedFiles && this.uploadedFiles.length > 0) || allImages.length > 0;
        if (!plainText && !hasAttachments) {
            this.showToast('Error', 'Comment body cannot be empty.', 'error');
            return;
        }

        this.isPosting = true;

        try {
            this.uploadedFileIds = [];
            this.uploadedFiles.forEach((file) => {
                this.uploadedFileIds.push([file.documentId, file.contentVersionId, file.name]);
            });

            await createFeedItem({
                bodyText: cleanBody,
                parentId: this.recordId,
                fileIds: this.uploadedFileIds,
                communityId: null,
                inlineImages: allImages         
            });

            this.showToast('Success', 'Comment added', 'success');
            this.newComment = '';
            this.uploadedFiles = [];
            this.uploadedFileIds = [];
            this.pendingImages = [];             
            this.updateAttachmentPreview(); 

            const preview = this.template.querySelector('.attachment-preview');
            if (preview) {
                preview.innerHTML = '';
                preview.style.display = 'none';
            }

            refreshApex(this.wiredResult).catch((err) => {
                console.error('Refresh after post failed:', JSON.stringify(err));
            });

        } catch (error) {
            console.error('postComment error:', JSON.stringify(error));
            const msg = error?.body?.message || error?.message || 'Failed to add comment';
            this.showToast('Error', msg, 'error');
        } finally {
            this.isPosting = false;
        }
    }

    handleUploadFinished(event) {
        const files = event.detail.files; 
        const baseDomain = window.location.origin;
        const _uploadedFiles = files.map((file) => ({
            name: file.name,
            url: `${baseDomain}/sfc/servlet.shepherd/document/download/${file.documentId}`, 
            documentId: file.documentId,
            contentVersionId: file.contentVersionId
        }));

        this.uploadedFiles = [...this.uploadedFiles, ..._uploadedFiles];
        this.updateAttachmentPreview();
    }

    updateAttachmentPreview() {
        const previewContainer = this.template.querySelector('.attachment-preview');
        if (!previewContainer) return;
        previewContainer.innerHTML = '';

        // Uploaded files
        this.uploadedFiles.forEach((file, index) => {
            const fileDiv = document.createElement('div');
            fileDiv.className = 'attachment-item';
            const fileLink = document.createElement('a');
            fileLink.textContent = file.name;
            fileLink.onclick = (e) => e.preventDefault();

            const removeButton = document.createElement('span');
            removeButton.textContent = ' ✖';
            removeButton.className = 'remove-attachment';
            removeButton.onclick = () => this.removeAttachment(index);

            fileDiv.appendChild(fileLink);
            fileDiv.appendChild(removeButton);
            previewContainer.appendChild(fileDiv);
        });

        // Pasted images
        this.pendingImages.forEach((img, index) => {
            const imgDiv = document.createElement('div');
            imgDiv.className = 'attachment-item';

            const thumb = document.createElement('img');
            thumb.src = `data:${img.mimeType};base64,${img.base64Data}`;
            thumb.style.height = '32px';
            thumb.style.verticalAlign = 'middle';
            thumb.style.marginRight = '6px';

            const label = document.createElement('span');
            label.textContent = img.fileName;

            const removeButton = document.createElement('span');
            removeButton.textContent = ' ✖';
            removeButton.className = 'remove-attachment';
            removeButton.onclick = () => this.removePendingImage(index);

            imgDiv.appendChild(thumb);
            imgDiv.appendChild(label);
            imgDiv.appendChild(removeButton);
            previewContainer.appendChild(imgDiv);
        });

        const hasAny = this.uploadedFiles.length > 0 || this.pendingImages.length > 0;
        previewContainer.style.display = hasAny ? 'block' : 'none';
    }

    removePendingImage(index) {
        this.pendingImages = this.pendingImages.filter((_, i) => i !== index);
        this.updateAttachmentPreview();
    }

    removeAttachment(index) {
        this.uploadedFiles.splice(index, 1); 
        this.updateAttachmentPreview(); 
    }

    previewHandler(event) {
        const targetAttachment = this.communications
            .flatMap(item => item.attachments)
            .find(att => att.id === event.target.dataset.id);

        if (!targetAttachment) return;

        const type = (targetAttachment.type || '').toUpperCase();
        const imageTypes = ['PNG', 'JPG', 'JPEG', 'GIF', 'WEBP', 'BMP'];
        const iframeTypes = ['PDF', 'WORD_X'];

        if (imageTypes.includes(type)) {
            this.showImage = true;
        } else if (iframeTypes.includes(type)) {
            this.showIframe = true;
        }

        this.modal = targetAttachment;
        this.showPreviewModal = true;
    }

    closePreviewModal()
    {
        this.showImage=false;
        this.showIframe=false;
        this.modal = undefined;
        this.showPreviewModal=false;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event); 
    }

    handleDownload(event) {

        const targetAttachment = this.communications
            .flatMap(item => item.attachments) 
            .find(att => att.id === event.target.dataset.id);
        
        this.url = generateUrl(targetAttachment.contentDocumentId);
    
    window.open(this.url);
        
    }
}