""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" File: vcal.vim
" Author: Ken Steen (ksteen@users.sf.net)
" Last Changed: January 13, 2002
" Version: 0.1
"-------------------------------------------------------------------------------
" Vcal is a calendar script for vim.
" Latest version is available at:
" http://vide.sf.net/download.html
"-------------------------------------------------------------------------------
" This file can either be put in a vim plugin directory or loaded into vim with
" :source vcal.vim
"
" Setup:
"		Change the g:Vcalfile, line 62, and the g:Vcaluser, line 64, 
"   variables to the correct settings.
"
" Commands:
"
"		Vcal - starts vcal from vim.
"
"		The following commands are only set in the vcal buffer.
"			ApptVcal - set a new appointment.
"			DateVcal month year - move to a new date :DateVcal 12 2004
"	 		TodayVcal - change calendar to show today.
"			AlarmVcal - set an alarm with a message.
"
" Mappings:
"	 n is mapped to go forward one month.
"  N is mapped to go backward one month.
"	 dd is mapped to remove the appointment under the cursor.
"	 
"
"	Todo:
"		The cat, echo, and at system commands should be replaced or changed to 
"		detect the operating system and use the appropriate system call.
"	 	All of the options for setting appointments are not yet implemented such 
" 		as end dates, complex repeating dates . . .
"		The syntax highlighting needs to be rewritten.
"		The :Alarm command needs to be changed to work in the console.
"		The file format should be changed to allow either vcalendar or vcard.		
"		Allow week to start on a Monday.
"===============================================================================

if exists("loaded_vcal")
	finish
endif
let loaded_vcal=1

if !exists(':Vcal')
	command -n=0 Vcal :call s:StartVcal()
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" User Settings

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ********** Do not use this release with a vcf file that you need! ************
" There is a sample vcf file included in the tarball or vcal will start 
" a new user-cal.vcf file if the file given is not readable.  
 let s:Vcalfile = "~/vcal-0.1/user-cal.vcf"
" let s:Vcalfile = "~/.user-cal.vcf"
" Change this to the user name for the calendar
 let s:Vcaluser = "kcs"


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Global Declarations 

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Current month and year shown in calendar.
let g:Vcalmonth_showing =strftime("%m") + 0
let g:Vcalyear_showing =strftime("%y") + 2000

" Todays date.
let g:Vcalthis_year = g:Vcalyear_showing
let g:Vcalthis_month = g:Vcalmonth_showing + 0

"strftime("%d") will return 03 instead of 3 this removes the 0.
let g:Vcalthis_day =strftime("%d") + 0
if strpart(g:Vcalthis_day, 0, 1) == 0
	let g:Vcalthis_day = strpart(g:Vcalthis_day, 1, 1) + 0
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" setup_commands()
" Add the vcal user commands.

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:setup_commands()

	if !exists(':AlarmVcal')
		command -n=0 AlarmVcal :call s:set_alarm()
	endif
	if !exists(':TodayVcal')
		command -n=0 TodayVcal :call s:show_month(g:Vcalthis_month, g:Vcalthis_year)
	endif
	if !exists(':DateVcal')
		command -n=+ DateVcal :call s:show_month(<f-args>)
	endif
	if !exists(':ApptVcal')
		command -n=0 ApptVcal :call s:set_appointment()
	endif

endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" StartVcal() 
" Initialize the commands and key mappings.

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:StartVcal()

	"If the current buffer is modified open vcal in a split window.
	if &modified
		silent :split Vcal.vcal
	else
		silent :edit! Vcal.vcal
	endif

	call s:setup_commands()

	" Map n go to next month N go to previous month when in the script.
	map <script><buffer><silent> n :call <SID>show_month(g:Vcalmonth_showing +1, g:Vcalyear_showing)<CR>
	map <script><buffer><silent> N :call <SID>show_month(g:Vcalmonth_showing -1, g:Vcalyear_showing)<CR>
	" dd delete an appointment
	map <script><buffer><silent> dd :call <SID>remove_appointment()<CR>

	setlocal noswapfile
	setlocal buftype=nowrite
	setlocal bufhidden=delete
	setlocal modifiable

	" The vcal commands are removed when leaving the buffer and
	" added back when entering the buffer.
	augroup vcal
		au!
		au BufLeave *.vcal call s:remove_commands()
		au BufEnter *.vcal  call s:setup_commands()
	augroup end

	"Show the initial calendar
	call s:show_month(g:Vcalthis_month, g:Vcalthis_year)

endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" show_month() 
" Adds the appointments to the calendar.

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:show_month(...)

  
	if a:0 == 2 " month and year are given

		" 2 digit year 
		if strlen(a:2) < 4 
			let expanded_year = a:2 +2000
		else
			let expanded_year = a:2
		endif

		"Using n or N to move through the months needs this correction.
		if a:1 == 13 
			let correct_month = 1
			let expanded_year = expanded_year +1
		elseif a:1 == 0
			let correct_month = 12
			let expanded_year = expanded_year -1
		else
			let correct_month = a:1
		endif
		let g:Vcalyear_showing = expanded_year
	elseif a:0 == 1 " only the month is given
		let g:Vcalyear_showing = g:Vcalthis_year
		let expanded_year = g:Vcalthis_year
		let correct_month = a:1
	endif

	let g:Vcalmonth_showing = correct_month
	
	" The date calculations can handle years like 30000 but it is probably not
	" what the user wants and the repeating date calculations will take forever.
	if expanded_year > 2100 
		let answer = input("Do you really want the year "  . expanded_year . "? \nThe repeating date functions will take a long time. y/n ")
		if answer != "y"
			let g:Vcalyear_showing = g:Vcalthis_year + 0
			let g:Vcalmonth_showing = g:Vcalthis_month + 0
			let correct_month = g:Vcalthis_month + 0
			let expanded_year = g:Vcalthis_year + 0
		endif
	endif

	setlocal modifiable

	syntax clear
	
	"Clear the buffer
	silent 1,$d 
	call s:print_month(correct_month, expanded_year)

	let line = "-------------------------------------------------------------------------------"
	put =line

	let space = " "
	silent put =space

	call s:show_vcf_dates(1, correct_month, expanded_year)
	call s:setup_syntax() 
	call s:sort_appointments()


	"Move to the separator line.
	0
	/^---

	echo " "
	setlocal nomodifiable
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" compare_dates()
" Used with SortR to sort the appointments by date.

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:compare_dates(line1, line2, direction)
	
	let matchend = match(a:line1, " ")
	let number_one = strpart(a:line1, 0, matchend) + 0
	let matchend = match(a:line2, " ")
	let number_two = strpart(a:line2, 0, matchend) + 0
	
	if number_one < number_two
		return -a:direction
	"Same date so sort by hour. 
	elseif number_two == number_one 
		let pos = matchend(a:line1, " . ")
		let message = strpart(a:line1, pos)
		let hr1 = matchend(message, "^[0-9]*") 
		let hour1 = strpart(message, 0, hr1) + 0
		let pos = matchend(message, "\:")
		let min1 = strpart(message, pos, 2) + 0
		let pos = matchend(a:line2, " . ")
		let message = strpart(a:line2, pos)
		let hr2 = matchend(message, "^[0-9]*")
		let hour2 = strpart(message, 0, hr2) + 0
		let pos = matchend(message, "\:")
		let min2 = strpart(message, pos, 2) + 0
		if hr1 == -1 && hr2 == -1
			return 0
		elseif hr1 == -1
			return -a:direction
		elseif hr2 == -1 
			return a:direction
		else
			if hour1 < hour2
				return -a:direction
			"Same hour so sort by minutes.
			elseif hour1 == hour2
				if min1 < min2
					return -a:direction
				elseif min1 == min2
					return 0
				else
					return a:direction
				endif
			else
				return a:direction
			endif
		endif
	else
		return a:direction
	endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" sort_appointments()
" Calls SortR() to sort the appointments by date.

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:sort_appointments()

	0
	/^---
	let begin = line(".") + 2
	let end = begin
	while strlen(getline(end)) > 1
		let end = end + 1
	endwhile
	let end = end - 1
	call s:SortR(begin, l:end, "s:compare_dates", 1)

endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"SortR() from explorer.vim
" A vim script quick sort 

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:SortR(start, end, cmp, direction)

  " Bottom of the recursion if start reaches end
  if a:start >= a:end
    return
  endif

  let partition = a:start - 1
  let middle = partition
  let partStr = getline((a:start + a:end) / 2)
  let i = a:start
  while (i <= a:end)
    let str = getline(i)
    exec "let result = " . a:cmp . "(str, partStr, " . a:direction . ")"
    if result <= 0
      " Need to put it before the partition.  Swap lines i and partition.
      let partition = partition + 1
      if result == 0
        let middle = partition
      endif
      if i != partition
        let str2 = getline(partition)
        call setline(i, str2)
        call setline(partition, str)
      endif
    endif
    let i = i + 1
  endwhile

  " Now we have a pointer to the "middle" element, as far as partitioning
  " goes, which could be anywhere before the partition.  Make sure it is at
  " the end of the partition.
  if middle != partition
    let str = getline(middle)
    let str2 = getline(partition)
    call setline(middle, str2)
    call setline(partition, str)
  endif
  call s:SortR(a:start, partition - 1, a:cmp,a:direction)
  call s:SortR(partition + 1, a:end, a:cmp,a:direction)
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" get_days_in_month() 
" Returns the number of days in a month.  

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:get_days_in_month(month, year)

	if a:month == 1 
		return 31
	elseif a:month == 2  
		if s:is_leap_year(a:year) 
			return 29
		else
			return 28
		endif
	elseif a:month == 3 
		return 31
	elseif a:month == 4 
		return 30
	elseif a:month == 5 
		return 31
	elseif a:month == 6 
		return 30
	elseif a:month == 7 
		return 31
	elseif a:month == 8 
		return 31
	elseif a:month == 9 
		return 30
	elseif a:month == 10 
		return 31
	elseif a:month == 11 
		return 30
	elseif a:month == 12 
		return 31
	endif
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" print_month()  
" Prints the monthly calendar on the top of the page.

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:print_month(month, year)

	if a:month == 1
		let title = "     January " . a:year
	elseif a:month == 2
		let title = "     February " . a:year
	elseif a:month == 3
		let title = "      March " . a:year
	elseif a:month == 4
		let title = "      April " . a:year
	elseif a:month == 5
		let title = "       May " . a:year
	elseif a:month == 6
		let title = "       June " . a:year
	elseif a:month == 7
		let title = "       July " . a:year
	elseif a:month == 8
		let title = "      August " . a:year
	elseif a:month == 9
		let title = "    September " . a:year
	elseif a:month == 10
		let title = "     October " . a:year
	elseif a:month == 11
		let title = "     November " . a:year
	elseif a:month == 12
		let title = "     December " . a:year
	endif

	let week_title = " Su Mo Tu We Th Fr Sa "
	let day_in_week =  s:day_in_week(1, a:month, a:year) 
	let month_days =  s:get_days_in_month(a:month, a:year) 

	" Start at the top of the buffer.
	0

	put =title 
	put =week_title

	let day_num = 1
	let start_col = day_in_week
	let cal_line = "" 
	let column = 0

	"First line of calendar dates.
	while column < start_col  
		let cal_line = cal_line . "   "
		let column = column + 1
	endwhile
	while column < 7
		let cal_line = cal_line . "  " . day_num
		let day_num = day_num + 1
		let column = column +1
	endwhile
	put =cal_line

	"The rest of the calendar
	while day_num <= month_days 
		let cal_line = ""
		let column = 0
		while column < 7 && day_num <= month_days 
			if day_num < 10
				let cal_line = cal_line . "  " . day_num
			else
				let cal_line = cal_line . " " . day_num
			endif
			let day_num = day_num + 1
			let column = column + 1
		endwhile
		put =cal_line
	endwhile
	let cal_line = ""
	put =cal_line

endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" day_in_week() 
" Returns the 0 based day of the week the given date falls on.
" Assumes Gregorian reformation eliminates September 3, 1752 through 
" September 13, 1752.  Returns Thursday for all missing days.
" Taken from the cal program.

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:day_in_week( day, month, year)

	" The total number of days since year 1.
	let leap_years =  s:leap_years_since_year_one(a:year - 1)
	let day_in_year = s:day_in_year(a:day, a:month, a:year)
	let total_days = (((a:year - 1) * 365) + leap_years + day_in_year)

	" The calendar was changed September 3, 1752
	let SATURDAY = 6 " 1/1/1 was a Saturday
	let FIRST_MISSING_DAY = 639799  " September 3, 1752
	let NUMBER_MISSING_DAYS  = 11  " 11 day correction during reformation
	" if day falls before September 3, 1752, mod by 7 to see how many weeks have
	" passed. 
	if total_days < FIRST_MISSING_DAY " Before September 3, 1752
		return ((total_days - 1 + SATURDAY) % 7)
	elseif total_days >= (FIRST_MISSING_DAY + NUMBER_MISSING_DAYS) "After change 
		return ((( total_days -1 + 6 ) - 11) % 7)
	else " It's a Thursday.
		return 4
	endif

endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" leap_years_since_year_one() 
" Returns leap years since year 1
" Taken from the cal program.

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:leap_years_since_year_one(year)

	if a:year > 1700
		let centuries = ((a:year / 100) - 17)
	else
		let centuries = 0
	endif
	if a:year > 1600
		let quad_centuries = ((a:year - 1600) / 400)
	else
		let quad_centuries = 0
	endif
	let leap_years = ((a:year / 4) - centuries + quad_centuries)
	return leap_years
endfunction



""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" day_in_year() 
" Returns the 1 based day number within the specified year.
" January 1 would be 1, December 31 would be 364 or 365.
" Taken from the cal program.

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:day_in_year(day, month, year)
	
	let i = 1
	let days = a:day
	while i < a:month
		if i == 2
			if s:is_leap_year(a:year)
				let days = days + 29
			else
				let days = days + 28
			endif
		else
			let days = days + s:get_days_in_month(i, a:year)
		endif
		let i = i + 1
	endwhile
	return days
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" is_leap_year() 
" Returns whether or not the given year is a leap year.
" Before 1753 a leap year was every 4 years.
" After 1752 a leap year is every 4 years unless it is a century year then it
" is counted every 4 centuries.

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:is_leap_year(year)

	if a:year <= 1752
		if a:year % 4
			return 0
		else 
			return 1
		endif
	elseif !(a:year % 4)
		if !(a:year % 100)
			if (a:year % 400)
				return 0
			else
				return 1
			endif
		else
			return 1
		endif
	else
		return 0
	endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" setup_syntax()  
" Sets the syntax to highlight appointments in the monthly calendar.

" The idea is to highlight the days in the monthly calendar based on 
" the type of appointment.  The appointment text for monthly and yearly 
" repeating dates is highlighted, while the text for weekly repeating 
" appointments and non repeating appointments is not highlighted.  

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:setup_syntax()

	if version < 600
		syntax clear
