---
layout: page
title: Škole
permalink: /schools/
---

<ul>
  {% assign schools = site.schools | sort: "title" %}
  {% for school in schools %}
    <li><a href="{{ school.url | relative_url }}">{{ school.title }}</a></li>
  {% endfor %}
</ul>
