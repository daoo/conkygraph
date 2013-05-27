function json_decode_file( file )
  local json = require( "json" )

  local str = ""
  for line in io.lines( file ) do
    str = str .. line
  end

  return json.decode( str )
end

function bench( width, height )
  local graphs = json_decode_file( "../graphs.json" )

  require( "cairo" )
  require( "conkygraph" )

  -- HACK
  local j = 0
  for k, v in pairs( graphs ) do
    j = j + 1
  end

  local w = width
  local h = height / j

  local cs = cairo_image_surface_create( cairo.FORMAT_RGB24, width, height )
  local cr = cairo_create( cs )

  cairo.set_source_rgb( cr, 1, 1, 1 )
  cairo.paint( cr )

  -- Fill with random data
  for k1, v in pairs( graphs ) do
    for k2, f in pairs( v.functions ) do
      local d = width / f.dx
      f.data = {}

      for i = 1, d do
        table.insert( f.data, math.sin( i ) )
      end
    end
  end

  local start = os.clock()

  local i = 0
  for k1, g in pairs( graphs ) do
    for k2, f in pairs( g.functions ) do
      cairo_graph( cr, 0, i * h, w, h, f )
    end

    i = i + 1
  end

  print( "Time: " .. os.clock() - start )

  cairo.surface_write_to_png( cs, "bench.png" )
end

bench( 1280, 1024 )
