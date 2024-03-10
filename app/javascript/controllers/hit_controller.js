import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="hit"
export default class extends Controller {
  referred = false;
  
  connect() {
    this.element.addEventListener('mouseover', () => this.handleHover());
  }

  handleHover() {
    if (this.referred) return;
    const pageUrl = encodeURIComponent(window.location.href);
    const requestUrl = `/hit/handle?ref=${pageUrl}`;

    fetch(requestUrl, {
      method: 'GET',
    }).then(response => {
      if (response.ok) {
        this.referred = true;
      } else {
        console.error('Request failed');
      }
    });
  }
}
