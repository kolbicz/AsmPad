.386
MODEL FLAT, STDCALL
LOCALS
JUMPS

UNICODE=0

INCLUDE	W32.INC
INCLUDE	WIN.INC

EXTRN	_wsprintfA			: PROC

.DATA

szAppName	db MAX_PATH+10 dup (?)
szCurFile	db MAX_PATH dup (?)
szSaveMsg	db MAX_PATH+70 dup (?)
szUntitled	db "Untitled",0
szAppTitle	db " - Asmpad",0
szAccName	db "IDR_ACCEL",0
szMenuName	db "MAINMENU",0
szClassName	db "Asmpad_Class",0
		
stWinClass 	WNDCLASSEX 	<>
stMessage	MSG			<>
	
.DATA?

hApp		dd ?
hIcon		dd ?
hFile		dd ?
hAccel		dd ?
pszCmdLine	dd ?
lpdwEnd		dd ?
lpdwStart	dd ?

.CODE

Start:
	
	call	GetModuleHandleA, NULL
	mov		hApp, eax
	call	GetCommandLine
	inc		eax
	.WHILE		!byte ptr [eax]==22h
		inc		eax
	.ENDW
	inc		eax
	.IF		byte ptr [eax]==20h
		inc		eax
	.ENDIF
	mov		pszCmdLine, eax
	call	GetFileTitle, pszCmdLine, offset szAppName, MAX_PATH
	.IF		byte ptr [szAppName]==0
		call	lstrcpy, offset szAppName, offset szUntitled
	.ENDIF
	call	lstrcat, offset szAppName, offset szAppTitle
	call	InitCommonControls
	call	WinMain, hApp, NULL, pszCmdLine, SW_SHOWDEFAULT
	call	ExitProcess

WinMain	PROC, hDlg:HWND, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD 

	mov		stWinClass.wc_cbSize, WNDCLASSEX_
	mov		stWinClass.wc_style, NULL
	mov		stWinClass.wc_lpfnWndProc, offset WndProc
	mov		stWinClass.wc_cbClsExtra, NULL
	mov		stWinClass.wc_cbWndExtra, NULL
	push	hApp
	pop		stWinClass.wc_hInstance
	call	LoadIcon, hApp, IDI_ICON_2
	mov		hIcon, eax
	mov		stWinClass.wc_hIcon, eax
	call	LoadCursor, NULL, IDC_ARROW
	mov		stWinClass.wc_hCursor, eax
	mov		stWinClass.wc_hbrBackground, COLOR_WINDOW ;COLOR_3DFACE+1
	mov		stWinClass.wc_lpszMenuName, offset szMenuName
	mov		stWinClass.wc_lpszClassName, offset szClassName
	call	RegisterClassEx, offset stWinClass
	call	CreateWindowEx, WS_EX_CLIENTEDGE, offset szClassName, offset szAppName, \
			WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 768, 558, NULL, NULL, hApp, NULL
	mov		hDlg, eax
	call	ShowWindow, hDlg, SW_NORMAL
    call 	UpdateWindow, hDlg
    call	LoadAccelerators, hApp, offset szAccName
    mov		hAccel, eax
    .WHILE TRUE
        call	GetMessage, offset stMessage, NULL, 0, 0 
        .BREAK .IF eax==FALSE
        	call	IsDialogMessage, hDlg, offset stMessage
        	.IF		hDlg==NULL || eax==FALSE
				call	TranslateAccelerator, hDlg, hAccel, offset stMessage
				.IF		eax==FALSE
    				call 	TranslateMessage, offset stMessage
    				call	DispatchMessage, offset stMessage
    			.ENDIF
    		.ENDIF
    .ENDW
    mov     eax, stMessage.ms_wParam 
    ret
    
WinMain	ENDP

.DATA?

dwRead			dd ?
dwFileSize		dd ?
dwOldProtect	dd ?
pszFileText		dd ?

.CODE
	
