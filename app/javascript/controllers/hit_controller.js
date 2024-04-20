import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="hit"
// check application_layout.rb
export default class extends Controller {
  referred = false;
  isRequesting = false;
  
  connect() {
    this.element.addEventListener('mouseover', () => this.debounce(this.handleHover()));
  }

  handleHover() {
    if (this.referred || this.isRequesting) return;
    this.isRequesting = true;
    const pageUrl = encodeURIComponent(window.location.href);
    const referrer = encodeURIComponent(document.referrer);

    const requestUrl = `/hit/handle?ref=${referrer}&page=${pageUrl}`;

    fetch(requestUrl, {
      method: 'GET',
      credentials: 'include',
    }).then(response => {
      if (response.ok) {
        this.referred = true;
        this.isRequesting = false;
      }
    }).catch(error => {
      console.error('Network error:', error);
      this.isRequesting = false;
    });
  }

  debounce(func) {
    let timeoutId;
    return function() {
      const context = this;
      const args = arguments;
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => {
        func.apply(context, args);
      }, 3000);
    }
  }
}
