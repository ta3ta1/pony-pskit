use "files"
use @_cwait[I64](
  exitcode: Pointer[I32] tag, handle: I64, action: I32) if windows
use @_spawnvp[I64](
  mode: I32,
  file: Pointer[U8] tag,
  args: Pointer[Pointer[U8] tag] tag) if windows
use @_spawnvpe[I64](
  mode: I32,
  file: Pointer[U8] tag,
  args: Pointer[Pointer[U8] tag] tag,
  vars: Pointer[Pointer[U8] tag] tag) if windows
use @pony_os_errno[I32]()

interface PSKitSpawnNotify
  fun ref opened() => None
  fun ref not_opened(errno: I32) => None
  fun ref finished(exitcode: I32) => None
  fun ref abended(errno: I32) => None
  fun strerror(errno: I32, code: Bool = true): String =>
    recover
      let p = @strerror[Pointer[U8]](errno)
      let s = String.from_cstring(p)
      if code then
        s + "(" + errno.string() + ")"
      else
        s
      end
    end

actor PSKitSpawn
  let notify: PSKitSpawnNotify iso

  new create(
    auth: AmbientAuth,
    notify': PSKitSpawnNotify iso,
    file': String,
    args': (Seq[String] val | None) = None,
    vars': (Seq[String] val | None) = None
  ) =>
    notify = consume notify'

    let file = file'
    let nullptr = Pointer[U8]

    // prepare args
    let args = Array[Pointer[U8] tag](2)
    args.push(file.cstring())
    match args'
    | let seq: Seq[String] val =>
      for arg in seq.values() do
        args.push(arg.cstring())
      end
    end
    args.push(nullptr)

    // prepare env vars
    let vars = Array[Pointer[U8] tag](1)
    match vars'
    | let seq: Seq[String] val =>
      for var1 in seq.values() do
        vars.push(var1.cstring())
      end
    end
    vars.push(nullptr)

    ifdef windows then
      let mode = I32(1) // _P_NOWAIT
      let ret_spawn =
        if vars.size() > 1 then
          @_spawnvpe(
            mode, file.cstring(), args.cpointer(), vars.cpointer())
        else
          @_spawnvp(
            mode, file.cstring(), args.cpointer())
        end
      if ret_spawn == -1 then
        let errno = @pony_os_errno()
        notify.not_opened(errno)
        return
      end

      notify.opened()

      _wait(ret_spawn)
    else
      compile_error "unsupported platform"
    end

  be _wait(pid: I64) =>
    ifdef windows then
      var exitcode: I32 = -1
      let ret_cwait = @_cwait(addressof exitcode, pid, 0)
      if ret_cwait == -1 then
        notify.abended(@pony_os_errno())
      else
        notify.finished(exitcode)
      end
    else
      compile_error "unsupported platform"
    end
