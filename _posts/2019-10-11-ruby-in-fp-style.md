---
title: Fun way of coding ruby in FP style
tags: [ruby]
published: true
---

Normally we think of ruby as OO language, but actually it can be good in "pure" FP as well.
I mean "generally", not "practically", because there is no any multi-threaded infrastructure
to support parallel functions - "normally" ruby still runs as a single process.

But why not to have some fun and think how it may look like if done in Functional Programming way? So... just playing around.

```ruby
require 'faraday'
require 'json'

module Lib
  Map = ->(func, object) { object.map(&func) }.curry
  Prop = ->(property, object) { object[property] }.curry
end

module Impure
  getHTTP = ->(url) { Faraday.get(url).body }
  extractFlickr = ->(body) { body.delete_prefix('jsonFlickrFeed(').delete_suffix(')') }

  GetParsedFlickr = JSON.method(:parse) << extractFlickr << getHTTP
  Trace = Kernel.method(:puts)
end

module App
  host = 'api.flickr.com'
  path = '/services/feeds/photos_public.gne'
  query = ->(t) { "?tags=#{t}&format=json" }
  url = ->(t) { "https://#{host}#{path}#{query[t]}" }

  mediaUrl = Lib::Prop['m'] << Lib::Prop['media']
  mediaUrls = Lib::Map[mediaUrl] << Lib::Prop['items']

  image = ->(src) { "<img src='#{src}' />" }
  images = Lib::Map[image] << mediaUrls
  render = Impure::Trace << images

  App = render << Impure::GetParsedFlickr << url
end

App::App['cats']
```

This works perfectly, but hey... how hard is to read this.


