---
title: Working with monads in plain ruby way
tags: [ruby]
published: false
---

Monads are a great way to handle complex responses from service objects without dealing with nils and exception
propagation. They are not a new concept to ruby, because many services apply monad pattern for returning values,
however ruby don't have any native way of working with them (unlike more FP languages) and many devs don't even know
that they are using monads. So....

## Quick recap - what are monads?

In a very simplified case, monad can be understood as a simple wrapper over data with resulted state, something like:

```ruby
{
  result: (:success || :failure || ...some other state...),
  data: ...whatever...
}
```

And because of this, it can be safely returned nil, exception or other state **inside the object itself**. But why they
are useful in ruby? Lets try to code something...

### Ruby example w/o monads

Lets have several service objects (`AService`, `BService`, `CService`) that can return:

- some created/found object as successful result
- `nil` as unsuccessful result (and no special message)
- raise error with message if needed to propagate message to parent

I'm a bit simplifying here, because there can be other ways of coding such logic, but IMO this is quite a common
way of doing things in ruby. And some service that utilize results of those simple services:

```ruby
class ComplexService
  def call(input)
    result_a = AService.call(input)
    return :a_not_ok unless result_a

    result_b = BService.call(result_a)
    return :b_not_ok unless result_b

    result_c = CService.call(result_a, result_b)
    return :c_not_ok unless result_c

    result_c
  rescue errors_a
    ...
  rescue errors_b
    ...
  rescue errors_c
    ...
  end
end
```

This looks bulletproof production code - we care about all results (in a respected manner) and deal with all errors.
Lot of things to code, lot of things not to forget.

### Imaginary monads way

But what if we can ask those simple service objects to always return **something valid and never raise error**?
This is where monads become handy.

```ruby
class SimpleService
  def call
    Success(result, metadata, etc) || Failure(errors, messages, etc)
  end
end
```

I will furhter use `dry-monads` from `dry-rb` gems (which is a top-notch lib, kinda next gen ruby in many senses).
But essentially, after removing all nice sugar, dry-rb's `Result` monad is just a following PORO:

```ruby
class Success
  def initialize(result)
    @result = result
  end

  def success # value itself
    result
  end

  def success?
    true
  end

  def failure?
    false
  end
end

res = Success.new("result")  # in dry-monads it is sugared to Success("result")
res.success?                 # true
res.failure?                 # false
res.success                  # "result" - the data
```

But what about `ComplexService` that works with monad returning services?
It needs to implement following logic: a) `AService` b) if ok, then `BService`
c) if ok, then `CService` (with covering all exceptional cases). In FP languages that may be done with
some native language operators, e.g. something like (such a process is called "binding"):

```
AService >> BService >> CService
```

But is it at all possible same easy way in ruby? Ruby doesn't have those Haskell style operators (and most probably
will never have in near or distant future). And this is where all the problems start happening....

## Binding result of several monads

### Basic way with `bind`

Surely the problem is not new, and at least gem's creators most probably have thought about it. Let's check:

```ruby
class ComplexService
  def call(input)
    AService.call(input).bind { |result_a|
      BService.call(result_a).bind { |result_b|
        CService.call(result_a, result_b)
      }
    }
  end
end
```

Doesn't looks cool and scalable :disappointed: Who want to write such monsters?

### DO notation with implicit `bind` and yielding

There is also new alternate way at least for `dry-monads`, named "DO notation".

```ruby
class ComplexService
  def call(input)
    result_a = yield AService.call(input)
    result_b = yield BService.call(result_a)
    CService.call(result_a, result_b)
  end
end
```

Much better looking from style perspective, but:

- this comes with a catch - you need to `include Dry::Monads::Do.for(:call)` which under the hood wraps your
  `call` method with special logic for yielding blocks.
- `yield`'ing doesn't look that pretty, yes they are ruby syntax, but it is overall harder to read vs normal code.
  Plus you should not forget that last call is w/o `yield`

### `dry-transaction` way

This is a "real" solution to the problem with multiple tweaks. It may look something like this

```ruby
class ComplexService < AppTransaction           # base class derivered from Dry::Transaction
  step :step_a
  step :step_b, with: :previously_registed_b    # this is how re-using of steps looks
  step :step_c

  private

  def step_a(input)
    AService.call(input)
  end

  def step_c(input)
    CService.call(input)
  end
```

But, but, but - this is a one more new DSL. Yes it is easy to understand, but it requires learning to read the code
and even more to write code correctly. There is an implicit `call` here which is bad overall. For logic flow
it may possibly needs to implement some `if:` predictes (like in rails). It is hard to pass params inside `step` -
you always need a private method. And so on and on....

