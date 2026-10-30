import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';
import searchArticles from '@salesforce/apex/Clickhelpsearchcontroller.searchArticles';

const PAGE_SIZE = 10;

export default class CaseDeflection extends LightningElement {
    // Inputs from the flow
    @api subject;
    @api description;

    // Output back to the flow
    @api issueResolved = false;

    articles = [];
    isLoading = true;
    currentPage = 0;

    connectedCallback() {
        this.loadArticles();
    }

    async loadArticles() {
        try {
            const res = await searchArticles({ term: this.subject });

            const seen = new Set();
            this.articles = (res || [])          
                .filter((a) => {
                    if (!a.fullUrl) return false;
                    const key = `${a.ftsTitleHtml || a.title || ''}|${a.ftsSnippetHtml || ''}`;
                    if (seen.has(key)) return false;
                    seen.add(key);
                    return true;
                })
                .map((a, i) => ({
                    key: `${i}-${a.id}`,
                    fullUrl: a.fullUrl,
                    projectTitle: a.projectTitle,
                    titleHtml: a.ftsTitleHtml || a.title,
                    snippetHtml: a.ftsSnippetHtml
                }));
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Deflection article search failed', e);
            this.articles = [];
        } finally {
            this.isLoading = false;
        }
    }

    get hasArticles() {
        return this.articles.length > 0;
    }

    // ---- pagination -------------------------------------------------------
    get pagedArticles() {
        const start = this.currentPage * PAGE_SIZE;
        return this.articles.slice(start, start + PAGE_SIZE);
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.articles.length / PAGE_SIZE));
    }

    get showPager() {
        return this.articles.length > PAGE_SIZE;
    }

    get pagerLabel() {
        const start = this.currentPage * PAGE_SIZE + 1;
        const end = Math.min((this.currentPage + 1) * PAGE_SIZE, this.articles.length);
        return `${start}\u2013${end} of ${this.articles.length}`;
    }

    get disablePrev() {
        return this.currentPage === 0;
    }

    get disableNext() {
        return this.currentPage >= this.totalPages - 1;
    }

    handlePrev() {
        if (this.currentPage > 0) {
            this.currentPage -= 1;
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages - 1) {
            this.currentPage += 1;
        }
    }

    // ---- flow -------------------------------------------------------------
    resolve(value) {
        this.issueResolved = value;
        this.dispatchEvent(new FlowAttributeChangeEvent('issueResolved', value));
        this.dispatchEvent(new FlowNavigationNextEvent());
    }

    handleYes() {
        this.resolve(true);
    }

    handleNo() {
        this.resolve(false);
    }
}