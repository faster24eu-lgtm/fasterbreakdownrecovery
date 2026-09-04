(function () {
  "use strict";

  /* Mobile navigation toggle */
  var navToggle = document.querySelector(".nav-toggle");
  var mobileNav = document.querySelector(".mobile-nav");

  if (navToggle && mobileNav) {
    navToggle.addEventListener("click", function () {
      var isOpen = mobileNav.classList.toggle("is-open");
      navToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
    });

    mobileNav.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        mobileNav.classList.remove("is-open");
        navToggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  /* Populate contact placeholders from central config */
  if (window.SITE_CONFIG) {
    var cfg = window.SITE_CONFIG;

    document.querySelectorAll('[data-contact="phone-href"]').forEach(function (el) {
      el.setAttribute("href", cfg.phone.href);
    });
    document.querySelectorAll('[data-contact="phone-display"]').forEach(function (el) {
      el.textContent = cfg.phone.display;
    });
    document.querySelectorAll('[data-contact="email-href"]').forEach(function (el) {
      el.setAttribute("href", cfg.email.href);
    });
    document.querySelectorAll('[data-contact="email-display"]').forEach(function (el) {
      el.textContent = cfg.email.display;
    });
    document.querySelectorAll('[data-contact="whatsapp-href"]').forEach(function (el) {
      el.setAttribute("href", cfg.whatsapp.href);
    });
    document.querySelectorAll('[data-contact="whatsapp-display"]').forEach(function (el) {
      el.textContent = cfg.whatsapp.display;
    });
  }

  /* Footer year */
  var yearEl = document.getElementById("current-year");
  if (yearEl) {
    yearEl.textContent = new Date().getFullYear();
  }
})();