This may be a good way for a sole developer or a team that fully adopts this concept, but is hard in more ordinary
rails-oriented teams, where there is different level of devs and different ways of doing things.

_So can it be more rubyish, more averagly native ways?_

_Something that ordinary dev can read, understand and fix, without reading much docs._

_And possibly with that cool Haskell `>>`?_

_And possibly with straightforward code without metaprogramming, operator overloading, etc...._

Looks like mission impossible... but why not try?

## Ruby native way

After some thinking, it is understood that what is needed here is a generator that have possibility to exit on step's
failure. Unfortunatelly generators are not a very natural pattern for ruby either, but we have `Enumerator`.
`Enumerator` can lazily loop through a collection in a generator style. And it does it naturally from
standard lib exactly with `>>` operator :smile:

```ruby
Enumerator.new do |yielder|
  yielder.yield value1        # this is `yield` method of `yielder`, not a `yield` block
  yielder << value2           # this is alias to `yielder.yield`
end
```

That maybe coded for monads chaining as (with implicit context):

```ruby
def bind_result_monads(&block)
  Enumerator.new(&block).reduce(nil) do |_, monad|
    monad.success? ? monad : (break monad)
  end
end
```

and a bit more complex variant (with explicit context) as:

```ruby
def bind_result_monads(context)
  Enumerator.new { |yielder| yield(yielder, context) }.reduce(nil) do |_, monad|
    context = monad.success || monad.failure
    monad.success? ? monad : (break monad)
  end
end
```

And a service using this as:

```ruby
class ComplexService
  # with explicit context
  def call(input)
    bind_result_monads(input) do |result, input|
      result.yield AService.call(input)             # just for completeness, I like `<<` more
      result << BService.call(input)
      result << CService.call(input)
    end
  end

  # with implicit context
  attr_accesor :context
  def call
    bind_result_monads do |result|
      result << AService.call(context)
      result << BService.call(context)
      result << CService.call(context)
    end
  end

  # in a chainable way
  def call
    bind_result_monads do |result|
      result << AService.call(context) << BService.call(context) << CService.call(context)
    end
  end

  # if we made our helper method a bit smarter to `.call(context)` - this is now totally Ruby-Haskell looking
  def call
    bind_result_monads do |result|
      result << AService << BService << CService
    end
  end

  # and symbols - those may be used for re-using of previously registered common operations
  def call
    bind_result_monads do |result|
      result << AService << :b_service << :c_service
    end
  end

  # and with some flow controls or lambdas or whatever - just need to properly handle those by type
  def call
    bind_result_monads do |result|
      result << AService
      result << :b_service unless skip_b_service?
      result << CService while context.need_one_more?
      result << -> { ... }
    end
  end
end
```

Practically, I have used this only with `Result` monads, but don't see why it will not work with other types of monads.
And possibly even other bindings, however this may require adding additional methods to enumerator object that we have
created, but this is also more straightforward vs metaprogramming:

```ruby
# just a possible example of other logical bindings
bind_monads do |result|
  result.bind(a)         # actually a synonym to plain result.yield(a)
  result.either(b, c)    # smth like (b.success? && b) || (c.success? && c) || Failure(b, c)
end
```

## Real life example

In real life, this monads helper (in its current implementation) is just as following:

```ruby
module ResultChain
  include Dry::Monads

  private

  def result_chain(&block)
    Enumerator.new(&block).reduce(nil) do |_, result|
      result = call_resolved_operation(result) if result.is_a?(Symbol)
      result.success? ? result : (break result)
    end
  end

  def call_resolved_operation(operation)
    AppOperationsContainer.resolve(operation).call(context)
  end
end
```

It accepts for input `Result` monad from `dry-monads` or a symbol (which means registered operation).
Other input types seems unnecessary at the moment, but could be easily added.
As well it is designed with common context in mind (see further) a-la Trailblazer style.

Real life service object that utilizes `ResultChain`:

```ruby
class CreateQuote
  include ResultChain                                       # just a mixin include

  method_object :context, [skip_fetch: false]               # implicit context and a param

  def call
    result_chain do |chain|                                 # result_chain always returns either Success(context)
      chain << init                                         # or Failure(context) with errors included if any
      chain << :build_model
      chain << :check_policy
      chain << :validate_contract
      chain << :persist_contract
      chain << schedule_background_fetch unless skip_fetch  # flow control
    end
  end

  private

  def init
    context[:model_class] = Quote
    context[:contract] = Quote::Contracts::Create
    Success(context)
  end

  def schedule_background_fetch
    FetchQuoteJob.perform_later(context.fetch(:model).id)
    Success(context)
  end
end
```
