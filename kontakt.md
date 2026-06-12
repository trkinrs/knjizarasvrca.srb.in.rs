---
layout: page
title: Kontakt
permalink: /kontakt/
---

<style>
  .kontakt-table {
    border-collapse: collapse;
    width: 100%;
    max-width: 700px;
    font-size: 0.95rem;
  }
  .kontakt-table tr {
    background-color: #fff;
  }
  .kontakt-table td {
    padding: 0.6rem 0.75rem;
    vertical-align: middle;
    border-bottom: 1px solid #eee;
  }
  .kontakt-table td:first-child {
    min-width: 250px;
    color: #666;
    font-size: 0.85rem;
  }
  @media (max-width: 600px) {
    .kontakt-table td {
      display: block;
      padding: 0.3rem 0.5rem;
    }
    .kontakt-table td:first-child {
      min-width: unset;
      padding-top: 0.75rem;
      padding-bottom: 0;
      border-bottom: none;
    }
    .kontakt-table tr:first-child td:first-child {
      padding-top: 0.5rem;
    }
  }
  .kontakt-table .cell-value {
    display: flex;
    align-items: center;
    gap: 0.6rem;
  }
  .btn-copy {
    flex-shrink: 0;
    background: #f0f0f0;
    border: 1px solid #ccc;
    border-radius: 4px;
    padding: 0.2rem 0.6rem;
    font-size: 0.78rem;
    cursor: pointer;
    color: #444;
    transition: background 0.15s, color 0.15s, opacity 0.15s;
    opacity: 0;
  }
  tr:hover .btn-copy {
    opacity: 1;
  }
  .btn-copy:hover {
    background: #e0e0e0;
  }
  .btn-copy.copied {
    background: #27ae60;
    color: #fff;
    border-color: #27ae60;
    opacity: 1;
  }
</style>

<table class="kontakt-table">
  <tbody>
    <tr>
      <td>Poslovno ime (name):</td>
      <td><div class="cell-value">
        <span class="copy-source">ŠVRĆA DRUŠTVO SA OGRANIČENOM ODGOVORNOŠĆU ZA PROMET ROBA SRBOBRAN</span>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
    <tr>
      <td>Skraćeno poslovno ime (short name):</td>
      <td><div class="cell-value">
        <span class="copy-source">Švrća</span>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
    <tr>
      <td>Matični broj (corporate ID):</td>
      <td><div class="cell-value">
        <span class="copy-source">08283028</span>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
    <tr>
      <td>PIB (tax ID):</td>
      <td><div class="cell-value">
        <span class="copy-source">101425778</span>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
    <tr>
      <td>Račun u banci (bank account):</td>
      <td><div class="cell-value">
        <span class="copy-source">265-2050310003018-19</span>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
    <tr>
      <td>Poslovno sedište (address):</td>
      <td><div class="cell-value">
        <span class="copy-source">Trg Republike 1</span>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
    <tr>
      <td>Poštanski broj, grad (zip, city):</td>
      <td><div class="cell-value">
        <span class="copy-source">21480 Srbobran</span>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
    <tr>
      <td>Imejl (email):</td>
      <td><div class="cell-value">
        <span class="copy-source">knjizarasvrca@gmail.com</span>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
    <tr>
      <td>Mobilni (mobile):</td>
      <td><div class="cell-value">
        <a href="tel:063603018"><span class="copy-source">063/603-018</span></a>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
  </tbody>
</table>

## Prodavnica Futog

<table class="kontakt-table">
  <tbody>
    <tr>
      <td>Adresa:</td>
      <td><div class="cell-value">
        <span class="copy-source">Cara Lazara 18, Futog</span>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
    <tr>
      <td>Mobilni:</td>
      <td><div class="cell-value">
        <a href="tel:+381606259699"><span class="copy-source">060/625-9699</span></a>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
    <tr>
      <td>Imejl (email):</td>
      <td><div class="cell-value">
        <span class="copy-source">knjizarasvrcafutog@gmail.com</span>
        <button class="btn-copy" type="button">Copy</button>
      </div></td>
    </tr>
  </tbody>
</table>

[O nama](/about/)

<script>
  document.querySelectorAll('.btn-copy').forEach(function(btn) {
    btn.addEventListener('click', function() {
      var text = btn.closest('.cell-value').querySelector('.copy-source').textContent.trim();
      navigator.clipboard.writeText(text).then(function() {
        btn.textContent = 'Copied!';
        btn.classList.add('copied');
        setTimeout(function() {
          btn.textContent = 'Copy';
          btn.classList.remove('copied');
        }, 1800);
      });
    });
  });
</script>