"	elseif exists("b:current_syntax")
"		return
	endif

	" Month names and day names are always highlighted.
	syn keyword vcalMonth 	January February March April May June July August September October November December

	syn keyword vcalDay Su Mo Tu We Th Fr Sa

	syn match vcalNumber "[0-9]"
	syn match vcalSeparator "^---*"
	syn match vcalYear "2[0-9][0-9][0-9]"
	syn match vcalHour "[0-9][0-9]:[0-9][0-9]\|[0-9]:[0-9][0-9]"


	" After the separator line get the appointments to highlight
	0
	/^---
	let start_line = line(".")
	let start_line = start_line + 1
	exe "$"
	let end_line = line(".")
	exe start_line


	"Normal Appointments - just the date is highlighted.
	while start_line <= end_line
		let end_match = match(getline(start_line), " \- ")
		let result = strpart(getline(start_line), 0, end_match)
		if match(result, "[0-9]") == 0
			let str1 = matchstr(getline(start_line), "\\d\\d:\\d\\d", 0)
			let cmd = "syn keyword vcalHour " . str1
			exe cmd
			let cmd = "syn match vcalAppt \"\\_s" . result . "\\_s\\|^". result . "\\_s\""
			exe cmd
		endif
		"Daily and weekly repeating dates. Highlight date and text.
		let end_match = match(getline(start_line), " \+ ")
		let result = strpart(getline(start_line), 0, end_match)
		if match(result, "[0-9]") == 0
			let cmd = "syn match vcalSpecialDay \"\\_s" . result . "\\_s\\|^". result . "\\_s\""
			exe cmd
			let line = getline(start_line)
			let str1 = matchstr(line, "\\d\\d:\\d\\d", 0)
			let cmd = "syn keyword vcalHour " . str1
			exe cmd
			let str1 = matchend(line, "\:\\d\\d\\_s")
			if str1 == -1
				break
			endif
			let str2 = matchend(line, "\\(\\w*\\)\\%$", str1)
			if str2 == -1
				break
			endif
			let result = strpart(line, str1, str2 - str1)
			let cmd = "syn match vcalSpecialDay  \"" . result  . "\""  
			exe cmd
		endif

		" Highlight monthly and yearly repeating dates and text.
		let end_match = match(getline(start_line), " \\* ")
		let result = strpart(getline(start_line), 0, end_match)
		if match(result, "[0-9]") == 0
			let cmd = "syn match vcalHoliday \"\\_s" . result . "\\_s\\|^". result . "\\_s\""
			exe cmd
			let line = getline(start_line)
			let str1 = matchstr(line, "\\d\\d:\\d\\d", 0)
			let cmd = "syn keyword vcalHour " . str1
			exe cmd
			let str1 = matchend(line, "\:\\d\\d\\_s")
			if str1 == -1
				break
			endif
			let str2 = matchend(line, "\\(\\w*\\)\\%$", str1)
			if str2 == -1
				break
			endif
			let result = strpart(line, str1, str2 - str1)
			let cmd = "syn match vcalHoliday  \"" . result  . "\""  
			exe cmd
		endif
		let start_line = start_line + 1
	endwhile

	" Highlight todays date. 
	if g:Vcalmonth_showing == g:Vcalthis_month && g:Vcalyear_showing == g:Vcalthis_year
		let cmd = "syn keyword vcalToday " . g:Vcalthis_day
		exe cmd
		let cmd = "syn match vcalToday \"\\_s" . g:Vcalthis_day . "\\_s\\|^". g:Vcalthis_day . "\\_s\""
		exe cmd
	endif


	" Define the default highlighting.
	if version >= 508 || !exists("did_vcal_syntax_inits")
		if version < 508
			let did_vcal_syntax_inits = 1
			command -nargs=+ HiLink hi link <args>
		else
			command -nargs=+ HiLink hi def link <args>
		endif

		HiLink vcalMonth		  Include
		HiLink vcalDay  		  Comment
		HiLink vcalYear		    Include
		HiLink vcalNumber  		Constant
		HiLink vcalSeparator	Include
		HiLink vcalToday 		  Conditional
		HiLink vcalHoliday		Type
		HiLink vcalAppt		    Comment
		HiLink vcalSpecialDay Include
		HiLink vcalHour       Constant

		delcommand HiLink
	endif

	let b:current_syntax = "vcal"

endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" show_vcf_dates()
" Adds the .vcf file dates to the calendar.
" A lot of the vcf info is not added yet.

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:show_vcf_dates(day, month, year)

	let end = 0
	let start = 0
	let space = " "
	let repeat = 0
	let not_done = 1

	let cmd = "cat " . s:Vcalfile
	let s:Vcaluser_vcf = system(cmd)
	let s:Vcaluser_vcf = substitute(s:Vcaluser_vcf, "\<CR>", " ", "g")
	let month_days = s:get_days_in_month(a:month, a:year)


	while not_done
		let apptend = match(s:Vcaluser_vcf, "END:VEVENT", start)
		let start = matchend(s:Vcaluser_vcf, "DTSTART:", end)
		let year = strpart(s:Vcaluser_vcf, start, 4) + 0
		let month = strpart(s:Vcaluser_vcf, start + 4, 2)
		if strpart(month, 0, 1) == '0'
			let month = strpart(month, 1, 1) + 0
		endif
		let day = strpart(s:Vcaluser_vcf, start + 6, 2)
		if strpart(day, 0, 1) == '0'
			let day = strpart(day, 1, 1) + 0
		endif
		let hour = strpart(s:Vcaluser_vcf, start + 9, 2)
		let min = strpart(s:Vcaluser_vcf, start + 11, 2)
		let end = start + 8

		" Exceptions to a repeating item
		let except = matchend(s:Vcaluser_vcf, "EXDATE:", end)
		if except != -1 && except < apptend
			let end = match(s:Vcaluser_vcf, "SUMMARY:", except)
			let exceptions = strpart(s:Vcaluser_vcf, except, end - except)
		else 
			let exceptions = ""
		endif
		let end = start + 8
		let start = matchend(s:Vcaluser_vcf, "SUMMARY:",  end)
		let end = match(s:Vcaluser_vcf, "STATUS:", start)
		let content = strpart(s:Vcaluser_vcf, start, end  - start)
		let start = matchend(s:Vcaluser_vcf, "RRULE:", end)
		if start != -1 && start < apptend
			let repeat = strpart(s:Vcaluser_vcf, start, apptend - start)
		else
			let repeat = 0
			let start = end
		endif
		let start =  match(s:Vcaluser_vcf, "BEGIN:VEVENT", apptend) 
		if start == -1
			let not_done = 0
		endif
		let end = start

		" Check the start date of the appointment.
		if a:year < year
			continue
		endif
		if a:year == year
			if a:month < month
				continue
			endif
		endif

		let repeat_type = strpart(repeat, 0, 1)

		"Repeat by Days or Weeks
		if repeat_type == 'W' || repeat_type == 'D'
			let pos = match(repeat, " ", 0)
			let repeat_num = strpart(repeat, 1, pos - 1) + 0
			while year < a:year 
				if repeat_type == 'D'
					let day = day + repeat_num
				else
					let day = day + (repeat_num * 7)
				endif
				while (day > s:get_days_in_month(month, year)) 
						let day = day - s:get_days_in_month(month, year) 
						if month == 12 
							let year = year + 1
							let month = 1
						else
							let month = month + 1
						endif
				endwhile
			endwhile

			while month < a:month
				if repeat_type == 'D'
					let day = day + repeat_num
				else
					let day = day + (repeat_num * 7)
				endif
				while (day > s:get_days_in_month(month, year)) 
						let day = day - s:get_days_in_month(month, year) 
						if month == 12 
							let year = year + 1
							let month = 1
						else
							let month = month + 1
						endif
				endwhile
			endwhile

			while day <= month_days

				if !s:is_exception_date(exceptions, year, month, day)
					let appt = day . " " . "+" . " " . hour .":". min . " ". content
					put =appt
				endif
				if repeat_type == 'D'
					if((day + repeat_num) > month_days)
						break
					endif
				else
					if((day + (repeat_num * 7)) > month_days)
						break
					endif
				endif
				if repeat_type == 'D'
					let day = day + repeat_num
				else
				 let day = s:add_ndays(day, month, year, repeat_num * 7, "day")
				endif
			endwhile

		"Repeat by Months
		elseif repeat_type == 'M'
			let pos = match(repeat, " ", 0)
			let repeat_num = strpart(repeat, 2, pos - 2)
			let pos = matchend(repeat, " ", 0)
			let endpos = match(repeat, " ", pos)
			let complex = strpart(repeat, pos, endpos - pos)
			let complex = complex + 0
			" Dates that repeat on the nth weekday of the month like Thanksgiving
			if complex
				let pos = matchend(repeat, " ", endpos)
				let endpos = match(repeat, " ", pos)
				let weekday = strpart(repeat, pos, endpos - pos)
				if weekday =~ "SU"
					let weekday = 0
				elseif weekday =~ "MO"
					let weekday = 1
				elseif weekday =~ "TU"
					let weekday = 2
				elseif weekday =~ "WE"
					let weekday = 3
				elseif weekday =~ "TH"
					let weekday = 4
				elseif weekday =~ "FR"
					let weekday = 5
				elseif weekday =~ "SA"
					let weekday = 6
				else
					let complex = 0
				endif
			endif
			while year < a:year 
				let month =  month + repeat_num
				if month > 12
					let year = year + 1
					let month = month - 12
				endif
			endwhile
			while month < a:month
				if month == a:month
					let appt = day . " " . "*" . " " . hour . ":" . min . " " . content
					put =appt
				endif
				let month = month + repeat_num
			endwhile
			if month == a:month
				if complex
					let day = s:nth_weekday(year, month, complex, weekday)
				endif
				if !s:is_exception_date(exceptions, year, month, day)
					let appt = day . " " . "*" . " " . hour . ":". min . " " . content
					put =appt
				endif
			endif

		"Repeat by Years
		elseif repeat_type == 'Y'
			let pos = match(repeat, " ", 0)
			let repeat_num = strpart(repeat, 2, pos - 2)
			while year < a:year
				let year = year + repeat_num
			endwhile
			if year == a:year && month == a:month
				if !s:is_exception_date(exceptions, year, month, day)
					let appt = day . " " . "*" . " " . hour . ":" . min . " " . content
					put =appt
				endif
			endif

		"Appointment does not repeat
		else
				if month == a:month && year == a:year
				let appt = day . " " . "-". " " . hour . ":" . min . " " . content
				put =appt
			endif
		endif
	endwhile

	" This can be a very long string so free up the memory.
	unlet s:Vcaluser_vcf

	"Examples of holidays set with a function.  
	"Easter Sunday
	if a:month == s:EasterSunday(a:year, 0)
		let easter = s:EasterSunday(a:year, 1)
		let appt = easter . " *" . " 12:00 Easter Sunday"
		put = appt
	endif

	"Boxing Day - First weekday after December 25th
	if a:month == 12
		let appt = s:BoxingDay()
		let appt = appt . " * 12:00 Boxing Day"
		put =appt
	endif

	"Leap Year
	if a:month == 2
		if s:is_leap_year(a:year)
			let appt = "29 * 12:00 Leap Year"
			put =appt
		endif
	endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" is_exception_date()
" checks for exceptions to repeating dates

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:is_exception_date(exceptions, year, month, day)

	if strlen(a:exceptions) < 8
		return 0
	endif

	let index = 0

	while index < strlen(a:exceptions)
		let ending_pos = matchend(a:exceptions, ",", index)
		"More than one exception
		if ending_pos > -1
			let exyr = strpart(a:exceptions, index, 4)
			let exmon = strpart(a:exceptions, index + 4, 2) + 0
			let exdy = strpart(a:exceptions, index + 6, 2) + 0
			if a:year == exyr && a:month == exmon && a:day == exdy
				return 1
			endif
			let index = ending_pos  
		else
			let exyr = strpart(a:exceptions, index, 4)
			let exmon = strpart(a:exceptions, index + 4, 2) + 0
			let exdy = strpart(a:exceptions, index + 6, 2) + 0
			if a:year == exyr && a:month == exmon && a:day == exdy
				return 1
			else
				return 0
			endif
		endif
	endwhile
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" set_alarm() 
" Set up an alarm
" Suggestions are welcome.  I don't know how to do this in the console except
" to use the at command to mail the user a message or to use a separate 
" program to ring the bell.

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:set_alarm()

	"This assumes you are running in X and not in the console.
	let time = input("Enter 24 hour time for alarm HH:MM: ")
	let message = input("Enter Message: ")
	let msg = "xmessage -display :0.0 " . "'" . message . "'"
	let cmd = "echo " . msg . " > ~/.vcal_Alarm"
	call system(cmd)
	let cmd = "at -f ~/.vcal_Alarm " . time 
	call system(cmd)
	let cmd = "rm -f ~/.vcal_Alarm"
	call system(cmd)
	

endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" remove_commands()  
" Removes all of the vcal commands except Vcal.  Called when leaving the 
" vcal buffer.

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:remove_commands()
	
	"Remove uneeded commands.
	delc TodayVcal
	delc AlarmVcal
	delc DateVcal
	delc ApptVcal
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" nth_weekday()   
" Returns the the date that the nth day-of-week occurs on.
"	16 = nth_weekday(2001, 12, 3, 0)
"	returns the date (16) of the 3rd Sunday of December, 2001
" The day of week numbers are 0 based.  Sunday = 0, Saturday = 6
" Used for dates like Thanksgiving the 4th Thursday of November
" Taken from the cal program

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:nth_weekday(year, month, nth_day, day_of_week)

    let weeks_counted = 0

    let month_days = s:get_days_in_month(a:month, a:year)

    let first_dow = s:day_in_week(1, a:month, a:year)

    if a:nth_day == 1 && a:day_of_week >= first_dow 
        let day = a:day_of_week - first_dow + 1
        return day;
    endif

    let day = 7 - first_dow

    if a:day_of_week >= first_dow 
			let weeks_counted = weeks_counted + 1
		endif

    while weeks_counted < a:nth_day 

        if day + a:day_of_week + 1 > month_days 
					break
				endif

        let weeks_counted = weeks_counted + 1
        if weeks_counted < a:nth_day 
					let day = day + 7
				endif

		endwhile

    if a:nth_day != 9 && weeks_counted != a:nth_day
			return -1
		endif

    let day = day + a:day_of_week + 1
    return day
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" add_ndays()  
" Returns year, month, or day of date + n days
" From the cal program.

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:add_ndays(day, month, year, n_days, return_value)

	let dy = a:day
	let mon = a:month
	let yr = a:year
	let dy = dy + a:n_days
	while (dy > s:get_days_in_month(mon, yr)) 
			let dy = dy - s:get_days_in_month(mon, yr) 
			if mon == 12 
				let yr = yr + 1
				let mon = 1
			else
				let mon = mon + 1
			endif
	endwhile

	if a:return_value == "year"
		return yr
	elseif a:return_value == "month"
		return mon
	elseif a:return_value == "day"
		return dy
	endif

endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" set_appointment()  
" Adds a new appointment to the calendar.

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:set_appointment()

	let dys_mon = s:get_days_in_month(g:Vcalmonth_showing, g:Vcalyear_showing)
	let day = input("Day 1-". dys_mon . ": ")
	if day + 0 < 1 || day + 0 > s:get_days_in_month(g:Vcalmonth_showing, g:Vcalyear_showing)
		let day = g:Vcalthis_day
	endif
	let hour = input("Enter 24 hour time for appointment HH:MM: ", strftime("%H:%M"))
	if strlen(hour) > 4
		let pos = matchend(hour, "\:")
		let min = strpart(hour, pos, 2)
		let hour = strpart(hour, 0, 2)
	else
		let pos = matchend(hour, "\:")
		let min = strpart(hour, pos, 2)
		let hour = strpart(hour, 0, 2)
		" 9:00 instead of 09:00
		if strlen(hour) == 1
			let hour = "0" . hour
		else
			let hour = strftime("%H")
			let min = strftime("%M")
		endif
	endif
	let msg = input("Message: ")
	if strlen(msg) < 2
		echo "Empty.  Canceling Appointment."
		return
	endif

	let recurr = input("Repeating appointment? y/n ")
	while 1
		if recurr == "y"
			let repeat_type = input("Repeat - d = daily, w = weekly, m = monthly, y = yearly : ")
			while 1
				if repeat_type == "d"
					let days = input("Repeat every how many days? ", 14)
					let repeat_string = "RRULE:D" . days . " #0\n"
					break
				elseif repeat_type == "w"
					let weeks = input("Repeat every how many weeks? ", 2)
					let weekday = s:day_in_week(day, g:Vcalmonth_showing, g:Vcalyear_showing)
					if weekday == 0
						let weekday = "SU"
					elseif weekday == 1
						let weekday = "MO"
					elseif weekday == 2
						let weekday = "TU"
					elseif weekday == 3
						let weekday = "WE"
					elseif weekday == 4
						let weekday = "TH"
					elseif weekday == 5
						let weekday = "FR"
					elseif weekday == 6
						let weekday = "SA"
					endif

					let repeat_string = "RRULE:W" . weeks . " " . weekday . " #0\n" 
					break
				elseif repeat_type == "m"
					let months = input("Repeat every how many months? ", 12)
					let repeat_string = s:get_complex_date(day, months)
					if strlen(repeat_string) < 4
						return
					endif
					break
				elseif repeat_type == "y"
					let years = input("Repeat every how many years? ", 1)
					let repeat_string = "RRULE:YD" . years . " #0\n""
					break
				else
					let repeat_type = input("Repeat - d = daily, w = weekly, m = monthly, y = yearly: ")
				endif
			endwhile
			break
		elseif recurr == "n"
			let repeat_string = ""
			break
		else
			let recurr = input("Repeating appointment? y/n ")
		endif
	endwhile
	
	let cmd = "cat " . s:Vcalfile
  let s:Vcaluser_vcf = system(cmd)
  let s:Vcaluser_vcf = substitute(s:Vcaluser_vcf, "\<CR>", " ", "g")


	let time = strftime("%H%M%S")
	let pos = match(s:Vcaluser_vcf, "BEGIN:VEVENT")
	let header = strpart(s:Vcaluser_vcf, 0, pos)
	let s:Vcaluser_vcf = strpart(s:Vcaluser_vcf, pos)
	if day < 10
		let day = "0" . day
	endif
	if g:Vcalmonth_showing < 10
		let g:Vcalmonth_showing = "0". g:Vcalmonth_showing
	endif
	let appt = "BEGIN:VEVENT\nSEQUENCE:-1\nDTSTART:" . g:Vcalyear_showing . g:Vcalmonth_showing . day . "T" . hour . min . "00" ."\nDTEND:" . g:Vcalyear_showing . g:Vcalmonth_showing . day . "T" . time . "\nDCREATED:" . g:Vcalyear_showing . g:Vcalmonth_showing . day . "T" . time . "\nLAST-MODIFIED:" . g:Vcalyear_showing . g:Vcalmonth_showing . day . "T" . time . "\nSUMMARY:" . msg . "\nSTATUS:NEEDS ACTION\nCLASS:PUBLIC\nPRIORITY:0\nTRANSP:0\nORGNAME:" . s:Vcaluser . "\n" . repeat_string . "END:VEVENT\n\n"


	let g:Vcalmonth_showing = g:Vcalmonth_showing + 0
	let cmd = "echo " . "\"" . header . appt .  s:Vcaluser_vcf . "\"" . " > " . s:Vcalfile
	call system(cmd)

 let cmd = "cat " . s:Vcalfile
 let s:Vcaluser_vcf = system(cmd)
 let s:Vcaluser_vcf = substitute(s:Vcaluser_vcf, "\<CR>", " ", "g")

 unlet s:Vcaluser_vcf

 call s:show_month(g:Vcalmonth_showing, g:Vcalyear_showing)


endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" get_complex_date()
" Returns the repeat rule for a complex date

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:get_complex_date(day, months)

	let weekday = s:day_in_week(a:day, g:Vcalmonth_showing, g:Vcalyear_showing)

	let index = 1
	while index < 6
		let dy = s:nth_weekday(g:Vcalyear_showing, g:Vcalmonth_showing, index, weekday)
		if dy == a:day
			break
		endif
		let index = index + 1
	endwhile
	if index == 1 || index == 21 || index == 31
		let ending = "st"
	elseif index == 2
		let ending = "nd"
	elseif index == 3
		let ending = "rd"
	else
		let ending = "th"
	endif

	if a:day == 1 || a:day == 21 || a:day == 31
		let dayend = "st"
	elseif a:day == 2 || a:day == 22
		let dayend = "nd"
	elseif a:day == 3 || a:day == 23
		let dayend = "rd"
	else
		let dayend = "th"
	endif

	if weekday == 0
		let weekday = "Sunday"
		let wd = "SU"
	elseif weekday == 1
		let weekday = "Monday"
		let wd = "MO"
	elseif weekday == 2
		let weekday = "Tuesday"
		let wd = "TU"
	elseif weekday == 3
		let weekday = "Wednesday"
		let wd = "WE"
	elseif weekday == 4
		let weekday = "Thursday"
		let wd = "TH"
	elseif weekday == 5
		let weekday = "Friday"
		let wd = "FR"
	elseif weekday == 6
		let weekday = "Saturday"
		let wd = "SA"
	endif

	echo " "
	if a:months == 1
		let answer = input("\na - Repeat on the " . a:day . dayend . " day of the month every month? \nb - Repeat on the " . index . ending . " " . weekday . " of every " . "month?\nc - Cancel  a\\b\\c?  ")

	else
		let answer = input("\na - Repeat on the " . a:day . dayend . " day of the month every " . s:months . " months?\nb - Repeat on the " . index . ending . " " . weekday . " of the month every " . s:months . " months?\nc - Cancel  a\\b\\c?  ")
	endif
	if answer == "a"
		return "RRULE:MD" . a:months . " " . a:day . " #0\n"
	elseif answer == "b"
		return "RRRULE:MP" . a:months . " " . index ."+ "	. wd . " #0\n"
	else
		return 0
	endif

endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" remove_appointment()
" Deletes the appointment under the cursor.

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:remove_appointment()
	let line_num = line(".")
	if line_num <= 11
		echo "Only appointments may be deleted"
		return
	endif

	setlocal modifiable

 	let cmd = "cat " . s:Vcalfile
 	let s:Vcaluser_vcf = system(cmd)
	let s:Vcaluser_vcf = substitute(s:Vcaluser_vcf, "\<CR>", " ", "g")


	let appointment = getline(".")
	let exdate = match(appointment, " ")
	let exday = strpart(appointment, 0, exdate) + 0
	if exday < 10
		let exday = "0" . exday
	endif
	let pos = matchend(appointment, "[0-9][0-9]:[0-9][0-9] ")
	let text = strpart(appointment, pos)
	let start = match(s:Vcaluser_vcf, escape(text, '*'))
	if start >= 0

		let pos = start + strlen(text)
		let dup_num = 0
		let dup = 1
		let s:file_end = match(s:Vcaluser_vcf, "END:VCALENDAR")
		while dup < s:file_end
			let dup = match(s:Vcaluser_vcf, text, pos)
			if dup == -1
				break
			endif
			let pos = dup + strlen(text)
			let dup_num = dup_num + 1
		endwhile

		let appt_start = 0
		let appt_end = matchend(s:Vcaluser_vcf, "END:VEVENT", start)
		while appt_start < appt_end
			let index = match(s:Vcaluser_vcf, "BEGIN:VEVENT", appt_start)
			let endindex = matchend(s:Vcaluser_vcf, "END:VEVENT", appt_start)
			if appt_end == endindex
				let appt_start = index
				break
			else
				let appt_start = endindex
			endif
		endwhile
		let remove = strpart(s:Vcaluser_vcf, appt_start, appt_end - appt_start)
		let repeats = match(remove, "RRULE", 0)
		if repeats >= 0
			let answer = input("This appoint repeats.\na - Rmove all occurances?\nb - Remove only this occurance?\nc - Cancel?\n a\\b\\c? ")
			if answer == 'a'
			elseif answer == 'b'
				if g:Vcalmonth_showing < 10
					let exmonth = "0" . g:Vcalmonth_showing
				else
					let exmonth = g:Vcalmonth_showing
				endif
				let exdate = matchend(remove, "EXDATE:")
				" No previous exception dates
				if exdate == -1
					let exdate = match(remove, "SUMMARY:")
					let exstring = "EXDATE:" . g:Vcalyear_showing . exmonth . exday . "T080000\n"
					let exdate_start = strpart(remove, 0, exdate)
					let exdate_end = strpart(remove, exdate)
					let remove = exdate_start . exstring . exdate_end
					let appt_start = strpart(s:Vcaluser_vcf, 0, appt_start)
					let appt_end = strpart(s:Vcaluser_vcf, appt_end +1)
					let s:Vcaluser_vcf = appt_start . remove . appt_end
					let cmd = "echo " . "\"" . s:Vcaluser_vcf . "\"" . " > " . s:Vcalfile
					call system(cmd)
				else
					let datepos = matchend(remove, "EXDATE:")
					if datepos == -1
						let datepos = exdate + 15
						echo "Error in reomoving repeating date. Aborting"
						return
					else 
						let exdate_start = strpart(remove, 0, datepos)
						let exdate_end = strpart(remove, datepos)
						let exstring =  g:Vcalyear_showing . exmonth . exday . "T080000,"
						let remove = exdate_start . exstring . exdate_end
						let appt_start = strpart(s:Vcaluser_vcf, 0, appt_start)
						let appt_end = strpart(s:Vcaluser_vcf, appt_end +1)
						let s:Vcaluser_vcf = appt_start . remove . appt_end
						let cmd = "echo " . "\"" . s:Vcaluser_vcf . "\"" . " > " . s:Vcalfile
						call system(cmd)
					endif

				endif

				echo " "
				setlocal nomodifiable
				unlet s:Vcaluser_vcf
				call s:show_month(g:Vcalmonth_showing, g:Vcalyear_showing)
				return
			else
				echo " "
				setlocal nomodifiable
				unlet s:Vcaluser_vcf
				return
			endif
		" More than one appointment matches the text and it is not a repeating appt.
		elseif dup_num
			let dup_num = dup_num + 1
			let text = "The text matches " . dup_num . " appointments aborting."
			echo text
			unlet s:Vcaluser_vcf
			setlocal nomodifiable
			return
		endif
		let appt_start = strpart(s:Vcaluser_vcf, 0, appt_start)
		let appt_end = strpart(s:Vcaluser_vcf, appt_end, strlen(s:Vcaluser_vcf) - appt_end)
		let s:Vcaluser_vcf = appt_start . appt_end

		let cmd = "echo " . "\"" . s:Vcaluser_vcf . "\"" . " > " . s:Vcalfile
		call system(cmd)
		echo " "
	else
		let answer = input("Unable to find appointment.  Press Return to continue.")
	endif
	
	unlet s:Vcaluser_vcf
	setlocal nomodifiable
	call s:show_month(g:Vcalmonth_showing, g:Vcalyear_showing)
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" EasterSunday()
" Gives the day and month of Easter.  This is valid only for the years 
" between 1583 and 4099.  Which is fine for an appointment calendar.
" This was written by David Hodges.

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:EasterSunday(year, return_value)

	if a:year < 1583 || a:year > 4089
		return 0
	endif
	let a = a:year / 100
	let b = a:year % 100
	let c = (3 * (a + 25)) / 4
	let d = (3 * (a + 25)) % 4
	let e = (8 * (a + 11)) / 25
	let f = (5 * a + b) % 19
	let g = (19 * f + c - e) % 30
	let h = (f + 11 * g) / 319
	let j = (60 * (5 - d) + b) / 4
	let k = (60 * (5 - d) + b) % 4
	let m = ( 2 * j - k - g + h) % 7
	let n = ( g - h + m + 114) / 31
	let p = ( g - h + m + 114) % 31

	if a:return_value == 1
		let easterday = p + 1
		return easterday
	else
		let eastermonth = n
		return eastermonth
	endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" BoxingDay()
" Adds Boxing Day to Calendar - The first weekday after Christmas

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:BoxingDay()
	let bday = s:day_in_week(25, g:Vcalmonth_showing, g:Vcalyear_showing) 
	if bday == 5
		let bday = 28
	elseif bday == 6
		let bday = 27
	else
		let bday = 26
	endif
	return bday
endfunction
