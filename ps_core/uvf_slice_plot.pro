pro uvf_slice_plot, slice_savefile, multi_pos = multi_pos, start_multi_params = start_multi_params, plot_xrange = plot_xrange, $
                    plot_yrange = plot_yrange, data_range = data_range, type = type, pub = pub, plotfile = plotfile, $
                    window_num = window_num, title = title, grey_scale = grey_scale, baseline_axis = baseline_axis, hinv = hinv, $
                    mark_0 = mark_0, image_space = image_space, color_0amp = color_0amp, charsize = charsize_in, $
                    cb_size = cb_size_in, margin = margin_in, cb_margin = cb_margin_in, no_title = no_title

  if n_elements(window_num) eq 0 then window_num = 1

  if n_elements(start_multi_params) gt 0 and n_elements(multi_pos) gt 0 then message, 'If start_multi_params are passed, ' + $
     'multi_pos cannot be passed because then it is used as an output to pass back the positions for future plots.'

  if n_elements(multi_pos) gt 0 then begin
     if n_elements(multi_pos) ne 4 then message, 'multi_pos must be a 4 element plot position vector'
     if max(multi_pos) gt 1 or min(multi_pos) lt 0 then message, 'multi_pos must be in normalized coordinates (between 0 & 1)'
     if multi_pos[2] le multi_pos[0] or multi_pos[3] le multi_pos[1] then $
        message, 'In multi_pos, x1 must be greater than x0 and y1 must be greater than y0 '
  endif

  type_enum = ['abs', 'phase', 'real', 'imaginary', 'weights']
  if n_elements(type) eq 0 then if keyword_set(image_space) then type = 'real' else type = 'phase'
  wh = where(type_enum eq type, count)
  if count eq 0 then message, 'unknown type. Use one of: ' + type_enum

  if keyword_set(image_space) and keyword_set(baseline_axis) then begin
     print, 'baseline_axis keyword cannot be used with image_space keyword'
     baseline_axis = 0
  endif

  restore, slice_savefile

  dims = size(uvf_slice, /dimension)
  if n_elements(dims) gt 2 then uvf_slice = total(uvf_slice, slice_axis+1) / n_elements(slice_inds)

  if max(abs(uvf_slice)) eq 0 then all_zero = 1

  if keyword_set(image_space) then begin
     old_xarr = xarr
     old_xdelta = xarr[1] - xarr[0]

     xdelta = 1d/(kperp_lambda_conv * dims[0] * old_xdelta)
     xarr = (dindgen(dims[0])-dims[0]/2) * xdelta

     if slice_axis eq 2 then begin
        old_yarr = yarr
        old_ydelta = yarr[1] - yarr[0]
        
        ydelta = 1d/(kperp_lambda_conv * dims[1] * old_ydelta)
        yarr = (dindgen(dims[1])-dims[1]/2) * ydelta

        image = shift(fft(shift(uvf_slice,dims[0]/2,dims[1]/2)),dims[0]/2,dims[1]/2)
     endif else image = shift(fft(shift(uvf_slice,dims[0]/2,0)),dims[0]/2,0)
     old_slice = uvf_slice
     uvf_slice = image

  endif else begin
     if keyword_set(hinv) then begin
        xarr = xarr / hubble_param
        yarr = yarr / hubble_param
     endif

     xdelta = xarr[1] - xarr[0]
     ydelta = yarr[1] - yarr[0]
  endelse

  xarr_edges = [xarr - xdelta/2, max(xarr) + xdelta/2]
  yarr_edges = [yarr - ydelta/2, max(yarr) + ydelta/2]

  if n_elements(plot_xrange) eq 0 then begin
     temp = where(total(abs(uvf_slice),2) gt 0, count)
     if count gt 1 then plot_xrange =  minmax(xarr_edges[[temp, max(temp)+1]]) $
     else plot_xrange = minmax(xarr_edges)
  endif

  if n_elements(plot_yrange) eq 0 then begin
     temp = where(total(abs(uvf_slice),1) gt 0, count)
     
     if count gt 1 then plot_yrange = minmax(yarr_edges[[temp, max(temp)+1]]) $
     else plot_yrange = minmax(yarr_edges)
  endif

  ;; if slice_axis eq 2 then begin
  ;;    plot_xrange = minmax([plot_xrange, plot_yrange])
  ;;    plot_yrange = plot_xrange
  ;; endif

  wh_x_inrange = where(xarr ge plot_xrange[0] and xarr + xdelta le plot_xrange[1], n_x_plot)
  wh_y_inrange = where(yarr ge plot_yrange[0] and yarr + ydelta le plot_yrange[1], n_y_plot)

  if n_x_plot eq 0 or n_y_plot eq 0 then message, 'No data in plot k range'

  if n_x_plot ne n_elements(xarr) then begin
     uvf_slice = uvf_slice[wh_x_inrange, *]
     xarr = xarr[wh_x_inrange]
  endif
  if n_y_plot ne n_elements(yarr) then begin
     uvf_slice = uvf_slice[*, wh_y_inrange]
     yarr = yarr[wh_y_inrange]
  endif

  case type of
     'abs': begin
        plot_slice = abs(uvf_slice)
        cb_title = 'Magnitude'
        plotfile_fadd = '_abs.eps'
     end
     'phase': begin
        plot_slice = atan(uvf_slice, /phase)
        cb_title = 'Phase (degrees)'
        plotfile_fadd = '_phase.eps'
     end
     'real': begin
        plot_slice = real_part(uvf_slice)
        cb_title = 'Real Part'
        plotfile_fadd = '_real.eps'
     end
     'imaginary':  begin
        plot_slice = imaginary(uvf_slice)
        cb_title = 'Imaginary Part'       
        plotfile_fadd = '_imaginary.eps'
     end
     'weights':begin
        if size(uvf_slice, /type) ne 4 and size(uvf_slice, /type) ne 5 then message, 'weights slices must be floats or doubles'
        plot_slice = uvf_slice / max(uvf_slice)
        cb_title = 'Normalized Weights'
        plotfile_add = '.eps'
     end
  endcase

  if n_elements(plotfile) eq 0 then $
     plotfile = strsplit(slice_savefile, '.idlsave', /regex, /extract) + plotfile_fadd $
  else if strcmp(strmid(plotfile, strlen(plotfile)-4), '.eps', /fold_case) eq 0 then plotfile = plotfile + '.eps'
    

  xarr_edges = [xarr - xdelta/2, max(xarr) + xdelta/2]
  yarr_edges = [yarr - ydelta/2, max(yarr) + ydelta/2]

  tvlct, r, g, b, /get

  if keyword_set(grey_scale) then begin
     cgloadct, 0, /reverse
     background_color = 'white'
     annotate_color = 'black'
  endif else begin
     cgloadct, 25, /brewer, /reverse
     background_color = 'white'
     annotate_color = 'black'
  endelse
  n_colors = 256
  
  if n_elements(data_range) eq 0 then if not keyword_set(all_zero) then data_range = minmax(plot_slice) else data_range = [-1*!pi, !pi]

  slice_plot = congrid(plot_slice, n_x_plot*10, n_y_plot * 10)
     
  slice_plot_norm = (slice_plot-data_range[0])*n_colors/(data_range[1]-data_range[0])
 
  tvlct, r2, g2, b2, /get
  plot_dims = size(slice_plot_norm, /dimension)
  slice_plot_norm_rgb = bytarr(3, plot_dims[0], plot_dims[1])
  slice_plot_norm_rgb[0,*,*] = r2[slice_plot_norm]
  slice_plot_norm_rgb[1,*,*] = g2[slice_plot_norm]
  slice_plot_norm_rgb[2,*,*] = b2[slice_plot_norm]

  if keyword_set(color_0amp) then begin
     wh_0amp = where(abs(slice_plot) eq 0, count_0amp)
     if count_0amp ne 0 then begin

        for i=0, 2 do begin
           temp = slice_plot_norm_rgb[i,*,*]
           temp[wh_0amp] = 255
           slice_plot_norm_rgb[i,*,*] = temp
        endfor

     endif
  endif


  max_ysize = 1000
  max_xsize = 1200
  base_size = 600
  if n_elements(multi_pos) eq 4 then begin
     ;; work out positions scaled to the area allowed in multi_pos with proper aspect ratio
     multi_xlen = (multi_pos[2]-multi_pos[0])
     multi_ylen = (multi_pos[3]-multi_pos[1])
     multi_center = [multi_pos[0] + multi_xlen/2d, multi_pos[1] + multi_ylen/2d]

     multi_size = [!d.x_vsize*multi_xlen, !d.y_vsize*multi_ylen]
  endif

  ;; Work out plot & colorbar positions
  ;; in units of plot area (incl. margins)
  if n_elements(cb_size_in) eq 0 then cb_size = 0.025 else cb_size = cb_size_in
  if n_elements(margin_in) lt 4 then begin
     margin = [0.2, 0.15, 0.02, 0.15] 
     if keyword_set(baseline_axis) and not keyword_set(no_title) then margin[3] = 0.22
     if keyword_set(baseline_axis) and slice_axis eq 2 then margin[2] = 0.1
   endif else margin = margin_in

  if n_elements(cb_margin_in) lt 2 then begin
     cb_margin = [0.15, 0.04] 
  endif else cb_margin = cb_margin_in 

  plot_pos = [margin[0], margin[1], (1-cb_margin[1]-cb_size-cb_margin[0]-margin[2]), (1-margin[3])]
  cb_pos = [(1-cb_margin[1]-cb_size), margin[1], (1-cb_margin[1]), (1-margin[3])]

  plot_aspect = (plot_pos[3] - plot_pos[1]) / (plot_pos[2] - plot_pos[0])

  plot_xlength = max(xarr_edges) - min(xarr_edges)
  if slice_axis eq 2 then plot_ylength = (max(yarr_edges) - min(yarr_edges)) $
  else plot_ylength = plot_xlength


  data_aspect = (plot_ylength / plot_xlength)
  aspect_ratio =  data_aspect /plot_aspect
  
  if aspect_ratio gt 1 then begin
     y_factor = 1.
     x_factor = 1/aspect_ratio
  endif else begin

     y_factor = aspect_ratio
     x_factor = 1.
  endelse
  
  if n_elements(multi_pos) eq 4 or n_elements(start_multi_params) gt 0 then begin
     if n_elements(start_multi_params) gt 0 then begin
        ;; calculate desired window size and positions for all plots
        ncol = start_multi_params.ncol
        nrow = start_multi_params.nrow

        multi_pos = fltarr(4, ncol*nrow)
     
        if tag_exist(start_multi_params, 'ordering') eq 0 then ordering = 'row' $
        else ordering = start_multi_params.ordering

        case ordering of
           'col': begin
              ;; col-major values
              col_val = reform(rebin(reform(indgen(ncol), 1, ncol), nrow, ncol), ncol*nrow)
              row_val = reverse(reform(rebin(indgen(nrow), nrow, ncol), ncol*nrow))
           end
           'row': begin
              ;; row-major values
              col_val = reform(rebin(indgen(ncol), ncol, nrow), ncol*nrow)
              row_val = reverse(reform(rebin(reform(indgen(nrow), 1, nrow), ncol, nrow), ncol*nrow))
           end
           else: message, 'unrecognized ordering value in start_multi_params, use "col" or "row" '
        endcase
               
        multi_pos[0,*] = col_val/double(ncol)
        multi_pos[1,*] = row_val/double(nrow)
        multi_pos[2,*] = (col_val+1)/double(ncol)
        multi_pos[3,*] = (row_val+1)/double(nrow)

        ;; define window size based on aspect ratio
        base_size_use = base_size
        xsize = round(base_size * x_factor * ncol)
        ysize = round(base_size * y_factor * nrow)
        while (ysize gt max_ysize) or (xsize gt max_xsize) do begin
           base_size_use = base_size_use - 100
           xsize = round(base_size_use * x_factor * ncol)
           ysize = round(base_size_use * y_factor * nrow)
        endwhile

        ;; make or set window
        if windowavailable(window_num) then begin 
           wset, window_num
           if !d.x_size ne xsize or !d.y_size ne ysize then make_win = 1 else make_win = 0
        endif else make_win = 1
        if make_win eq 1 then window, window_num, xsize = xsize, ysize = ysize
        cgerase, background_color 

        ;; if pub is set, start ps output
        if keyword_set(pub) then pson, file = plotfile, /eps

        ;; calculate multi_size & multi x/ylen not calculated earlier
        multi_xlen = (multi_pos[2,0]-multi_pos[0,0])
        multi_ylen = (multi_pos[3,0]-multi_pos[1,0])
        multi_center = [multi_pos[0,0] + multi_xlen/2d, multi_pos[1,0] + multi_ylen/2d]
   
        ;; This print is necessary because for some reason the pixel
        ;; size of the window changes after a print and without this
        ;; statement the first plot has the wrong size. Awesome.
        temp = [!d.x_vsize,!d.y_vsize]
        print, temp
        
        multi_size = [!d.x_vsize*multi_xlen, !d.y_vsize*multi_ylen]

        multi_pos_use = multi_pos[*,0]
     endif else multi_pos_use = multi_pos

     multi_aspect = multi_size[1]/float(multi_size[0])
     
     new_aspect = aspect_ratio/multi_aspect
     if new_aspect gt 1 then begin
        y_factor = 1.
        x_factor = 1/new_aspect
     endif else begin          
        y_factor = new_aspect
        x_factor = 1.
     endelse
     
     new_xlen = multi_xlen*x_factor
     new_ylen = multi_ylen*y_factor
     new_multi = [multi_center[0] - new_xlen/2d, multi_center[1] - new_ylen*y_factor/2d, $
                  multi_center[0] + new_xlen/2d, multi_center[1] + new_ylen*y_factor/2d]
     
     new_pos = [new_xlen * plot_pos[0] + new_multi[0], new_ylen * plot_pos[1] + new_multi[1], $
                new_xlen * plot_pos[2] + new_multi[0], new_ylen * plot_pos[3] + new_multi[1]]
     
     new_cb_pos = [new_xlen * cb_pos[0] + new_multi[0], new_ylen * cb_pos[1] + new_multi[1], $
                   new_xlen * cb_pos[2] + new_multi[0], new_ylen * cb_pos[3] + new_multi[1]]
     
     plot_pos = new_pos
     cb_pos = new_cb_pos
     
     no_erase = 1
  endif else begin
     xsize = round(base_size * x_factor)
     ysize = round(base_size * y_factor)
     
     if not keyword_set(pub) then begin
        while (ysize gt max_ysize) or (xsize gt max_xsize) do begin
           base_size = base_size - 100
           xsize = round(base_size * x_factor)
           ysize = round(base_size * y_factor)
        endwhile
     endif
     no_erase = 0
  endelse

  if not keyword_set(no_title) then begin
     xloc_title = (plot_pos[2] - plot_pos[0])/2. + plot_pos[0]
     if n_elements(multi_pos) gt 0 then yloc_title = plot_pos[3] + 0.7* (multi_pos_use[3]-plot_pos[3]) $
     else yloc_title = plot_pos[3] + 0.6* (1-plot_pos[3])
  endif

  if n_elements(multi_pos) gt 0 then begin
     xloc_lambda = plot_pos[0] - 0.1* (plot_pos[0]-multi_pos_use[0])
     yloc_lambda = plot_pos[3] + 0.1* (multi_pos_use[3]-plot_pos[3])

     xloc2_lambda = plot_pos[2] + 0.1* (multi_pos_use[2]-plot_pos[2])
     yloc2_lambda = plot_pos[1] - 0.1* (plot_pos[1]-multi_pos_use[1])
  endif else begin
     xloc_lambda = (plot_pos[2] - plot_pos[0])/2d + plot_pos[0]
     yloc_lambda = plot_pos[3] + 0.3* (1-plot_pos[3])

     xloc2_lambda = plot_pos[2] + 0.3* (1-plot_pos[2])
     yloc2_lambda =  (plot_pos[3] - plot_pos[1])/2d + plot_pos[1]
  endelse

  if keyword_set(pub) then begin
     charthick = 3
     thick = 3
     xthick = 3
     ythick = 3
     if n_elements(charsize_in) eq 0 then begin
        if n_elements(multi_pos) gt 0 then begin
           charsize = 1.5d * (multi_size[0]/6500.)
        endif else charsize = 2
     endif else charsize = charsize_in
     font = 1
     
     if n_elements(multi_pos) eq 0 then begin
        window, window_num, xsize = xsize, ysize = ysize
        pson, file = plotfile, /eps 
     endif
  
  endif else begin
     charthick = 1
     thick = 1
     xthick = 1
     ythick = 1
     font = -1
     if n_elements(charsize_in) eq 0 then begin
        if n_elements(multi_pos) gt 0 then begin
           charsize = 1.2d * (multi_size[0]/float(base_size))
        endif else charsize = 2
     endif else charsize = charsize_in

     if n_elements(multi_pos) eq 0 then begin
        if windowavailable(window_num) then begin 
           wset, window_num
           if !d.x_size ne xsize or !d.y_size ne ysize then make_win = 1 else make_win = 0
        endif else make_win = 1
        
        if make_win eq 1 then window, window_num, xsize = xsize, ysize = ysize
     endif
  endelse

 
  if n_elements(title) ne 0 then plot_title = title $
  else begin
     case type of
        'abs': plot_title = 'Magnitude in ' + plane_name + ' plane'
        'phase': plot_title = 'Phase in ' + plane_name + ' plane'
        'real': plot_title = 'Real part of ' + plane_name + ' plane'
        'imaginary': plot_title = 'Imaginary part of ' + plane_name + ' plane'
        'weights': plot_title = plane_name + ' plane weights'
     endcase
  endelse

  if keyword_set(image_space) then begin
     case slice_axis of 
        0:begin
           plot_xtitle = 'theta y (radians)'
           plot_ytitle = plot_yname + ' (MHz)'
        end
        1: begin
           plot_xtitle = 'theta x (radians)'
           plot_ytitle = plot_yname + ' (MHz)'
        end
        2: begin
           plot_xtitle = 'theta x (radians)'
           plot_ytitle = 'theta y (radians)'
        end
     endcase
  endif else begin
     case slice_axis of 
        0:begin
           if keyword_set (hinv) then plot_xtitle = textoidl('k_y (h Mpc^{-1})', font = font) $
           else plot_xtitle = textoidl('k_y (Mpc^{-1})', font = font)
           plot_ytitle = plot_yname + ' (MHz)'
           baseline_xtitle = plot_xname + textoidl(' (\lambda)', font = font)
        end
        1: begin
           if keyword_set (hinv) then plot_xtitle = textoidl('k_x (h Mpc^{-1})', font = font) $
           else plot_xtitle = textoidl('k_x (Mpc^{-1})', font = font)
           plot_ytitle = plot_yname + ' (MHz)'
           baseline_xtitle = plot_xname + textoidl(' (\lambda)', font = font)
       end
        2: begin
           if keyword_set (hinv) then plot_xtitle = textoidl('k_x (h Mpc^{-1})', font = font) $
           else plot_xtitle = textoidl('k_x (Mpc^{-1})', font = font)
           if keyword_set (hinv) then plot_ytitle = textoidl('k_y (h Mpc^{-1})', font = font) $
           else plot_ytitle = textoidl('k_y (Mpc^{-1})', font = font)
           baseline_xtitle = plot_xname + textoidl(' (\lambda)', font = font)
           baseline_ytitle = plot_yname + textoidl(' (\lambda)', font = font)
       end
     endcase
  endelse

  plot_xarr = xarr_edges
  plot_yarr = yarr_edges

  if keyword_set(baseline_axis) then initial_title = '' else initial_title = plot_title

  axkeywords = {xstyle: 5, ystyle: 5, thick: thick, charthick: charthick, xthick: xthick, ythick: ythick, $
                charsize: charsize, font: font} 

  cgimage, slice_plot_norm_rgb, /nointerp, position = plot_pos, xrange = minmax(plot_xarr), yrange = minmax(plot_yarr), $
           title = initial_title, noerase = no_erase, color = annotate_color, background = background_color, $
           axkeywords = axkeywords, /axes

  if keyword_set(mark_0) then begin
     cgplot, /overplot, plot_yarr * 0d, plot_yarr, color=annotate_color, psym=-0, thick = thick
     if slice_axis eq 2 then  cgplot, /overplot, plot_xarr, plot_xarr* 0d, color=annotate_color, psym=-3, thick = thick
  endif


  cgaxis, xaxis=0, xtick_get = xticks, xtitle = plot_xtitle, xrange = minmax(plot_xarr), $
          charthick = charthick, xthick = xthick, ythick = ythick, charsize = charsize, font = font, $
          xstyle = 1, color = annotate_color
  
  cgaxis, yaxis=0, ytick_get = yticks, ytitle = plot_ytitle, yrange = minmax(plot_yarr), $
          charthick = charthick, xthick = xthick, ythick = ythick, charsize = charsize, font = font, ystyle = 1, color = annotate_color
 
  if keyword_set(baseline_axis) then begin
     ;; baselines don't care about hinv -- take it back out.
     if keyword_set(hinv) then baseline_range = minmax(plot_xarr * hubble_param * kperp_lambda_conv) $
     else baseline_range = minmax(plot_xarr* kperp_lambda_conv)
          
     cgaxis, xaxis=1, xrange = baseline_range, xthick = xthick,  charthick = charthick, ythick = ythick, charsize = charsize, $
             font = font, xstyle = 1, color = annotate_color, xtitle = baseline_xtitle
     
     if not keyword_set(no_title) then cgtext, xloc_title, yloc_title, plot_title, /normal, alignment=0.5, charsize=1.2 * charsize, $
                                               color = annotate_color, font = font
     ;; cgtext, xloc_lambda, yloc_lambda, baseline_xtitle, /normal, alignment=0.5, charsize=charsize, $
     ;;        color = annotate_color, font = font

  endif else $
     cgaxis, xaxis=1, xrange = minmax(plot_xarr), xtickv = xticks, xtickname = replicate(' ', n_elements(xticks)), $
             charthick = charthick, xthick = xthick, ythick = ythick, charsize = charsize, font = font, xstyle = 1, $
             color = annotate_color

  if keyword_set(baseline_axis) and slice_axis eq 2 then begin
     ;; baselines don't care about hinv -- take it back out.
     if keyword_set(hinv) then baseline_range = minmax(plot_yarr * hubble_param * kperp_lambda_conv) $
     else baseline_range = minmax(plot_yarr* kperp_lambda_conv)
          
     cgaxis, yaxis=1, yrange = baseline_range, xthick = xthick, charthick = charthick, ythick = ythick, charsize = charsize, $
             font = font, ystyle = 1, color = annotate_color, ytitle = baseline_ytitle

      ;; cgtext, xloc2_lambda, yloc2_lambda, baseline_ytitle, /normal, alignment=0.5, charsize=charsize, $
      ;;        color = annotate_color, font = font
 endif else $
     cgaxis, yaxis=1, yrange = minmax(plot_yarr), ytickv = yticks, ytickname = replicate(' ', n_elements(yticks)), $
             charthick = charthick, xthick = xthick, ythick = ythick, charsize = charsize, font = font, ystyle = 1, $
             color = annotate_color

  if type eq 'phase' then cb_range = data_range * 180/!dpi else cb_range = data_range


  cgcolorbar, color = annotate_color, /vertical, position = cb_pos, charsize = charsize, font = font, minrange = cb_range[0], $
              maxrange = cb_range[1], title = cb_title, minor=5, charthick = charthick, xthick = xthick, ythick = ythick

  if keyword_set(pub) and n_elements(multi_pos) eq 0 then begin
     psoff
     wdelete, window_num
  endif
  
  tvlct, r, g, b

end