LoadFile	PROC, hWndEdit:DWORD, pszFileName:LPSTR
	
   	call	CreateFile, pszFileName, GENERIC_READ, FILE_SHARE_READ+FILE_SHARE_WRITE, \
   			NULL, OPEN_EXISTING, NULL, NULL
   	mov		hFile, eax
	.IF		!hFile==INVALID_HANDLE_VALUE
      	call	GetFileSize, hFile, NULL
      	mov		dwFileSize, eax
      	inc		dwFileSize
      	.IF		!dwFileSize==INVALID_HANDLE_VALUE
         	call	GlobalAlloc, GMEM_FIXED+GMEM_ZEROINIT+GMEM_DDESHARE, dwFileSize
			mov		pszFileText, eax
         	.IF		!pszFileText==NULL
           	 	call	ReadFile, hFile, pszFileText, dwFileSize, offset dwRead, NULL
               	call	SetWindowText, hWndEdit, pszFileText
               	call	SetFocus, hWndEdit
            .ENDIF
            call	GlobalFree, pszFileText
        .ENDIF
	.ENDIF
   	ret

LoadFile	ENDP

.DATA?

dwWritten		dd ?
dwTextLength	dd ?
pszText			dd ?

.CODE

SaveFile	PROC, hWndEdit:HWND, pszFileName:LPSTR
	
	call	CreateFile, pszFileName, GENERIC_WRITE, FILE_SHARE_READ+FILE_SHARE_WRITE, \
			NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
	mov		hFile, eax
   	.IF		!hFile==INVALID_HANDLE_VALUE
	    call	GetWindowTextLengthA, hWndEdit
	    mov		dwTextLength, eax
	    inc		dwTextLength
	    .IF		dwTextLength>0
	        call	GlobalAlloc, GMEM_FIXED+GMEM_ZEROINIT, dwTextLength
	        mov		pszText, eax
	        .IF		!pszText==NULL	        
				call	GetWindowTextA, hWndEdit, pszText, dwTextLength
				dec		dwTextLength				
	            call	WriteFile, hFile, pszText, dwTextLength, offset dwWritten, NULL
	            call	GlobalFree, pszText
			.ENDIF
		.ENDIF
   .ENDIF
    call	CloseHandle, hFile
    call	SendMessage, hEdit, EM_SETMODIFY, FALSE, NULL    
	ret

SaveFile	ENDP

.DATA

szFileFilter	db "All Files (*.*)",0,"*.*",0,"Text Files (*.txt)",0,"*.txt",0,"Asm Files (*.asm)",0,"*.asm",0,0
szFileName		db MAX_PATH	dup (?)
szDefExt		db "asm",0

ofn   			OPENFILENAME <>

.CODE

DoFileOpenSave	PROC, hDlg:DWORD, bSave:BOOL
   	
   	call	RtlZeroMemory, offset ofn, OPENFILENAME_
	mov		ofn.on_lStructSize, OPENFILENAME_
	push	hDlg
	pop		ofn.on_hwndOwner
	mov		ofn.on_lpstrFilter, offset szFileFilter
	mov		ofn.on_lpstrFile, offset szFileName
	mov		ofn.on_nMaxFile, MAX_PATH
	mov		ofn.on_lpstrDefExt, offset szDefExt
   	.IF		bSave==TRUE
		mov		ofn.on_Flags, OFN_EXPLORER+OFN_PATHMUSTEXIST+OFN_HIDEREADONLY+OFN_OVERWRITEPROMPT
        call	GetSaveFileName, offset ofn
        call	SaveFile, hEdit, offset szFileName
	.ELSE
	     mov	ofn.on_Flags, OFN_EXPLORER+OFN_FILEMUSTEXIST+OFN_HIDEREADONLY
	     call	GetOpenFileName, offset ofn
	     call	LoadFile, hEdit, offset szFileName
	.ENDIF
	.IF		!byte ptr [szFileName]==0
		call	lstrcpy, offset szCurFile, offset szFileName
		call	GetFileTitle, offset szFileName, offset szAppName, MAX_PATH
		call	lstrcat, offset szAppName, offset szAppTitle
		call	SetWindowText, hDlg, offset szAppName
	.ENDIF
	call	RtlZeroMemory, offset szFileName, MAX_PATH
	ret
	
DoFileOpenSave	ENDP

.DATA

szEditClass		db "edit",0
szFontName		db "Fixedsys",0
szAboutApp		db "Asmpad",0
szChangeText1	db "The Text in the ",0
szChangeText2	db " file has changed.",0
szChangeText3	db 13,10,13,10,"Do you want to save changes?",0
szHelpFile		db "notepad.hlp",0
szAboutText		db "Coded in Win32Asm by HaRdLoCk",0
szTime			db 24 dup (?)
szTimeFmat		db "%ld:%02ld xM %02ld.%02ld.%ld",0
FINDMSGSTRING	db "commdlg_FindReplace",0

