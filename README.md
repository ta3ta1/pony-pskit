# pony-pskit

Work in progress...

Currently it provides following package and only work for windows.

### package `pskit/spawn`

```pony
use "../pskit/spawn"

class Notify is PSKitSpawnNotify
  let out: OutStream

  new iso create(out': OutStream) =>
    out = out'

  fun opened() =>
    None

  fun not_opened(errno: I32) =>
    out.print(strerror(errno))

  fun finished(exitcode: I32) =>
    out.print("finished: " + exitcode.string())

  fun abended(errno: I32) =>
    out.print(strerror(errno))

actor Main
  new create(env: Env) =>
    let auth = try
      env.root as AmbientAuth
    else
      env.err.print("no auth")
      return
    end

    PSKitSpawn(
      auth,
      TestNotify(env.out),
      "git", // command
      recover ["--version"] end, // arg
      recover ["GIT_PAGER=vim"] end // env vars
    )
```

#### How to run tests

You can use `mk.bat`.

    > mk stub

then

    > mk test

or

    > mk test seq

to let test cases run sequentially.