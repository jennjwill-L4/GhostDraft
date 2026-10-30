import { LightningElement, wire, track, api } from 'lwc';
import getArticlesByKeys from '@salesforce/apex/ArticleListController.getArticlesByKeys';

export default class ArticleRecommendations extends LightningElement {
    @track articles = []
    @api varSubject;
    @api varDescription;
    error;
    
    get keywords(){
        const subjectSplit = this.varSubject?this.varSubject.split(/\s+/g):[];
        const descriptionSplit = this.varDescription?this.varDescription.split(/\s+/g):[];
        return [...subjectSplit, ...descriptionSplit];
    }
    
    @wire(getArticlesByKeys, { keys: '$keywords' })
    wiredArticles(result) {
        if (result.data) {
            this.articles = result.data;
        } else {
            console.log('error in wiredArticles', JSON.stringify(result.error))
        }
    }
    
    goToArticle(event) {
        window.open(
            `article/${event.target.dataset.url}`,
            '_blank'
        );
    }

    // goToAllArticles() {
    //     window.open(
    //         `/s/knowledge-base`,
    //         '_blank'
    //     );
    // }
}