stReplace		FINDREPLACE		<>
stPrintDlg		PRINTDLGS		<>
stPageSetup		PAGESETUPDLGS	<>
stDocInfo		DOCINFO			<>
stFindText		FINDTEXT		<>
stFontDlg		CHOOSEFONT		<>
stLogFont		LOGFONT			<>
stRect			RECT			<>
stSysTime		SYSTEMTIME		<>

dwTrue			dd 000000001h
dwFalse			dd 000000000h
dwBufferSize	dd LF_FACESIZE

.DATA?

hEdit			dd ?
hFont			dd ?
hMenu			dd ?
hMem			dd ?
hMemSave		dd ?
hMemSave2		dd ?
hRegKey			dd ?

bWordWrap		dd ?

pszMem			dd ?

dwhDc			dd ?
dwFontSize		dd ?
dwValueType		dd ?
dwHour			dd ?
dwMinute		dd ?
dwDay			dd ?
dwMonth			dd ?
dwMemLenght		dd ?
dwYear			dd ?
dwAmPm			dd ?
dwLineCount		dd ?

.CODE

WndProc	PROC, hDlg:HWND, uMsg:UINT, wPara:WPARAM, lPara:LPARAM
	
	.IF		uMsg==WM_CREATE
       	call	RegOpenKeyExA, HKEY_CURRENT_USER, offset szSubKey, NULL, KEY_QUERY_VALUE, offset hRegKey
        call	RegQueryValueExA, hRegKey, offset szWrap, NULL, NULL, offset bWordWrap, offset dwcbData
        call	RegQueryValueExA, hRegKey, offset szHeight, NULL, NULL, offset stFontDlg.cf_iPointSize, offset dwcbData
        call	RegQueryValueExA, hRegKey, offset szFaceName, NULL, NULL, offset stLogFont.lf_lfFaceName, offset dwBufferSize
        call	RegCloseKey, hRegKey     
       	call	GetMenu, hDlg
       	mov		hMenu, eax
	    call	DoWordWrapThing
	    .IF		!byte ptr [pszCmdLine]==0
        	call	LoadFile, hEdit, pszCmdLine
        .ENDIF
       	call	SetFocus, hEdit
       	call	CreateFontIndirectA, offset stLogFont
       	;call	CreateFontA, 13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, \
        ;		OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH, offset szFontName
       	mov		hFont, eax
       	call	SendMessageA, hEdit, WM_SETFONT, hFont, TRUE
       	call	RegisterWindowMessageA, offset FINDMSGSTRING
	.ELSEIF	uMsg==WM_SIZE
		.IF		!wPara==SIZE_MINIMIZED
	    	call	GetClientRect, hDlg, offset stRect
	        call	MoveWindow, hEdit, 0, 0, stRect.rc_right, stRect.rc_bottom, TRUE
		.ENDIF
	.ELSEIF	uMsg==WM_COMMAND
		.IF		wPara==CM_FILE_NEW
			call	CheckIfFileChanged
			.IF	eax==IDNO
				call	lstrcpy, offset szAppName, offset szUntitled
				call	lstrcat, offset szAppName, offset szAppTitle
				call	SetWindowText, hDlg, offset szAppName
				call	SetWindowText, hEdit, NULL
				call	SetFocus, hEdit
			.ENDIF
        .ELSEIF		wPara==CM_FILE_OPEN
			call	DoFileOpenSave, hDlg, FALSE
			call	SetWindowText, hDlg, offset szAppName			
        .ELSEIF	wPara==CM_FILE_SAVE
        	.IF		byte ptr [szAppName]=="U"
        		call	DoFileOpenSave, hDlg, TRUE
        	.ELSE
            	call	SaveFile, hEdit, offset szCurFile
				call	SetWindowText, hDlg, offset szAppName
			.ENDIF
        .ELSEIF	wPara==CM_FILE_SAVEAS
            call	DoFileOpenSave, hDlg, TRUE
        .ELSEIF	wPara==CM_FILE_PAGE
			mov		stPageSetup.pa_lStructSize, PAGESETUPDLGS_
			push	hDlg		
			pop		stPageSetup.pa_hwndOwner
			push	hApp
			pop		stPageSetup.pa_hInstance
        	;call	PageSetupDlgA, offset stPageSetup
        	call	DialogBoxParamA, hApp, 4002, hDlg, offset PrintDialogFunc, NULL
        .ELSEIF	wPara==CM_FILE_PRINT
        	call	SendMessage, hEdit, EM_GETLINECOUNT, NULL, NULL
        	mov		dwLineCount, eax
        	mov		stPrintDlg.pr_lStructSize, PRINTDLGS_
        	push	hDlg
        	pop		stPrintDlg.pr_hwndOwner
        	push	hApp
        	pop		stPrintDlg.pr_hInstance
         	mov     stPrintDlg.pr_Flags, PD_RETURNDC+PD_RETURNDEFAULT
        	call	PrintDlgA, offset stPrintDlg
         	mov     stDocInfo.cbSize, DOCINFO_
         	mov     stDocInfo.lpszDocName, offset szCurFile
         	;mov     stDocInfo.lpszOutput, NULL
         	;mov     stDocInfo.fwType, NULL
        	call 	StartDoc, stPrintDlg.pr_hDC, offset stDocInfo
        	call    StartPage, stPrintDlg.pr_hDC
        	call	SelectObject, stPrintDlg.pr_hDC, hFont
			call	GetWindowTextLengthA, hEdit
	    	mov		dwTextLength, eax
	    	inc		dwTextLength
	        call	GlobalAlloc, GMEM_FIXED+GMEM_ZEROINIT, dwTextLength
	        mov		pszText, eax	    	
	    	call	GetWindowTextA, hEdit, pszText, dwTextLength
        	call	TextOut, stPrintDlg.pr_hDC, 12, 12, pszText, dwTextLength
        	call	EndPage, stPrintDlg.pr_hDC
        	call	EndDoc, stPrintDlg.pr_hDC
        	call	DeleteDC, stPrintDlg.pr_hDC
        .ELSEIF	wPara==CM_FILE_EXIT
            call	PostMessage, hDlg, WM_CLOSE, NULL, NULL
        .ELSEIF	wPara==CM_EDIT_UNDO
        	call	SendMessage, hEdit, WM_UNDO, NULL, NULL
        .ELSEIF	wPara==CM_EDIT_CUT
        	call	SendMessage, hEdit, WM_CUT, NULL, NULL
        .ELSEIF	wPara==CM_EDIT_COPY
        	call	SendMessage, hEdit, WM_COPY, NULL, NULL
        .ELSEIF	wPara==CM_EDIT_PASTE
        	call	SendMessage, hEdit, WM_PASTE, NULL, NULL
        .ELSEIF	wPara==CM_EDIT_DELETE
        	call	SendMessage, hEdit, WM_CLEAR, NULL, NULL
        .ELSEIF	wPara==CM_EDIT_ALL
        	call	SetFocus, hEdit
        	call	SendMessage, hEdit, EM_SETSEL, 0, -1
        .ELSEIF	wPara==CM_EDIT_TIME
        	call	GetLocalTime, offset stSysTime
        	movsx	eax, stSysTime.st_wHour
        	mov		dwHour, eax
        	lea		edx, szTimeFmat
        	.WHILE	!byte ptr [edx]=="x"
        		inc 	edx
        	.ENDW
        	.IF		eax>11
        		mov		byte ptr [edx], "P"
        	.ELSE
        		mov		byte ptr [edx], "A"
        	.ENDIF
        	movsx	eax, stSysTime.st_wMinute
        	mov		dwMinute, eax
        	movsx	eax, stSysTime.st_wDay
        	mov		dwDay, eax
        	movsx	eax, stSysTime.st_wMonth
        	mov		dwMonth, eax        	
        	movsx	eax, stSysTime.st_wYear
        	mov		dwYear, eax
        	call	OpenClipboard, hDlg
        	call	EmptyClipboard        	
        	call	GlobalAlloc, GMEM_MOVEABLE+GMEM_DDESHARE, 40
        	mov		pszText, eax
        	call	GlobalLock, pszText
        	mov		hMem, eax
        	call	_wsprintfA, hMem, offset szTimeFmat, dwHour, dwMinute, dwDay, dwMonth, dwYear
        	call	SetClipboardData, CF_TEXT, hMem
        	call	CloseClipboard
        	call	SendMessageA, hEdit, WM_PASTE, NULL, NULL
        	call	GlobalUnlock, hMem
        	call	GlobalFree, pszText
        .ELSEIF	wPara==CM_EDIT_WRAP
        	call	SendMessage, hEdit, EM_GETMODIFY, NULL, NULL
        	push	eax
        	call	GetWindowTextLengthA, hEdit
	    	mov		dwTextLength, eax
	    	inc		dwTextLength
	        call	GlobalAlloc, GMEM_FIXED+GMEM_ZEROINIT, dwTextLength
	        mov		pszText, eax
	        call	GetWindowTextA, hEdit, pszText, dwTextLength
        	call	SendMessage, hEdit, WM_CLOSE, NULL, NULL
			call	DoWordWrapThing
			call	SetWindowTextA, hEdit, pszText
	        call	GlobalFree, pszText
	        call	SendMessageA, hEdit, WM_SETFONT, hFont, TRUE
	        call	SetFocus, hEdit
	        pop		eax
	        .IF		eax==TRUE
	        	call	SendMessage, hEdit, EM_SETMODIFY, TRUE, NULL
	        .ENDIF
        .ELSEIF	wPara==CM_EDIT_FONT
        	call	RegOpenKeyExA, HKEY_CURRENT_USER, offset szSubKey, NULL, KEY_QUERY_VALUE, offset hRegKey
        	;call	RegQueryValueExA, hRegKey, offset szHeight, NULL, NULL, offset stLogFont.lf_lfHeight, offset dwcbData
        	;call	RegQueryValueExA, hRegKey, offset szWidth, NULL, NULL, offset stLogFont.lf_lfWidth, offset dwcbData
        	;call	RegQueryValueExA, hRegKey, offset szEscapement, NULL, NULL, offset stLogFont.lf_lfEscapement, offset dwcbData
        	;call	RegQueryValueExA, hRegKey, offset szOrientation, NULL, NULL, offset stLogFont.lf_lfOrientation, offset dwcbData
        	;call	RegQueryValueExA, hRegKey, offset szFaceName, NULL, NULL, offset stLogFont.lf_lfFaceName, offset dwBufferSize
        	;call	RegQueryValueExA, hRegKey, offset szHeight, NULL, NULL, offset stLogFont.lf_lfHeight, offset dwcbData
        	;call	RegQueryValueExA, hRegKey, offset szFontSizeName, NULL, offset dwValueType, offset dwFontSize, 4
        	;call	RegQueryValueExA, hRegKey, offset szFaceName, NULL, NULL, offset stLogFont.lf_lfFaceName, offset dwBufferSize
        	call	RegCloseKey, hRegKey
        	mov		stFontDlg.cf_lStructSize, CHOOSEFONT_
        	push	hDlg
        	pop		stFontDlg.cf_hWndOwner
        	push	stLogFont.lf_lfHeight
        	pop		stFontDlg.cf_iPointSize
        	mov		stFontDlg.cf_lpLogFont, offset stLogFont
        	mov		stFontDlg.cf_Flags, CF_EFFECTS+CF_BOTH+CF_INITTOLOGFONTSTRUCT
        	call	ChooseFontA, offset stFontDlg
        	.IF		!eax==0
        		call	CreateFontIndirectA, offset stLogFont
        		mov		hFont, eax
        		call	SendMessageA, hEdit, WM_SETFONT, hFont, TRUE
        		call	SetFocus, hEdit
        	.ENDIF
        .ELSEIF	wPara==CM_SEARCH_FIND
        	mov		stReplace.fr_lpstrFindWhat, offset szFindText
        	mov		stReplace.fr_wFindWhatLen, MAX_STRING_LEN
        	mov		stReplace.fr_Flags, FR_DOWN+FR_HIDEWHOLEWORD
            mov		stReplace.fr_lStructSize, size FINDREPLACE
        	push	hDlg
        	pop		stReplace.fr_hwndOwner
        	push	hApp
        	pop		stReplace.fr_hInstance
        	call	FindTextA, offset stReplace
        .ELSEIF	wPara==CM_SEARCH_FINDNEXT
        	mov		stFindText.ft_chrg.cpMin, 0
        	mov		stFindText.ft_chrg.cpMax, -1
        	mov		stFindText.ft_lpstrText, offset szFindText
        	call	SendMessageA, hEdit, EM_FINDTEXT, NULL, offset stFindText
        .ELSEIF	wPara==CM_SEARCH_REPLACE
        	mov		stReplace.fr_lpstrReplaceWith, offset szReplaceText
        	mov		stReplace.fr_lpstrFindWhat, offset szFindText
        	mov		stReplace.fr_wFindWhatLen, MAX_STRING_LEN
        	mov		stReplace.fr_wReplaceWithLen, not NULL
        	mov		stReplace.fr_lStructSize, size FINDREPLACE
        	mov		stReplace.fr_Flags, FR_HIDEWHOLEWORD
        	push	hDlg
        	pop		stReplace.fr_hwndOwner
        	push	hApp
        	pop		stReplace.fr_hInstance
        	call	ReplaceTextA, offset stReplace
        	call	GetWindowTextLength, hEdit
        	mov		dwTextLength, eax
        	inc		eax
        	call	GlobalAlloc, GMEM_MOVEABLE+GMEM_ZEROINIT, eax
        	mov		pszText, eax
        	call	GetWindowTextA, hWndEdit, pszText, dwTextLength
        	mov		esi, pszText
        	lea		edx, szFindText
        	movsx	eax, byte ptr [esi]
        	movsx	ecx, byte ptr [edx]
        	.WHILE	!eax==ecx && !eax==0
        		inc		esi
        		inc		edx
        		movsx	eax, byte ptr [esi]
        		movsx	ecx, byte ptr [edx]
        	.ENDW
        	call	GlobalFree, pszText
        .ELSEIF	wPara==CM_HELP_HELP
        	call	WinHelp, hDlg, offset szHelpFile, HELP_CONTENTS, NULL
        .ELSEIF	wPara==CM_HELP_ABOUT
        	call	ShellAboutA, hDlg, offset szAboutApp, offset szAboutText, hIcon
        .ENDIF
	.ELSEIF	uMsg==WM_CLOSE
		call	CheckIfFileChanged
		.IF	eax==IDNO
			call	DestroyWindow, hDlg
		.ENDIF
	.ELSEIF	uMsg==WM_MENUSELECT
		call	SendMessage, hEdit, EM_GETMODIFY, NULL, NULL
    	.IF		eax==TRUE
	        call	EnableMenuItem, hMenu, CM_EDIT_UNDO, MF_ENABLED
	    .ELSE
	        call	EnableMenuItem, hMenu, CM_EDIT_UNDO, MF_GRAYED
	    .ENDIF
	    call	SendMessage, hEdit, EM_GETSEL, NULL, NULL
	    mov		edx, eax
	    shr		eax, 16
	    and		edx, 0FFFFh
	    .IF		!eax==edx
	       	call	EnableMenuItem, hMenu, CM_EDIT_CUT, MF_ENABLED
	       	call	EnableMenuItem, hMenu, CM_EDIT_COPY, MF_ENABLED
	       	call	EnableMenuItem, hMenu, CM_EDIT_DELETE, MF_ENABLED
	    .ELSE
	       	call	EnableMenuItem, hMenu, CM_EDIT_CUT, MF_GRAYED
	       	call	EnableMenuItem, hMenu, CM_EDIT_COPY, MF_GRAYED
	       	call	EnableMenuItem, hMenu, CM_EDIT_DELETE, MF_GRAYED
	    .ENDIF
	    call	OpenClipboard, hDlg
	    call	EnumClipboardFormats, CF_TEXT
	    .IF		eax==0
	    	call	EnableMenuItem, hMenu, CM_EDIT_PASTE, MF_GRAYED
	    .ELSE
	    	call	EnableMenuItem, hMenu, CM_EDIT_PASTE, MF_ENABLED
	    .ENDIF
	    call	CloseClipboard
    .ELSEIF	uMsg==WM_DESTROY
        call	PostQuitMessage, NULL
	.ELSE
        call	DefWindowProc, hDlg, uMsg, wPara, lPara
   	.ENDIF
   	
   ret

