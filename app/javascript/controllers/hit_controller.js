import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="hit"
export default class extends Controller {
  requestMade = false;
  connect() {
    console.log('Connected to the hit controller');
    console.log('document.referrer:', document.referrer);
    this.element.addEventListener('mouseover', () => this.handleHover());
  }

  handleHover() {
    if (this.requestMade) return;
    
    const pageUrl = encodeURIComponent(window.location.href); // Encode URL to ensure it's safe to include in a query string
    const requestUrl = `/hit/handle?ref=${pageUrl}`;

    fetch(requestUrl, {
      method: 'GET',
  
    }).then(response => {
      if (response.ok) {
        console.log('Request was successful');
        this.requestMade = true;
      } else {
        console.error('Request failed');
      }
    });
  }
}
