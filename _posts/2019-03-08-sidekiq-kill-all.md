---
title: Sidekiq kill all from ruby console
tags: [sidekiq]
---

This clears all jobs from all sidekiq queues.

```ruby
Sidekiq::Queue.all.each(&:clear)
Sidekiq::RetrySet.new.clear
Sidekiq::ScheduledSet.new.clear
Sidekiq::DeadSet.new.clear
```