WndProc	ENDP

CheckIfFileChanged	Proc

call	SendMessage, hEdit, EM_GETMODIFY, NULL, NULL
.IF		eax==TRUE
	call	lstrcpy, offset szSaveMsg, offset szChangeText1
	.IF		byte ptr [szCurFile]==0
		call	lstrcat, offset szSaveMsg, offset szUntitled
	.ELSE
		call	lstrcat, offset szSaveMsg, offset szCurFile
	.ENDIF
	call	lstrcat, offset szSaveMsg, offset szChangeText2
	call	lstrcat, offset szSaveMsg, offset szChangeText3
	call	MessageBoxA, hDlg, offset szSaveMsg, offset szAboutApp, MB_YESNOCANCEL+MB_ICONEXCLAMATION
	.IF		eax==IDYES
		.IF		byte ptr [szAppName]=="U"
			call	DoFileOpenSave, hEdit, TRUE
		.ELSE
			call	SaveFile, hEdit, offset szCurFile
		.ENDIF
	.ENDIF
.ELSE
	mov		eax, IDNO
.ENDIF
ret
			
CheckIfFileChanged	ENDP

DoWordWrapThing		PROC
	
	call	GetClientRect, hDlg, offset stRect
   	call	RegOpenKeyExA, HKEY_CURRENT_USER, offset szSubKey, NULL, KEY_ALL_ACCESS, offset hRegKey
	.IF		bWordWrap==FALSE
		call	CreateWindowEx, NULL, offset szEditClass, NULL,\ 
        	    WS_CHILD+WS_VISIBLE+ES_LEFT+WS_VSCROLL+ES_MULTILINE+ES_WANTRETURN,\ 
            	CW_USEDEFAULT, CW_USEDEFAULT, stRect.rc_right, stRect.rc_bottom, hDlg, IDC_MAIN_TEXT, hApp, NULL
        mov		hEdit, eax
        call	CheckMenuItem, hMenu, CM_EDIT_WRAP, MF_CHECKED
    	call	RegSetValueExA, hRegKey, offset szWrap, NULL, REG_DWORD, offset dwTrue, 4        
        mov		bWordWrap, TRUE
    .ELSE
    	call	CreateWindowEx, NULL, offset szEditClass, NULL,\ 
        		WS_CHILD+WS_VISIBLE+ES_LEFT+ES_AUTOHSCROLL+WS_HSCROLL+WS_VSCROLL+ES_MULTILINE+ES_WANTRETURN,\ 
        		CW_USEDEFAULT, CW_USEDEFAULT, stRect.rc_right, stRect.rc_bottom, hDlg, IDC_MAIN_TEXT, hApp, NULL
   		mov		hEdit, eax
   		call	CheckMenuItem, hMenu, CM_EDIT_WRAP, MF_UNCHECKED
		call	RegSetValueExA, hRegKey, offset szWrap, NULL, REG_DWORD, offset dwFalse, 4           		
        mov		bWordWrap, FALSE
    .ENDIF
    call	RegCloseKey, hRegKey    
    ret

