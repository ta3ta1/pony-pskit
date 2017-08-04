use "files"
use ".."
use @_cwait[I64](
  exitcode: Pointer[I32] tag, handle: I64, action: I32) if windows
use @_wspawnvp[I64](
  mode: I32,
  file: Pointer[U8] tag,
  args: Pointer[Pointer[U8] tag] tag) if windows
use @_wspawnvpe[I64](
  mode: I32,
  file: Pointer[U8] tag,
  args: Pointer[Pointer[U8] tag] tag,
  vars: Pointer[Pointer[U8] tag] tag) if windows
use @posix_spawnp[I32](
  pid: Pointer[I32] tag,
  file: Pointer[U8] tag,
  actions: Pointer[U8] tag,
  attr: Pointer[U8] tag,
  args: Pointer[Pointer[U8] tag] tag,
  vars: Pointer[Pointer[U8] tag] tag) if posix
use @waitpid[I32](pid: I32, wstatus: Pointer[I32] tag, options: I32) if posix
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

class PSKitSpawn
  new create(
    auth: AmbientAuth,
    notify': PSKitSpawnNotify iso,
    file': String,
    args': (Seq[String] val | None) = None,
    vars': (Seq[String] val | None) = None) ?
  =>
    let file =
      match sanitize_command_name(file')
      | let seq: ByteSeq => seq
      else
        error
      end

    let args =
      match args'
      | None => None // no arg
      | let seq: Seq[String] val =>
        match sanitize_seq(seq)
        | let sseq: Seq[ByteSeq] val =>
          sseq
        else
          error
        end
      end

    let vars =
      match vars'
      | None => None // no vars
      | let seq: Seq[String] val =>
        match sanitize_seq(seq)
        | let sseq: Seq[ByteSeq] val =>
          sseq
        else
          error
        end
      end

    _PSKitSpawn(consume notify', file, args, vars)

  fun sanitize_command_name(file: String): (ByteSeq | None) =>
    let out = Path.clean(file)
    if out == "." then
      None
    else
      try
        OSString.from(out)?
      else
        None
      end
    end

  fun sanitize_seq(arr: Seq[String] val): (Seq[ByteSeq] val | None) =>
    recover
      var out = Array[ByteSeq](arr.size())
      for e in arr.values() do
        if e.size() == 0 then continue end // TODO: error?

        try
          out.push(OSString.from(e)?)
        else
          return None
        end
      end
      consume out
    end

actor _PSKitSpawn
  let notify: PSKitSpawnNotify iso

  new create(
    notify': PSKitSpawnNotify iso,
    file': ByteSeq,
    args': (Seq[ByteSeq] val | None) = None,
    vars': (Seq[ByteSeq] val | None) = None)
  =>
    notify = consume notify'

    let file = file'
    let nullptr = Pointer[U8]

    // prepare args
    let args = Array[Pointer[U8] tag](2)
    args.push(file.cpointer())
    match args'
    | let seq: Seq[ByteSeq] val =>
      for arg in seq.values() do
        args.push(arg.cpointer())
      end
    end
    args.push(nullptr)

    // prepare env vars
    let vars = Array[Pointer[U8] tag](1)
    match vars'
    | let seq: Seq[ByteSeq] val =>
      for var1 in seq.values() do
        vars.push(var1.cpointer())
      end
    end
    vars.push(nullptr)

    // spawn
    ifdef windows then
      let mode = I32(1) // _P_NOWAIT
      let ret_spawn =
        if vars.size() > 1 then
          @_wspawnvpe(
            mode, file.cpointer(), args.cpointer(), vars.cpointer())
        else
          @_wspawnvp(
            mode, file.cpointer(), args.cpointer())
        end
      if ret_spawn == -1 then
        let errno = @pony_os_errno()
        notify.not_opened(errno)
        return
      end

      notify.opened()

      _wait(ret_spawn)
    elseif posix then
      var pid: I32 = -1
      let ret_spawn =
        if vars.size() > 1 then
          @posix_spawnp(
            addressof pid, file.cpointer(),
            nullptr, nullptr,
            args.cpointer(), vars.cpointer())
        else
          let nullptrptr: Pointer[Pointer[U8] tag] tag =
            Pointer[Pointer[U8] tag]
          @posix_spawnp(
            addressof pid, file.cpointer(),
            nullptr, nullptr,
            args.cpointer(), nullptrptr)
        end
      if ret_spawn != 0 then
        notify.not_opened(ret_spawn)
        return
      end

      notify.opened()

      _wait(pid.i64())
    else
      compile_error "unsupported platform"
    end

  fun _extract_exitcode(wstatus: I32): I32 ? =>
    if (wstatus and 0x7f) == 0 then
      (wstatus >> 8) and 0xff
    else
      error
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
    elseif posix then
      var wstatus: I32 = 0
      let ret_waitpid = @waitpid(pid.i32(), addressof wstatus, 0)
      if ret_waitpid == -1 then
        notify.abended(@pony_os_errno())
      else
        try
          let exitcode = _extract_exitcode(wstatus)?
          notify.finished(exitcode)
        else
          notify.abended(4) // roughly pass EINTR
        end
      end
    else
      compile_error "unsupported platform"
    end
