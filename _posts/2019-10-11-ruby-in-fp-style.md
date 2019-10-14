---
title: Ruby in FP style
tags: [ruby]
published: false
---

Some fun way of coding Ruby in FP style.

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
