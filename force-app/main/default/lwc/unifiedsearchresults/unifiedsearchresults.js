import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import basePath from '@salesforce/community/basePath';
import search from '@salesforce/apex/Clickhelpsearchcontroller.search';

const DEFAULT_PAGE_SIZE = 10;
const IMAGE_EXTS = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'];

export default class UnifiedSearchResults extends NavigationMixin(LightningElement) {
    @api searchTerm;
    @api showSearchBox = false;
    @api heading = 'Search Results';
    @api pageSize = DEFAULT_PAGE_SIZE;

    term = '';
    articles = [];
    files = [];
    cases = [];
    isLoading = false;
    hasSearched = false;

    articlePage = 0;
    filePage = 0;
    casePage = 0;

    // file preview modal
    previewOpen = false;
    previewType = 'none'; // 'image' | 'none'
    previewTitle = '';
    previewUrl = '';
    previewName = '';

    get size() {
        const n = parseInt(this.pageSize, 10);
        return n && n > 0 ? n : DEFAULT_PAGE_SIZE;
    }

    // ---- term acquisition -------------------------------------------------
    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (!pageRef) {
            return;
        }
        const fromUrl =
            pageRef.state?.term ||
            pageRef.state?.searchTerm ||
            pageRef.attributes?.searchTerm ||
            pageRef.attributes?.searchKey;

        const next = this.searchTerm || fromUrl;
        if (next) {
            const decoded = this.safeDecode(next);
            if (decoded && decoded !== this.term) {
                this.term = decoded;
                this.runSearch();
            }
        }
    }

    safeDecode(value) {
        try {
            return decodeURIComponent(value);
        } catch (e) {
            return value;
        }
    }

    handleInputChange(event) {
        this.term = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.runSearch();
        }
    }

    handleSearchClick() {
        this.runSearch();
    }

    // ---- data fetch -------------------------------------------------------
    async runSearch() {
        if (!this.term || !this.term.trim()) {
            return;
        }
        this.isLoading = true;
        this.articlePage = 0;
        this.filePage = 0;
        this.casePage = 0;

        try {
            const res = await search({ term: this.term });

            const siteRoot = basePath.replace(/\/s$/, '');

            const seen = new Set();
            this.articles = (res.articles || [])
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

            this.cases = (res.cases || []).map((c) => ({
                id: c.id,
                caseNumber: c.caseNumber,
                subject: c.subject,
                status: c.status,
                createdDate: c.createdDate
            }));

            this.files = (res.files || []).map((f) => {
                const ext = (f.fileExtension || '').toLowerCase();
                const baseName = f.title || 'file';
                const downloadName =
                    ext && !baseName.toLowerCase().endsWith(`.${ext}`)
                        ? `${baseName}.${ext}`
                        : baseName;
                const isImage = IMAGE_EXTS.includes(ext);
                const isPdf = ext === 'pdf';
                return {
                    id: f.id,
                    contentDocumentId: f.contentDocumentId,
                    title: f.title,
                    fileExtension: ext,
                    isImage,
                    isPdf,
                    isOther: !isImage && !isPdf,
                    downloadName,
                    sizeLabel: this.formatSize(f.contentSize),
                    lastModifiedDate: f.lastModifiedDate,
                    fileUrl: `${siteRoot}/sfc/servlet.shepherd/document/download/${f.contentDocumentId}?operationContext=S1`
                };
            });
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Unified search failed', e);
            this.articles = [];
            this.cases = [];
            this.files = [];
        } finally {
            this.isLoading = false;
            this.hasSearched = true;
        }
    }

    // ---- file preview (images preview; unsupported types show download) ----
    openPreview(event) {
        const ds = event.currentTarget.dataset;
        this.previewType = ds.type || 'none';
        this.previewUrl = ds.url;
        this.previewTitle = ds.title || 'File';
        this.previewName = ds.name || this.previewTitle;
        this.previewOpen = true;
    }

    closePreview() {
        this.previewOpen = false;
        this.previewUrl = '';
    }

    get isImagePreview() {
        return this.previewType === 'image';
    }
    get isNoPreview() {
        return this.previewType === 'none';
    }

    // ---- navigation -------------------------------------------------------
    openCase(event) {
        const caseId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: caseId, objectApiName: 'Case', actionName: 'view' }
        });
    }

    // ---- pagination -------------------------------------------------------
    get pagedArticles() {
        const start = this.articlePage * this.size;
        return this.articles.slice(start, start + this.size);
    }
    get pagedFiles() {
        const start = this.filePage * this.size;
        return this.files.slice(start, start + this.size);
    }
    get pagedCases() {
        const start = this.casePage * this.size;
        return this.cases.slice(start, start + this.size);
    }

    get articlePager() {
        return this.buildPager(this.articles.length, this.articlePage);
    }
    get filePager() {
        return this.buildPager(this.files.length, this.filePage);
    }
    get casePager() {
        return this.buildPager(this.cases.length, this.casePage);
    }

    buildPager(total, page) {
        const size = this.size;
        const totalPages = Math.max(1, Math.ceil(total / size));
        const start = total === 0 ? 0 : page * size + 1;
        const end = Math.min((page + 1) * size, total);
        return {
            total,
            label: `${start}\u2013${end} of ${total}`,
            show: total > size,
            disablePrev: page === 0,
            disableNext: page >= totalPages - 1
        };
    }

    articlePrev() {
        if (this.articlePage > 0) {
            this.articlePage -= 1;
        }
    }
    articleNext() {
        if ((this.articlePage + 1) * this.size < this.articles.length) {
            this.articlePage += 1;
        }
    }
    filePrev() {
        if (this.filePage > 0) {
            this.filePage -= 1;
        }
    }
    fileNext() {
        if ((this.filePage + 1) * this.size < this.files.length) {
            this.filePage += 1;
        }
    }
    casePrev() {
        if (this.casePage > 0) {
            this.casePage -= 1;
        }
    }
    caseNext() {
        if ((this.casePage + 1) * this.size < this.cases.length) {
            this.casePage += 1;
        }
    }

    // ---- helpers / getters ------------------------------------------------
    formatSize(bytes) {
        if (bytes === null || bytes === undefined) {
            return '';
        }
        if (bytes < 1024) {
            return `${bytes} B`;
        }
        if (bytes < 1048576) {
            return `${(bytes / 1024).toFixed(0)} KB`;
        }
        return `${(bytes / 1048576).toFixed(1)} MB`;
    }

    get hasArticles() {
        return this.articles.length > 0;
    }
    get hasCases() {
        return this.cases.length > 0;
    }
    get hasFiles() {
        return this.files.length > 0;
    }
    get hasAnyResults() {
        return this.hasArticles || this.hasCases || this.hasFiles;
    }
    get showEmptyState() {
        return this.hasSearched && !this.isLoading && !this.hasAnyResults;
    }
    get articleCountLabel() {
        return `${this.articles.length} Result${this.articles.length === 1 ? '' : 's'}`;
    }
    get caseCountLabel() {
        return `${this.cases.length} Result${this.cases.length === 1 ? '' : 's'}`;
    }
    get fileCountLabel() {
        return `${this.files.length} Result${this.files.length === 1 ? '' : 's'}`;
    }
}