import streams, strformat

type
    Rgb* = tuple[r: uint8, g: uint8, b: uint8]
    TargaImg = object
        header: array[18, uint8]
        pixels: seq[Rgb]
    PpmImg = object
        lines: seq[string]
    Writeable* = concept w
        var s: Stream
        s.write(w)

template writeTo*(w: Writeable, fileName: string) =
    let file = newFileStream(fileName, FileMode.fmReadWrite)
    file.write(w)
    file.flush()
    file.close()

#TOOD: access rgb data directly
template toOpenArray*(rgb: Rgb) : openArray[uint8] = toOpenArray([rgb[0], rgb[1], rgb[2]], 0, 2)

iterator ritems*[T](a: seq[T]): T {.inline.} =
  ## Iterates over each item of `a` backwards
  var i = len(a)
  let L = len(a)
  while i > 0:
    dec(i)
    yield a[i]
    assert(len(a) == L, "the length of the seq changed while iterating over it")

proc clear*[T](seq: var seq[T]) =
    seq.setLen(0)

proc newTarga*(width: int32, height: int32, pixels: seq[Rgb]) : TargaImg =
    var tga = TargaImg()
    tga.header[2] = 2
    tga.header[12] = uint8(255 and width)
    tga.header[13] = uint8(255 and (width shr 8))
    tga.header[14] = uint8(255 and height)
    tga.header[15] = uint8(255 and (height shr 8))
    tga.header[16] = 24u8
    #tga.header[17] = 32u8

    var row = newSeq[Rgb]()
    #from botton to up
    for pixel in pixels.ritems:
        row.add(pixel)
        if row.len < width:
            continue
        #"unreverse" row
        for pixel2 in row.ritems:
            tga.pixels.add pixel2
        row.clear()
    return tga

proc newPpm*(width: int32, height: int32, pixels: seq[Rgb]) : PpmImg =
    var ppm = PpmImg()
    ppm.lines.add "P3"
    ppm.lines.add fmt"{width} {height}"
    ppm.lines.add "255"

    for pixel in pixels:
        ppm.lines.add fmt"{pixel[0]} {pixel[1]} {pixel[2]}"
    return ppm

proc write*(strm: Stream, tga: TargaImg) =
    strm.write(tga.header)
    #targa is BGR not RGB
    for pixel in tga.pixels:
        strm.write(pixel.b)
        strm.write(pixel.g)
        strm.write(pixel.r)

proc write*(strm: Stream, ppm: PpmImg) =
    for line in ppm.lines:
        strm.writeLine(line)
