pro kpower_1d_plots, power_savefile, plot_weights = plot_weights, multi_pos = multi_pos, data_range = data_range, k_range = k_range, $
    png = png, eps = eps, pdf = pdf, plotfile = plotfile, window_num = window_num, colors = colors, names = names, psyms = psyms, $
    save_text = save_text, delta = delta, hinv = hinv, note = note, title = title, kpar_power = kpar_power, kperp_power = kperp_power, $
    yaxis_type = yaxis_type
    
  if n_elements(yaxis_type) eq 0 then yaxis_type = 'clipped_log'
  yaxis_type_list = ['clipped_log', 'sym_log', 'folded_log']
  wh_axis_type = where(yaxis_type_list eq yaxis_type, count_axis_type)
  if count_axis_type eq 0 then message, 'yaxis_type not recognized'
  
  if keyword_set(kpar_power) and keyword_set(kperp_power) then message, 'Only one of kpar_power and kperp_power can be set'
  
  if n_elements(plotfile) gt 0 or keyword_set(png) or keyword_set(eps) or keyword_set(pdf) then pub = 1 else pub = 0
  if pub eq 1 then begin
    if not (keyword_set(png) or keyword_set(eps) or keyword_set(pdf)) then begin
      basename = cgRootName(plotfile, directory=directory, extension=extension)
      
      case extension of
        'eps': eps=1
        'png': png=1
        'pdf': pdf=1
        '': png = 1
        else: begin
          print, 'Unrecognized extension, using png'
          png = 1
        end
      endcase
      
    endif
    if n_elements(plotfile) eq 0 and n_elements(multi_pos) eq 0 then begin
      if keyword_set(kpar_power) then plotfile = 'idl_kpar_power_plots' else $
        if keyword_set(kperp_power) then plotfile = 'idl_kperp_power_plots' else plotfile = 'idl_kpower_1d_plots'
      cd, current = current_dir
      print, 'no filename specified for kpower_1d_plots output. Using ' + current_dir + path_sep() + plotfile
    endif
    
    if keyword_set(png) and keyword_set(eps) and keyword_set(pdf) then begin
      print, 'only one of eps, pdf and png can be set, using png'
      eps = 0
    endif
    
    if keyword_set(png) then begin
      plot_exten = '.png'
      delete_ps = 1
    endif else if keyword_set(pdf) then begin
      plot_exten = '.pdf'
      delete_ps = 1
    endif else if keyword_set(eps) then begin
      plot_exten = '.eps'
      delete_ps = 0
    endif
  endif
  
  if n_elements(window_num) eq 0 then window_num = 2
  
  nfiles = n_elements(power_savefile)
  if n_elements(names) gt 0 and n_elements(names) ne nfiles then message, 'Number of names does not match number of files'
  if n_elements(colors) gt 0 and n_elements(colors) ne nfiles then message, 'Number of colors does not match number of files'
  if n_elements(psyms) gt 0 then begin
    if n_elements(psym) eq 1 then psyms = intarr(nfiles) + psyms
    if n_elements(psyms) ne nfiles then message, 'Number of psyms does not match number of files'
  endif else psyms = intarr(nfiles) + 10
  
  margin = [0.15, 0.2, 0.05, 0.1]
  plot_pos = [margin[0], margin[1], (1-margin[2]), (1-margin[3])]
  
  if n_elements(multi_pos) gt 0 then begin
    if n_elements(multi_pos) ne 4 then message, 'multi_pos must be a 4 element plot position vector'
    if max(multi_pos) gt 1 or min(multi_pos) lt 0 then message, 'multi_pos must be in normalized coordinates (between 0 & 1)'
    if multi_pos[2] le multi_pos[0] or multi_pos[3] le multi_pos[1] then $
      message, 'In multi_pos, x1 must be greater than x0 and y1 must be greater than y0 '
      
    no_erase = 1
    
    xlen = (multi_pos[2]-multi_pos[0])
    ylen = (multi_pos[3]-multi_pos[1])
    
    plot_pos = [xlen * plot_pos[0] + multi_pos[0], ylen * plot_pos[1] + multi_pos[1], $
      xlen * plot_pos[2] + multi_pos[0], ylen * plot_pos[3] + multi_pos[1]]
      
    margin = [xlen, ylen, xlen, ylen] * margin
    
  endif else no_erase = 0
  
  if yaxis_type eq 'sym_log' then begin
    ymid = plot_pos[1] + (plot_pos[3]-plot_pos[1])/2.
    positive_plot_pos = [plot_pos[0], ymid, plot_pos[2], plot_pos[3]]
    negative_plot_pos = [plot_pos[0], plot_pos[1], plot_pos[2], ymid]
    
    xloc_ytitle = plot_pos[0] - margin[0]/2.
    yloc_ytitle = ymid
  endif
  
  
  if pub then begin
    if n_elements(plotfile) eq 0 then plotfile = strsplit(power_savefile[0], '.idlsave', /regex, /extract) + '_1dkplot' + plot_exten $
    else if strcmp(strmid(plotfile, strlen(plotfile)-4), plot_exten, /fold_case) eq 0 then plotfile = plotfile + plot_exten
  endif
  
  color_list = ['black', 'PBG5', 'red6', 'GRN3', 'PURPLE', 'ORANGE', 'TG2','TG8', 'blue', 'olive drab', 'coral', 'magenta']
  
  if n_elements(colors) eq 0 then begin
    if nfiles gt n_elements(color_list) then colors = indgen(nfiles)*254/(nfiles-1) $
    else colors = color_list[indgen(nfiles)]
  endif
  
  if keyword_set(save_text) then begin
    text_filename = strsplit(plotfile, plot_exten, /regex, /extract) + '.txt'
    if nfiles gt 1 then if n_elements(names) ne 0 then text_labels = names else text_labels = strarr(nfiles)
    
    openw, lun, text_filename, /get_lun
  endif
  
  
  for i=0, nfiles-1 do begin
    restore, power_savefile[i]
    
    n_k = n_elements(power)
    
    if keyword_set(plot_weights) then begin
      if n_elements(weights) ne 0 then power = weights $
      else message, 'No weights array included in this file'
    endif
    
    if keyword_set(hinv) then begin
      if n_elements(k_edges) ne 0 then k_edges = k_edges / hubble_param
      if n_elements(k_centers) ne 0 then k_centers = k_centers / hubble_param
      if not keyword_set(plot_weights) then power = power * (hubble_param)^3d
    endif
    
    log_bins = 1
    if n_elements(k_centers) ne 0 then k_log_diffs = (alog10(k_centers) - shift(alog10(k_centers), 1))[2:*] $
    else k_log_diffs = (alog10(k_edges) - shift(alog10(k_edges), 1))[2:*]
    if total(abs(k_log_diffs - k_log_diffs[0])) gt n_k*1e-15 then log_bins = 0
    
    if n_elements(k_centers) ne 0 then begin
      k_mid = k_centers
      if n_elements(k_edges) eq 0 then begin
        if log_bins then begin
          k_bin = alog10(k_centers[2])-alog10(k_centers[1])
          k_edges = 10^([alog10(k_centers) - k_bin, alog10(max(k_centers)) + k_bin])
        endif else begin
          k_bin = k_centers[2] - k_centers[1]
          k_edges = [k_centers - k_bin, max(k_centers) + k_bin]
        endelse
      endif
    endif else begin
      if n_elements(k_bin) eq 0 then $
        if log_bins then k_bin = alog10(k_edges[2])-alog10(k_edges[1]) else k_bin = k_edges[2] - k_edges[1]
      if log_bins then k_mid = 10^(alog10(k_edges[1:*]) - k_bin/2.) else k_mid = k_edges[1:*] - k_bin/2.
    endelse
    
    ;; limit to k_range if set
    if keyword_set(k_range) then begin
      wh_k_inrange = where(k_edges ge k_range[0] and k_edges[1:*] le k_range[1], n_k_plot)
      
      if n_k_plot eq 0 then message, 'No data in plot k range'
      
      if n_k_plot ne n_k then begin
        power = power[wh_k_inrange]
        k_mid = k_mid[wh_k_inrange]
        temp = [wh_k_inrange, wh_k_inrange[n_k_plot-1]+1]
        k_edges = k_edges[temp]
        n_k = n_k_plot
      endif
      
    endif
    
    theory_delta = (power * k_mid^3d / (2d*!pi^2d)) ^(1/2d)
    
    if keyword_set(save_text) then begin
      if keyword_set(hinv) then printf, lun,  text_labels[i]+ ' k (h Mpc^-1)' $
      else printf, lun,  text_labels[i]+ ' k (Mpc^-1)'
      printf, lun, transpose(k_mid)
      printf, lun, ''
      if keyword_set(delta) then begin
        printf, lun,  text_labels[i]+ ' delta (sqrt(k^3 Pk/(2pi^2)) -- mk)'
        printf, lun, transpose(theory_delta)
      endif else begin
        if keyword_set(hinv) then printf, lun, text_labels[i] + ' power (mk^2 h^-3 Mpc^3)' $
        else printf, lun,  text_labels[i]+ ' power (mk^2 Mpc^3)'
        printf, lun, transpose(power)
      endelse
      printf, lun, ''
    endif
    
    if keyword_set(delta) then power = theory_delta
    
    wh_zero = where(power eq 0d, count_zero, complement = wh_non0, ncomplement = count_non0)
    if count_non0 eq 0 then message, 'No non-zero power'
    if count_zero gt 0 then begin
      ;; only want to drop 0 bins at the edges.
      wh_keep = indgen(max(wh_non0) - min(wh_non0) + 1) + min(wh_non0)
      
      power = power[wh_keep]
      k_mid = k_mid[wh_keep]
      k_edges = k_edges[[wh_keep, max(wh_keep)+1]]
      
      wh_zero = where(power eq 0d, count_zero, complement = wh_non0, ncomplement = count_non0)
    endif
    
    ;; extend arrays for plotting full histogram bins if plotting w/ psym=10
    if psyms[i] eq 10 then begin
      if min(k_edges gt 0) then k_mid = [min(k_edges), k_mid, max(k_edges)] $
      else k_mid = [10^(alog10(k_mid[0])-k_log_diffs[0]), k_mid, max(k_edges)]
      power = [power[0], power, power[n_elements(power)-1]]
    endif
    
    
    wh_neg = where(power lt 0d, count_neg)
    wh_pos = where(power gt 0d, count_pos)
    if count_pos gt 0 then pos_range = minmax(power[wh_pos])
    if count_neg gt 0 then neg_range = minmax(power[wh_neg])
    
    if count_pos eq 0 and yaxis_type eq 'clipped_log' then message, 'No positive power and yaxis_type is clipped_log'
    
    tag = 'f' + strsplit(string(i),/extract)
    if i eq 0 then begin
      if n_elements(data_range) eq 0 then begin
        if yaxis_type ne 'clipped_log' then yrange = 10.^([floor(alog10(min(abs(power[wh_non0])))), ceil(alog10(max(abs(power[wh_non0]))))]) $
        else yrange = 10.^([floor(alog10(min_pos)), ceil(alog10(max(power)))])
      endif else begin
        yrange = data_range
      endelse
      if n_elements(k_range) eq 0 then xrange = minmax(k_mid) else xrange = k_range
      
      power_plot = create_struct(tag, power)
      k_plot = create_struct(tag, k_mid)
      
      if yaxis_type ne 'clipped_log' then begin
        n_pos = [count_pos]
        pos_locs = create_struct(tag, wh_pos)
        
        n_neg = [count_neg]
        neg_locs = create_struct(tag, wh_neg)
        
        n_zero = [count_zero]
        zero_locs = create_struct(tag, wh_zero)
      endif
      
    endif else begin
      if n_elements(data_range) eq 0 then begin
        if yaxis_type ne 'clipped_log' then yrange = minmax([yrange, 10.^([floor(alog10(min(abs(power[wh_non0])))), ceil(alog10(max(abs(power[wh_non0]))))])]) $
        else yrange = minmax([yrange, 10.^([floor(alog10(min_pos)), ceil(alog10(max(power)))])])
      endif
      if n_elements(k_range) eq 0 then begin
        xrange_new = minmax(k_mid)
        xrange = minmax([xrange, xrange_new])
      endif
      
      power_plot = create_struct(tag, power, power_plot)
      k_plot = create_struct(tag, k_mid, k_plot)
      
      if yaxis_type ne 'clipped_log' then begin
        n_pos = [n_pos, count_pos]
        pos_locs = create_struct(tag, wh_pos, pos_locs)
        
        n_neg = [n_neg, count_neg]
        neg_locs = create_struct(tag, wh_neg, neg_locs)
        
        n_zero = [n_zero, count_zero]
        zero_locs = create_struct(tag, wh_zero, zero_locs)
      endif
      
    endelse
    
    undefine, power
    if n_elements(k_edges) ne 0 then undefine, k_edges
    if n_elements(k_centers) ne 0 then undefine, k_centers
  endfor
  
  xloc_note = .99
  yloc_note = 0 + 0.1* (plot_pos[1]-0)
  
  if keyword_set(save_text) then free_lun, lun
  
  tvlct, r, g, b, /get
  
  if keyword_set(pub) then begin
    charthick = 3
    thick = 3
    xthick = 3
    ythick = 3
    charsize = 2
    font = 1
    if nfiles gt 3 then legend_charsize = charsize / (nfiles/3d)  else legend_charsize = 2
    
    if n_elements(multi_pos) eq 0 then begin
      cgps_open, plotfile, /font, encapsulated=eps, landscape=1, pagetype='letter'
    endif
    
    DEVICE, /ISOLATIN1
    perp_char = '!9' + String("136B) + '!X' ;"
    
  endif else if n_elements(multi_pos) eq 0 then begin
    if windowavailable(window_num) then wset, window_num else window, window_num
    
    perp_char = '!9' + string(120B) + '!X'
  endif
  
  ;;plot, k_plot, power_plot, /ylog, /xlog, xrange = xrange, xstyle=1
  plot_order = reverse(indgen(nfiles))
  if keyword_set(plot_weights) then begin
    ytitle = 'Weights'
  endif else begin
    if keyword_set(delta) then ytitle = textoidl('(k^3 P_k /(2\pi^2))^{1/2} (mK)', font = font) else begin
      if keyword_set(hinv) then ytitle = textoidl('P_k (mK^2 h^{-3} Mpc^3)', font = font) $
      else ytitle = textoidl('P_k (mK^2 Mpc^3)', font = font)
    endelse
  endelse
  if keyword_set(kpar_power) then begin
    if keyword_set(hinv) then xtitle = textoidl('k_{||} (h Mpc^{-1})', font = font) $
    else xtitle = textoidl('k_{||} (Mpc^{-1})', font = font)
  endif else if keyword_set(kperp_power) then begin
    if keyword_set (hinv) then xtitle = textoidl('k_{perp} (h Mpc^{-1})', font = font) $
    else xtitle = textoidl('k_{perp} (Mpc^{-1})', font = font)
    xtitle = repstr(xtitle, 'perp', perp_char)
  endif else begin
    if keyword_set(hinv) then xtitle = textoidl('k (h Mpc^{-1})', font = font) $
    else xtitle = textoidl('k (Mpc^{-1})', font = font)
  endelse
  
  case yaxis_type of
    'sym_log': begin
      cgplot, k_plot.(plot_order[0]), power_plot.(plot_order[0]), position = positive_plot_pos, /ylog, /xlog, xrange = xrange, yrange = yrange, $
        xstyle=1, ystyle=1, axiscolor = 'black', title = title, psym=psyms[0], xtickformat = '(A1)', /nodata,$
        ytickformat = 'exponent', thick = thick, charthick = charthick, xthick = xthick, ythick = ythick, charsize = charsize, $
        font = font, noerase = no_erase
      for i=0, nfiles - 1 do if n_pos[i] gt 0 then begin
        temp_plot = power_plot.(plot_order[i])
        if n_neg[i] gt 0 then temp_plot[wh_neg] = yrange[0]
        if n_zero[i] gt 0 then temp_plot[wh_zero] = yrange[0]
        cgplot, /overplot, k_plot.(plot_order[i]), temp_plot, psym=psyms[i], color = colors[i], $
          thick = thick
      endif
      cgtext, xloc_ytitle, yloc_ytitle, ytitle, /normal, alignment=0.5, orientation = 90, charsize = charsize, font = font
      
      if log_bins gt 0 then bottom = 1 else bottom = 0
      if n_elements(names) ne 0 then $
        al_legend, names, textcolor = colors, box = 0, /right, bottom = bottom, charsize = legend_charsize, charthick = charthick
        
        
      cgplot, k_plot.(plot_order[0]), -1*(power_plot.(plot_order[0])), position = negative_plot_pos, /ylog, /xlog, xrange = xrange, yrange = reverse(yrange), $
        xstyle=1, ystyle=1, axiscolor = 'black', psym=psyms[0], xtickformat = 'exponent', /nodata, $
        ytickformat = 'exponent', thick = thick, charthick = charthick, xthick = xthick, ythick = ythick, charsize = charsize, $
        font = font, /noerase
      for i=0, nfiles - 1 do if n_neg[i] gt 0 then begin
        temp_plot = -1*(power_plot.(plot_order[i]))
        if n_pos[i] gt 0 then temp_plot[wh_pos] = yrange[0]
        if n_zero[i] gt 0 then temp_plot[wh_zero] = yrange[0]
        cgplot, /overplot, k_plot.(plot_order[i]), temp_plot, psym=psyms[i], color = colors[i], $
          thick = thick
      endif
    end
    'folded_log': begin
      cgplot, k_plot.(plot_order[0]), power_plot.(plot_order[0]), position = plot_pos, /nodata, /ylog, /xlog, xrange = xrange, yrange = yrange, $
        xstyle=1, ystyle=1, axiscolor = 'black', xtitle = xtitle, ytitle = ytitle, title = title, psym=psyms[0], xtickformat = 'exponent', $
        ytickformat = 'exponent', thick = thick, charthick = charthick, xthick = xthick, ythick = ythick, charsize = charsize, $
        font = font, noerase = no_erase
      for i=0, nfiles - 1 do begin
        if n_pos[i] gt 0 then begin
          temp_plot = power_plot.(plot_order[i])
          if n_neg[i] gt 0 then temp_plot[wh_neg] = yrange[0]
          if n_zero[i] gt 0 then temp_plot[wh_zero] = yrange[0]
          cgplot, /overplot, k_plot.(plot_order[i]), temp_plot, psym=psyms[i], color = colors[i], $
            thick = thick
        endif

        if n_neg[i] gt 0 then begin
          temp_plot = -1*(power_plot.(plot_order[i]))
          if n_pos[i] gt 0 then temp_plot[wh_pos] = yrange[0]
          if n_zero[i] gt 0 then temp_plot[wh_zero] = yrange[0]
          cgplot, /overplot, k_plot.(plot_order[i]), temp_plot, psym=psyms[i], color = colors[i], $
            thick = thick, linestyle=2            
        endif
      endfor

      if log_bins gt 0 then bottom = 1 else bottom = 0
      if n_elements(names) ne 0 then $
        al_legend, names, textcolor = colors, box = 0, /right, bottom = bottom, charsize = legend_charsize, charthick = charthick
        
        
    end
    'clipped_log': begin
      cgplot, k_plot.(plot_order[0]), power_plot.(plot_order[0]), position = plot_pos, /ylog, /xlog, xrange = xrange, yrange = yrange, $
        xstyle=1, ystyle=1, axiscolor = 'black', xtitle = xtitle, ytitle = ytitle, title = title, psym=psyms[0], xtickformat = 'exponent', $
        ytickformat = 'exponent', thick = thick, charthick = charthick, xthick = xthick, ythick = ythick, charsize = charsize, $
        font = font, noerase = no_erase
      for i=0, nfiles - 1 do cgplot, /overplot, k_plot.(plot_order[i]), power_plot.(plot_order[i]), psym=psyms[i], color = colors[i], $
        thick = thick
        
      if log_bins gt 0 then bottom = 1 else bottom = 0
      if n_elements(names) ne 0 then $
        al_legend, names, textcolor = colors, box = 0, /right, bottom = bottom, charsize = legend_charsize, charthick = charthick
        
    end
  endcase
  if n_elements(note) ne 0 then begin
    if keyword_set(pub) then char_factor = 0.75 else char_factor = 1
    cgtext, xloc_note, yloc_note, note, /normal, alignment=1, charsize = char_factor*charsize, font = font
  endif
  
  if keyword_set(pub) and n_elements(multi_pos) eq 0 then begin
    cgps_close, png = png, pdf = pdf, delete_ps = delete_ps, density=600
  endif
  
  tvlct, r, g, b
  
end
