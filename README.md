# pony-pskit

Work in progress...

Currently it provides following package.

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

    PSKitSpawn(auth, TestNotify(env.out), "git", recover ["--version"] end)
```
