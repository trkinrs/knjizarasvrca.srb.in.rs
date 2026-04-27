---
layout: page
title: Pretraga
permalink: /pretraga/
---

<input id="search-input" type="search" placeholder="Pretraži proizvode..." autofocus
  style="width:100%;padding:0.6rem 0.8rem;font-size:1.1rem;border:1px solid #ccc;border-radius:6px;box-sizing:border-box;margin-bottom:1.5rem;">

<div id="search-results"></div>

<script src="https://unpkg.com/lunr/lunr.js"></script>
<script>
  var idx, docs;

  fetch('{{ "/search.json" | relative_url }}')
    .then(function(r) { return r.json(); })
    .then(function(data) {
      docs = data;
      idx = lunr(function() {
        this.ref('url');
        this.field('title', { boost: 10 });
        this.field('sku',   { boost: 5 });
        this.field('collection');
        data.forEach(function(doc) { this.add(doc); }, this);
      });
      var q = new URLSearchParams(window.location.search).get('q');
      if (q) {
        document.getElementById('search-input').value = q;
        renderResults(q);
      }
    });

  document.getElementById('search-input').addEventListener('input', function() {
    var q = this.value.trim();
    history.replaceState(null, '', q ? '?q=' + encodeURIComponent(q) : window.location.pathname);
    renderResults(q);
  });

  function renderResults(q) {
    var el = document.getElementById('search-results');
    if (!q || q.length < 2) { el.innerHTML = ''; return; }

    var results;
    try { results = idx.search(q + '*'); } catch(e) { results = []; }

    if (!results.length) {
      el.innerHTML = '<p>Nema rezultata za <strong>' + escHtml(q) + '</strong>.</p>';
      return;
    }

    var map = {};
    docs.forEach(function(d) { map[d.url] = d; });

    el.innerHTML = '<p>' + results.length + ' rezultat(a):</p><ul style="list-style:none;padding:0">' +
      results.map(function(r) {
        var d = map[r.ref];
        var stock = (d.srbobran || 0) + (d.futog || 0);
        var stockHtml = stock > 0
          ? '<span style="color:#27ae60">&#9679; Na stanju</span>'
          : '<span style="color:#ccc">&#9679; Nije na stanju</span>';
        var imgHtml = d.image
          ? '<img src="' + escHtml(d.image) + '" style="width:56px;height:56px;object-fit:cover;border-radius:4px;flex-shrink:0">'
          : '<div style="width:56px;height:56px;background:#f0f0f0;border-radius:4px;flex-shrink:0"></div>';
        var priceHtml = d.price ? '<strong>' + Math.round(d.price) + ' din.</strong>' : '';
        return '<li style="display:flex;gap:0.75rem;align-items:center;padding:0.6rem 0;border-bottom:1px solid #eee">' +
          '<a href="' + escHtml(d.url) + '">' + imgHtml + '</a>' +
          '<div>' +
            '<a href="' + escHtml(d.url) + '" style="font-size:1rem;font-weight:bold;display:block">' + escHtml(d.title) + '</a>' +
            '<small style="color:#888">šifra ' + escHtml(String(d.sku)) + ' &mdash; ' + escHtml(d.collection) + '</small><br>' +
            priceHtml + ' ' + stockHtml +
          '</div>' +
          '</li>';
      }).join('') + '</ul>';
  }

  function escHtml(s) {
    return String(s).replace(/[&<>"']/g, function(c) {
      return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];
    });
  }
</script>
