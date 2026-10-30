import { LightningElement,wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getArticles from '@salesforce/apex/ArticleListController.getTopRatedArticles';
export default class TopRatedArtcles extends NavigationMixin(LightningElement){
    articles = [];
    leftColumnArticles = [];
    rightColumnArticles = [];

    @wire(getArticles)
    wiredArticles({ error, data }) {
        if (data) {
            this.articles = data;
            this.splitArticles(data);
        } else if (error) {
            console.error('Error fetching articles: ', error);
        }
    }

    splitArticles(articles) {
        // Divide articles into two columns
        this.leftColumnArticles = articles.slice(0, 5);
        this.rightColumnArticles = articles.slice(5, 10);
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
}