; Partially vectorized 2D discrete fourier transform of unevenly spaced data
;    A hybrid of the regular and vector approaches
; locations1 & 2 are x/y values of data points
; k1 & k2 are kx/ky values to test at


function discrete_ft_2d_fast, locations1, locations2, data, k1, k2, $
  timing = timing, fchunk = fchunk, exp2pi = exp2pi, no_progress = no_progress

  print, 'Beginning discrete 2D FT'

  time0 = systime(1)

  data_dims = size(data, /dimensions)
  n_dims = n_elements(data_dims)
  if n_dims gt 2 then message,  'Data can have up to 2 dimensions -- 1 for x & y combined and 1 for z'

  n_k1 = n_elements(k1)
  n_k2 = n_elements(k2)
  n_pts = data_dims[0]
  if n_dims eq 1 then n_slices = 1 else n_slices = data_dims[1]

  ;; fchunk is how many frequencies to process simultaneously.
  ;; It allows trade-off between speed and memory usage.
  ;; Defaut is 1 (minimum memory usage), max is number of f channels
  if n_elements(fchunk) eq 0 then fchunk = 1 else fchunk = round(fchunk)
  if (fchunk lt 0) or (fchunk) gt n_slices then $
     message, 'fchunk specifies how many frequencies to process simultaneously. Allowed values are 0-' + number_formatter(n_slices)

  if n_elements(locations1) ne n_pts or n_elements(locations2) ne n_pts then message, $
     'locations1 & 2 must have same number of elements as first dimension of data.'

  ft = complex(fltarr(n_k1, n_k2, n_slices))

  x_loc_k = float(matrix_multiply(locations1, k1, /btranspose))
  y_loc_k = float(matrix_multiply(locations2, k2, /btranspose))

  wh_freq0 = where(total(abs(data), 1) eq 0, count_freq0, complement = wh_freq_n0, ncomplement = count_freq_n0)
  if count_freq0 gt 0 then begin
     if count_freq_n0 eq 0 then message, 'data are all zeros'

     ;; want to skip zero channels to save time. Step through freqs in order of good channels.
     freq_order = [wh_freq_n0, wh_freq0]
  endif else freq_order = indgen(n_slices)

  n_chunks = ceil(count_freq_n0/float(fchunk))
  fchunk_sizes = intarr(n_chunks) + fchunk
  if n_chunks gt 1 then fchunk_sizes[n_chunks-1] = count_freq_n0 - total(fchunk_sizes[0:n_chunks-2])
  fchunk_edges = [0, total(fchunk_sizes, /cumulative)]

  nsteps = n_chunks
  inner_times = fltarr(nsteps)
  step1_times = fltarr(nsteps)
  step2_times = fltarr(nsteps)
  step3_times = fltarr(nsteps)

  if keyword_set(exp2pi) then begin
     y_exp = exp(-1.*2.*!pi*complex(0,1)*y_loc_k)
     x_exp = exp(-1.*2.*!pi*complex(0,1)*x_loc_k)
  endif else begin
     y_exp = exp(-1.*complex(0,1)*y_loc_k)
     x_exp = exp(-1.*complex(0,1)*x_loc_k)
  endelse

  x_exp_real = real_part(x_exp)
  x_exp_imag = imaginary(x_exp)

  undefine, x_exp

  time_preloop = systime(1) - time0
  print, 'pre-loop time: ' + strsplit(string(time_preloop), /extract)

  ;; check memory to reset the highwater mark
  temp = memory(/current)/1.e9

  for j=0, n_chunks-1 do begin

     temp=systime(1)

     if fchunk_sizes[j] eq 1 then begin
        freq_inds = freq_order[fchunk_edges[j]]
        data_inds = dindgen(n_pts) + n_pts*freq_inds

        data_expand = rebin(data[temporary(data_inds)], n_pts, n_k1, /sample)

        ;;; save memory if we're only going through this loop once
        if n_chunks EQ 1 then begin
           term1_real = data_expand * temporary(x_exp_real)
           term1_imag = temporary(data_expand) * temporary(x_exp_imag)
        endif else begin
           term1_real = data_expand * x_exp_real
           term1_imag = temporary(data_expand) * x_exp_imag
        endelse

     endif else begin
        freq_inds = freq_order[findgen(fchunk_sizes[j]) + fchunk_edges[j]]
        data_inds = rebin(dindgen(n_pts), n_pts, fchunk_sizes[j], /sample) + n_pts * $
                    rebin(reform(freq_inds, 1, fchunk_sizes[j]), n_pts, fchunk_sizes[j], /sample)

        data_expand = rebin(reform(data[temporary(data_inds)], n_pts, 1, fchunk_sizes[j]), n_pts, n_k1, fchunk_sizes[j], /sample)

        term1_real = reform(data_expand * rebin(x_exp_real, n_pts, n_k1,fchunk_sizes[j], /sample), n_pts, n_k1*fchunk_sizes[j])

        term1_imag = reform(temporary(data_expand) * rebin(x_exp_imag, n_pts, n_k1,fchunk_sizes[j], /sample), $
                            n_pts, n_k1*fchunk_sizes[j])

     endelse
     term1 = temporary(term1_real)+complex(0,1)*temporary(term1_imag)

     temp2 = systime(1)

     if fchunk_sizes[j] eq 1 then begin
        inds = dindgen(n_k1*n_k2) + n_k1 * n_k2 * freq_inds

        temp3 = systime(1)

        ft[temporary(inds)] = matrix_multiply(temporary(term1), y_exp,/atranspose)

     endif else begin
        inds = reform(rebin(dindgen(n_k1*n_k2), n_k1*n_k2, fchunk_sizes[j], /sample) + $
                      n_k1 * n_k2 * rebin(reform(freq_inds, 1, fchunk_sizes[j]), $
                                          n_k1*n_k2, fchunk_sizes[j], /sample), n_k1, n_k2, fchunk_sizes[j])
        temp3 = systime(1)
        ft[temporary(inds)] = transpose(reform(matrix_multiply(temporary(term1), y_exp,/atranspose), $
                                               n_k1, fchunk_sizes[j], n_k2), [0,2,1])
     endelse

     temp4 = systime(1)

     inner_times[j] = temp4 - temp
     step1_times[j] = temp2-temp
     step2_times[j] = temp3-temp2
     step3_times[j] = temp4-temp3

     if not keyword_set(no_progress) then begin
       prog_steps, j, nsteps, inner_times, progress_steps=progress_steps
     endif

  endfor

  time1 = systime(1)
  timing = time1-time0

  if timing lt 60 then timing_str = number_formatter(timing, format='(d8.2)') + ' sec' $
  else if timing lt 3600 then timing_str = number_formatter(timing/60, format='(d8.2)') + ' min' $
  else timing_str= number_formatter(timing/3600, format='(d8.2)') + ' hours'

  print, 'discrete 2D FT time: ' + timing_str

  return, ft
end
