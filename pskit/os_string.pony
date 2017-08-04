use @MultiByteToWideChar[I32](
  codepage: U32,
  flags: U32,
  mbstr: Pointer[U8] tag,
  mblen: I32,
  wstr: Pointer[U8] tag,
  wlen: I32) if windows

primitive OSString
  fun from(utf8: ByteSeq): ByteSeq ? =>
    ifdef windows then
      // get buffer size
      let size = @MultiByteToWideChar(
        65001, 0, utf8.cpointer(), -1, Pointer[U8], 0)
      if size == 0 then
        error
      end
      // convert
      recover
        let buf = Array[U8] .> undefined(size.usize() * 2)
        let wrote = @MultiByteToWideChar(
          65001, 0, utf8.cpointer(), -1, buf.cpointer(), size)
        if wrote == 0 then
          error
        end
        consume buf
      end
    else
      utf8
    end
