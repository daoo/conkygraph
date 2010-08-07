-- This work is licensed under the Creative Commons Attribution 3.0 Unported License. To view a copy of this license, visit http://creativecommons.org/licenses/by/3.0/ or send a letter to Creative Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.

function antialias( cr, antialias )
  require( "cairo" )

  if antialias then
    cairo_set_antialias( cr, CAIRO_ANTIALIAS_DEFAULT )
  else
    cairo_set_antialias( cr, CAIRO_ANTIALIAS_NONE )
  end
end

function rgb_to_r_g_b( color, alpha )
  local c = tonumber( "0x" .. color )

  return ( ( c / 0x10000 ) % 0x100 ) / 255.0, ( ( c / 0x100 ) % 0x100 ) / 255.0, ( c % 0x100 ) / 255.0, alpha
end

function cairo_graph( cr, x, y, width, height, f )
  require( "cairo" )

  local function value_to_y( height, value )
    if height ~= nil and value ~= nil then
      return height * ( 1 - value )
    end

    return 0
  end

  if f.data ~= nil and #f.data > 0 then
    local x2 = x + width
    local nx = x2

    cairo_move_to( cr, x2, y + value_to_y( height, f.data[1] ) )

    -- Drawn from right to left
    local curve_to = cairo_line_to
    for i, v in pairs( f.data ) do
      nx = nx - f.dx

      if nx >= x then
        curve_to( cr, nx, y + value_to_y( height, v ) )
      else
        break
      end
    end

    antialias( cr, f.antialias )
    cairo_set_source_rgba( cr, rgb_to_r_g_b( f.stroke_color, 1 ) )
    cairo_set_line_width( cr, f.stroke_width )

    if f.fill then
      cairo_stroke_preserve( cr )

      cairo_line_to( cr, nx, y + height )
      cairo_line_to( cr, x2, y + height )
      cairo_close_path( cr )
      cairo_set_source_rgba( cr, rgb_to_r_g_b( f.fill_color, f.fill_alpha ) )
      cairo_fill( cr )
    else
      cairo_stroke( cr )
    end
  end
end
------------------------------------------------------------------------------------------------------------------------
function draw_graph( cr, x, y, width, height, graph )
  if conky_window == nil or graph == nil then
    return
  end

  local function push( t, v, c )
    while #t > c do
      table.remove( t, #t )
    end

    table.insert( t, 1, v )
  end

  -- Find margins, sizes and positions
  local x_outer = tonumber( x ) + conky_window.text_start_x
  local y_outer = tonumber( y ) + conky_window.text_start_y

  local w_outer = tonumber( width )
  if w_outer == 0 then
    w_outer = conky_window.text_width - x
  end
  local h_outer = tonumber( height )
  if h_outer == 0 then
    h_outer = conky_window.text_height - y
  end

  local x_inner = x_outer
  local y_inner = y_inner
  local w_inner = w_outer
  local h_inner = h_outer
  if graph.outline then
    local o = graph.outline_width
    x_inner = x_outer + o
    y_inner = y_outer + o

    local o2 = o * 2
    w_inner = w_outer - o2
    h_inner = h_outer - o2
  end

  require( "cairo" )

  cairo_rectangle( cr, x_inner, y_inner, w_inner, h_inner )
  cairo_clip( cr )

  for i, f in pairs( graph.functions ) do
    if f.data == nil then
      f.data = {}
    end

    local pixels_per_value = w_inner / f.dx

    local str = conky_parse( f.conky_variable )
    local val = tonumber( str )

    if val ~= nil then
      if f.record_max then
        if val > f.max_value then
          f.max_value = val
        else
          for i, v in pairs( f.data ) do
            if v > f.max_value then
              f.max_value = v
            end
          end
        end
      end

      push( f.data, val / f.max_value, pixels_per_value )
    end

    cairo_graph( cr, x_inner, y_inner, w_inner, h_inner, f )
  end

  cairo_reset_clip( cr )

  if graph.outline then
    cairo_set_source_rgba( cr, rgb_to_r_g_b( graph.outline_color, graph.outline_alpha ) )
    cairo_rectangle( cr, x_outer, y_outer, w_outer, h_outer )
    antialias( cr, graph.outline_antialias )
    cairo_set_line_width( cr, graph.outline_width )
    cairo_stroke( cr )
  end
end

function conky_load_graphs( file )
  function json_decode_file( file )
    local json = require( "json" )

    local t = {}
    for line in io.lines( file ) do
      t[#t + 1] = line
    end
    local str = table.concat( t, "\n" )

    return json.decode( str )
  end

  local lfs = require( "lfs" )

  mod_time = lfs.attributes( file, "modification" )
  graphs_file = file
  graphs = json_decode_file( file )
end

function is_file_dirty( file )
  local lfs = require( "lfs" )

  local tmp = lfs.attributes( file, "modification" )
  if tmp ~= mod_time then
    mod_time = tmp
    return true
  end

  return false
end

function conky_draw_graphs()
  if conky_window == nil then
    return
  end

  if is_file_dirty( graphs_file ) then
    print( "Reloading " .. graphs_file .. "..." )
    conky_load_graphs( graphs_file )
  end

  if graphs == nil then
    return
  end

  require( "cairo" )

  local cs = cairo_xlib_surface_create( conky_window.display, conky_window.drawable, conky_window.visual,
                                        conky_window.width, conky_window.height )
  local cr = cairo_create( cs )

  cairo_set_line_join( cr, CAIRO_LINE_JOIN_ROUND )

  for k, v in pairs( graphs ) do
    draw_graph( cr, v.x, v.y, v.width, v.height, v )
  end

  cairo_destroy( cr )
end
