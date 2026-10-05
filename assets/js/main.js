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

/* Hero Google review carousel (same behaviour as takeldienstfaster.be) */
(function () {
  "use strict";
  var box = document.querySelector(".hero-review");
  if (!box) return;
  var slides = box.querySelectorAll(".hero-review-slide");
  var dotsWrap = box.querySelector(".hero-review-dots");
  var current = 0, timer = null, paused = false;
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var dots = Array.prototype.map.call(slides, function (_, i) {
    var b = document.createElement("button");
    b.type = "button";
    b.setAttribute("aria-label", "Show review " + (i + 1) + " of " + slides.length);
    b.addEventListener("click", function () { show(i); restart(); });
    dotsWrap.appendChild(b);
    return b;
  });

  function show(i) {
    slides[current].classList.remove("is-active");
    dots[current].removeAttribute("aria-current");
    current = (i + slides.length) % slides.length;
    slides[current].classList.add("is-active");
    dots[current].setAttribute("aria-current", "true");
  }
  function restart() {
    clearInterval(timer);
    if (reduce || paused) return;
    timer = setInterval(function () { show(current + 1); }, 4000);
  }

  box.addEventListener("mouseenter", function () { paused = true; restart(); });
  box.addEventListener("mouseleave", function () { paused = false; restart(); });
  box.addEventListener("focusin", function () { paused = true; restart(); });
  box.addEventListener("focusout", function () { paused = false; restart(); });

  show(0);
  restart();
})();
