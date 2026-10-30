import { LightningElement, wire, api, track } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import getTopics from '@salesforce/apex/ArticleListController.getTopics';
import getArticles from '@salesforce/apex/ArticleListController.getArticles';
export default class ArticleList extends NavigationMixin(LightningElement) {
    @api recordId;
    @track articles = [];
    @track displayedArticles = [];
    @track error = false;
    @track isLoadingMore = false;
    @track hasMoreArticles = false;
    @track selectedTopic;
    pageSize = 12;
    currentPage = 1;
    @track allArticles;
    topics = [];
    @track visibleTopics;
    @track hiddenTopics = [];
    @track showMoreButton = false;
    @track dropdownClass = false;
    @track isSortDropdownOpen = false;
    @track buttons;
    @track sortOptions=[
        { id: 'sortByPublishDateLatest', value:'LATEST PUBLISH DATE' },
        { id: 'sortByPublishDateOldest', value:'OLDEST PUBLISH DATE' },
        { id: 'sortByPopularityMost', value:'MOST POPULAR' }
    ]
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.attributes.recordId; 
        }
    }

    @wire(getTopics)
    wiredTopics({ error, data }) {
        if (data) {
            this.topics = data;
            if (this.topics.length > 0) {
                this.selectedTopic = this.recordId;
            }

            this.topics = data.map(topic => ({
                ...topic,
                'class': topic.Id === this.selectedTopic ? 'slds-button slds-button_neutral selected' : 'slds-button slds-button_neutral'
            }));
            this.updateVisibleAndHiddenTopics();


        } else if (error) {
            this.error = error;
        }
       
    }


    @wire(getArticles, { recordId: '$selectedTopic' })
    getArticlesData({ error, data }) {
        if (data) {
            this.allArticles = data.map((item, index) => ({
                ...item, 
                publishedDate: new Date(item.LastPublishedDate).toDateString().slice(4, 10),
                publishedYear: new Date(item.LastPublishedDate).toDateString().slice(11, item.LastPublishedDate.length+1)
            }));
            this.updateDisplayedArticles();
        } else if (error) {
            this.error = error;
        }
        this.isLoadingMore = false;
    }

    updateSelectedButton() {
        this.topics = data.map(topic => ({
            ...topic,
            'class': topic.Id === this.selectedTopic ? 'slds-button  selected' : 'slds-button slds-button_neutral'
        }));
        
    }
    updateVisibleAndHiddenTopics() {
        const maxVisibleTabs = 12; 
        if (this.topics.length > maxVisibleTabs) {
            this.visibleTopics = this.topics.slice(0, maxVisibleTabs);
            this.hiddenTopics = this.topics.slice(maxVisibleTabs, this.topics.length + 1);
            this.showMoreButton = true;
        } else {
            this.visibleTopics = this.topics;
            this.hiddenTopics = [];
            this.showMoreButton = false;
        }

        this.visibleTopics=[...this.visibleTopics].sort((a, b) => {
            const dateA = new Date(a.CreatedDate || 0);
            const dateB = new Date(b.CreatedDate || 0);
            const dateComparison = dateA - dateB;
            if (dateComparison == 0) {
                const dateC = new Date(a.SystemModstamp || 0);
                const dateD = new Date(b.SystemModstamp || 0);
                return dateC-dateD;
            }
            return dateComparison;
        });

    }
    toggleDropdown() {
        if (this.dropdownClass) {
            const menu = this.template.querySelector('.dropdown-menu');
            this.dropdownClass = false;
            menu.classList.remove('active');
        }
        else {
            const menu = this.template.querySelector('.dropdown-menu');
            this.dropdownClass = true;
            menu.classList.add('active');
        }

    }

    handleTopicChange(event) {
        this.selectedTopic = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({

            type: 'standard__recordPage',

            attributes: {

                recordId: this.selectedTopic,

                objectApiName: 'Topic',

                actionName: 'view'

            }

        });
        



    }
    loadArticles() {
        this.isLoadingMore = true;
        this.offset = this.pageSize * (this.currentPage - 1);
        this.loadMoreArticles();
    }

    updateDisplayedArticles() {
        const startIndex = 0;
        let endIndex = startIndex + (this.pageSize * this.currentPage);
        if (endIndex >= this.allArticles.length) {
            endIndex = this.allArticles.length;
            this.hasMoreArticles = false;
        }
        else {
            this.hasMoreArticles = true;
        }
        this.displayedArticles = this.allArticles.slice(startIndex, endIndex);
    }

    loadMoreArticles() {
        this.currentPage += 1;
        this.updateDisplayedArticles();
    }

    handleTileClick(event) {
        const articleId = event.currentTarget.dataset.id;
        this.navigateToArticle(articleId);
    }

    navigateToArticle(articleId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: articleId,
                objectApiName: 'Knowledge__kav',
                actionName: 'view'
            }
        });
    }
    get getButtonClass() {
        return (topicId) => {
            return topicId === this.selectedTopicId ? 'slds-button slds-button_brand' : 'slds-button slds-button_neutral';
        };
    }

    

    sorttoggleDropdown() {
        this.isSortDropdownOpen = !this.isSortDropdownOpen;
    }
    sort(event){
        this.sortOptions = this.sortOptions.map(button => ({
            ...button,
            'selected': button.id === event.currentTarget.dataset.id ? true : false
        }));
        const sortType = event.currentTarget.dataset.id;
        if(sortType=='sortByPublishDateOldest')
        {
            this.allArticles=[...this.allArticles].sort((a, b) => {
                const dateA = new Date(a.LastPublishedDate || 0);
                const dateB = new Date(b.LastPublishedDate || 0);
                return dateA - dateB; // Descending order
            });
            this.updateDisplayedArticles();
        }
        else if(sortType=='sortByPublishDateLatest'){
            this.allArticles=[...this.allArticles].sort((a, b) => {
                const dateA = new Date(a.LastPublishedDate || 0);
                const dateB = new Date(b.LastPublishedDate || 0);
                return dateB - dateA; // Ascending order
            });
            this.updateDisplayedArticles();
        }
        else if(sortType=='sortByPopularityMost'){
            this.allArticles=[...this.allArticles].sort((a, b) => {
              
                return a.ArticleTotalViewCount - b.ArticleTotalViewCount; 
            });
            this.updateDisplayedArticles();
        }
        else if(sortType=='sortByPopularityLess'){
            this.allArticles=[...this.allArticles].sort((a, b) => {
              
                return b.ArticleTotalViewCount - a.ArticleTotalViewCount; 
            });
            this.updateDisplayedArticles();
        }
        this.isSortDropdownOpen=false;
    }
    
}