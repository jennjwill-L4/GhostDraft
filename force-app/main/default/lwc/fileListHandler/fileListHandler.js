import { LightningElement } from 'lwc';

export default class FileListHandler extends LightningElement {


    renderedCallback() {

        const navContainer = document.querySelector('.leftNav ul');
        if (navContainer) {
            const navItems = navContainer.querySelectorAll('.fileSource_item');
            navItems.forEach(item => item.classList.remove('slds-is-active'));
            const librariesItem = navContainer.querySelector('li:last-child');
            if (librariesItem) {
                librariesItem.classList.add('slds-is-active');
                const librariesButton = librariesItem.querySelector('a[data-filesourceid="content_workspace"]');
                if (librariesButton) {
                    librariesButton.click();


                }

            }
        }

        const container = document.querySelector('.forceCommunityFileDetailPage');
        if (container) {

            const observer = new MutationObserver((mutations, obs) => {
                const tabs = container.querySelectorAll('ul.tabs__nav li.tabs__item');
                if (tabs) {
                    let previewTab1=null;
                    let detailsTab1=null;
                    tabs.forEach((tab) => {
                        const tabTitle = tab.querySelector('.title').textContent.trim(); 
                        if (tabTitle === 'Preview') {
                            previewTab1 = tab;
                        }
                        if (tabTitle === 'Details') {
                            detailsTab1=tab;

                        }
                    }); 
                    if (previewTab1) {
                            previewTab1.classList.remove('active');
                            previewTab1.querySelector('a.tabHeader').setAttribute('aria-selected', 'false');
                            previewTab1.querySelector('a.tabHeader').setAttribute('tabindex', '-1');
                            previewTab1.style.display = 'none';
                        }
                    if (detailsTab1) {
                            detailsTab1.classList.add('active');
                            detailsTab1.querySelector('a.tabHeader').setAttribute('aria-selected', 'true');
                            detailsTab1.querySelector('a.tabHeader').setAttribute('tabindex', '0');
                            const clickEvent = new Event('click', { bubbles: true, cancelable: true });
                            detailsTab1.querySelector('a.tabHeader').dispatchEvent(clickEvent);
                        }
                    let tabsetElement = document.querySelector('.uiTabset--base.uiTabset--default.uiTabset');

                    if (tabsetElement) {
                        tabsetElement.style.width = '1390px'; 
                    }
    
                    obs.disconnect(); 
                }
            });
            observer.observe(container, { childList: true, subtree: true });
        }
                
    }
    
}