DoWordWrapThing		ENDP

PrintDialogFunc		PROC, hWndDlg:DWORD, uMsg:DWORD, wPara:DWORD, lPara:DWORD

	.IF		uMsg==WM_CLOSE
		call	EndDialog, hWndDlg, NULL
	.ELSEIF	uMsg==WM_COMMAND
		.IF		wPara==IDC_CANCEL
			call	EndDialog, hWndDlg, NULL
		.ELSEIF	wPara==IDC_OK
			call	MessageBoxA, hWndDlg, offset szSubKey, NULL, MB_OK
		.ENDIF
	.ENDIF
	xor		eax, eax
	ret

PrintDialogFunc		ENDP

.DATA

szHeight			db	"iPointSize",0
szWidth				db	"lfWidth",0
szEscapement		db	"lfEscapement",0
szOrientation		db	"lfOrientation",0
szWeight			db	"Weight",0
szItalic			db	"Italic",0
szUnderline			db	"Underline",0
szStrikeOut			db	"StrikeOut",0
szCharSet			db	"CharSet",0
szOutPrecision		db	"OutPrecision",0
szClipPrecision		db	"ClipPrecision",0
szQuality			db	"Quality",0
szPitchAndFamily 	db	"PitchAndFamily",0
szFaceName			db	"lfFaceName",0
szWrap				db 	"fWrap",0
szSubKey			db 	"Software\Microsoft\Notepad",0

szFindText			db	MAX_STRING_LEN DUP (?),0
szReplaceText		db	MAX_STRING_LEN DUP (?),0


dwcbData	dd 1
	
End Start