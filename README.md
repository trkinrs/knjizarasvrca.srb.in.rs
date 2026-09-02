# Knjizara Svrca

Da bi se dobilo na brzini, ne koristiti `where` ili `find` vec hash iz
`_plugins/posts_by_sifra.rb`

```
umesto
+    {% assign product = site.komision | where: "sku", book.sifra | first %}
 
koristiti
{% assign product = site.posts_by_sifra[book.sifra] %}
```
