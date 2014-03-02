# lnpoc

A typical database backed web application does this on each request:

1. query database
1. instantiate objects from results
1. produce html
1. throw all the objects away

This strong isolation between requests is great - it allows for sane
development without having to fear that requests interfere with each
other, and makes sure the data is always up to date.  However, it does
seem wasteful when the same data is used for display in each request
over and over, and when the number of reads is significantly larger
than the number of writes - a scenario that is not untypical for many
web applications.

The common strategy to improve efficiency in this scenario is to cache
the full or partial html output. Which is often ok, but has its
downsides.

This app experiments with another approach: multiple web server
threads share read access to a ruby object, and postgresql's
LISTEN/NOTIFY is used to keep it up to date.

The example used in this app is chosen to fit that scenario: it
displays a current highscore list, which is kept in memory (in the
top-level variable `highscore`, but could be a `Repository` or
something like that in a non-example app).  The table in the view has
an additional column called "Difference to mine", which shows a
dynamically calculated value based on the query parameter `mine`, when
present.  This illustrates a case where caching html output is not
feasible.

On each write to the scores table, which the highscore is based on, a
database trigger sends a NOTIFY. The web server uses multithreaded
puma, and there is one additional thread which listens for
notifications, and refreshes the shared highscore object when
necessary.

You can see the app in action on heroku: http://lnpoc.herokuapp.com/

Of course, doing something like this only makes sense when the
following is true:

- the shared ruby objects fully fit into memory
- the shared ruby objects are strictly used read only by the web
  threads

Also, when there are more pre-instantiated objects with dependencies
on each other, it would be necessary to come up with a way that the
objects are updated atomically at once, and maybe in such a way that
changes become only visible for a web thread at the beginning of a
request, not in the middle of processing. Maybe this could be achieved
by using a centralized repository, and having the web threads get a
reference to a specific version of it at the beginning of the request.

Concurrent programming is hard and there are propably a gazillion of
reasons why this could fail.  Nevertheless, I think the approach in
general is worth exploring, because for some apps it could mean a
significant performance and scalability gain.  Directly, because less
database queries are made, but also indirectly, because less
query-specific optimization of the datamodel would be necessary.

I'd be happy to hear your feedback.


## Notes / TODO

- as mentioned above, maybe make sure changes are effective only at
  the beginning of a request

- when multiple notifications queue up, e.g. because of a batch
  update, only one update should be performed (something like a unique
  queue?)

- a way to monitor memory usage

- a way to include in the payload what exactly has changed. Not useful
  for the Highscore example, but when caching some kind if IdentityMap


(btw., lnpoc stands for LISTEN/NOTIFY proof of concept)
