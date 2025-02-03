; external functions from X11 library
extern XOpenDisplay
extern XDisplayName
extern XCloseDisplay
extern XCreateSimpleWindow
extern XMapWindow
extern XRootWindow
extern XSelectInput
extern XFlush
extern XCreateGC
extern XSetForeground
extern XDrawLine
extern XDrawPoint
extern XNextEvent

; external functions from stdio library (ld-linux-x86-64.so.2)    
extern printf
extern exit

%define	StructureNotifyMask	131072
%define KeyPressMask		1
%define ButtonPressMask		4
%define MapNotify		19
%define KeyPress		2
%define ButtonPress		4
%define Expose			12
%define ConfigureNotify		22
%define CreateNotify 16
%define QWORD	8
%define DWORD	4
%define WORD	2
%define BYTE	1

global main

section .bss
display_name:    resq    1
screen:         resd    1
depth:          resd    1
connection:     resd    1
width:          resd    1
height:         resd    1
window:         resq    1
gc:             resq    1

; Arrays to store coordinates
foyers_x:       times 50 dd 0    ; Array for foyer x coordinates (max 50 foyers)
foyers_y:       times 50 dd 0    ; Array for foyer y coordinates
points_x:       times 2000 dd 0  ; Array for point x coordinates (max 2000 points)
points_y:       times 2000 dd 0  ; Array for point y coordinates
num_foyers:     resd 1           ; Number of foyers to generate
num_points:     resd 1           ; Number of points to generate

section .data
event:          times 24 dq 0
x1:             dd 0
x2:             dd 0
y1:             dd 0
y2:             dd 0
rand_seed:      dd 12345         ; Seed for random number generation

section .text
	
;##################################################
;########### PROGRAMME PRINCIPAL ##################
;##################################################

main:
xor     rdi,rdi
call    XOpenDisplay	; Création de display
mov     qword[display_name],rax	; rax=nom du display

; display_name structure
; screen = DefaultScreen(display_name);
mov     rax,qword[display_name]
mov     eax,dword[rax+0xe0]
mov     dword[screen],eax

mov rdi,qword[display_name]
mov esi,dword[screen]
call XRootWindow
mov rbx,rax

mov rdi,qword[display_name]
mov rsi,rbx
mov rdx,10
mov rcx,10
mov r8,400	; largeur
mov r9,400	; hauteur
push 0xFFFFFF	; background  0xRRGGBB
push 0x00FF00
push 1
call XCreateSimpleWindow
mov qword[window],rax

mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,131077 ;131072
call XSelectInput

mov rdi,qword[display_name]
mov rsi,qword[window]
call XMapWindow

mov rsi,qword[window]
mov rdx,0
mov rcx,0
call XCreateGC
mov qword[gc],rax

mov rdi,qword[display_name]
mov rsi,qword[gc]
mov rdx,0x000000	; Couleur du crayon
call XSetForeground

boucle: ; boucle de gestion des évènements
mov rdi,qword[display_name]
mov rsi,event
call XNextEvent

cmp dword[event],ConfigureNotify	; à l'apparition de la fenêtre
je dessin							; on saute au label 'dessin'

cmp dword[event],KeyPress			; Si on appuie sur une touche
je closeDisplay						; on saute au label 'closeDisplay' qui ferme la fenêtre
jmp boucle

;#########################################
;#		DEBUT DE LA ZONE DE DESSIN		 #
;#########################################
; Random number generation function
generate_random:
    push rbp
    mov rbp, rsp
    mov eax, dword[rand_seed]
    imul eax, 1103515245
    add eax, 12345
    mov dword[rand_seed], eax
    mov edx, 0
    div dword[rbp+16]    ; Divide by range parameter
    mov eax, edx         ; Return remainder
    pop rbp
    ret

dessin:
    ; Set initial values
    mov dword[num_foyers], 50     ; Number of foyers to generate
    mov dword[num_points], 2000   ; Number of points to generate

    ; Generate random foyers
    mov ecx, dword[num_foyers]
    xor esi, esi        ; Index counter
generate_foyers:
    push rcx
    
    ; Generate X coordinate (0-400)
    push 400
    call generate_random
    mov dword[foyers_x + esi*4], eax
    
    ; Generate Y coordinate (0-400)
    push 400
    call generate_random
    mov dword[foyers_y + esi*4], eax
    
    inc esi
    pop rcx
    loop generate_foyers

    ; Generate random points
    mov ecx, dword[num_points]
    xor esi, esi        ; Index counter
generate_points:
    push rcx
    
    ; Generate X coordinate (0-400)
    push 400
    call generate_random
    mov dword[points_x + esi*4], eax
    
    ; Generate Y coordinate (0-400)
    push 400
    call generate_random
    mov dword[points_y + esi*4], eax
    
    inc esi
    pop rcx
    loop generate_points

    ; Draw points and connect to nearest foyers
    mov ecx, dword[num_points]
    xor esi, esi        ; Point index
draw_points:
    push rcx
    
    ; Find nearest foyer for current point
    mov ebx, 0          ; Current nearest foyer index
    mov r12d, 0x7FFFFFFF ; Minimum distance (start with max int)
    
    mov r13d, dword[points_x + esi*4] ; Current point X
    mov r14d, dword[points_y + esi*4] ; Current point Y
    
    mov ecx, dword[num_foyers]
    xor edi, edi        ; Foyer index
find_nearest:
    push rcx
    
    ; Calculate distance: (x2-x1)^2 + (y2-y1)^2
    mov eax, dword[foyers_x + edi*4]
    sub eax, r13d
    imul eax, eax       ; (x2-x1)^2
    mov r15d, eax
    
    mov eax, dword[foyers_y + edi*4]
    sub eax, r14d
    imul eax, eax       ; (y2-y1)^2
    add r15d, eax       ; Total distance squared
    
    cmp r15d, r12d
    jae not_closer
    mov r12d, r15d      ; Update minimum distance
    mov ebx, edi        ; Update nearest foyer index
not_closer:
    inc edi
    pop rcx
    loop find_nearest
    
    ; Draw line from point to nearest foyer
    mov rdi, qword[display_name]
    mov rsi, qword[gc]
    mov edx, 0x000000   ; Black color
    call XSetForeground
    
    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, qword[gc]
    mov ecx, dword[points_x + esi*4]    ; Point X
    mov r8d, dword[points_y + esi*4]     ; Point Y
    mov r9d, dword[foyers_x + ebx*4]     ; Foyer X
    push qword[foyers_y + ebx*4]         ; Foyer Y
    call XDrawLine
    
    inc esi
    pop rcx
    loop draw_points

    jmp flush

;couleur du point 1
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0x0000FF	; Couleur du crayon ; bleu
call XSetForeground
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov rcx,10	; coordonnée en x
mov r8,50	; coordonnée en y
call XDrawPoint

;couleur de la ligne 1
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0xFF0000	; Couleur du crayon ; rouge
call XSetForeground
; coordonnées de la ligne 1
mov dword[x1],50
mov dword[y1],50
mov dword[x2],200
mov dword[y2],350
; dessin de la ligne 1
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,dword[x1]	; coordonnée source en x
mov r8d,dword[y1]	; coordonnée source en y
mov r9d,dword[x2]	; coordonnée destination en x
push qword[y2]		; coordonnée destination en y
call XDrawLine

;couleur de la ligne 2
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0x00FF00	; Couleur du crayon ; vert
call XSetForeground
; coordonnées de la ligne 2
mov dword[x1],50
mov dword[y1],350
mov dword[x2],200
mov dword[y2],50
; dessin de la ligne 2
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,dword[x1]	; coordonnée source en x
mov r8d,dword[y1]	; coordonnée source en y
mov r9d,dword[x2]	; coordonnée destination en x
push qword[y2]		; coordonnée destination en y
call XDrawLine

;couleur de la ligne 3
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0x00FFFF	; Couleur du crayon ; bleu
call XSetForeground
; coordonnées de la ligne 3	
mov dword[x1],275
mov dword[y1],50
mov dword[x2],275
mov dword[y2],350
; dessin de la ligne 3
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,dword[x1]	; coordonnée source en x
mov r8d,dword[y1]	; coordonnée source en y
mov r9d,dword[x2]	; coordonnée destination en x
push qword[y2]		; coordonnée destination en y
call XDrawLine

;couleur de la ligne 4
mov rdi,qword[display_name]
mov rsi,qword[gc]
mov edx,0xFF00FF	; Couleur du crayon ; violet
call XSetForeground
; coordonnées de la ligne 4	
mov dword[x1],350
mov dword[y1],50
mov dword[x2],350
mov dword[y2],350
; dessin de la ligne 4
mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,dword[x1]	; coordonnée source en x
mov r8d,dword[y1]	; coordonnée source en y
mov r9d,dword[x2]	; coordonnée destination en x
push qword[y2]		; coordonnée destination en y
call XDrawLine

; ############################
; # FIN DE LA ZONE DE DESSIN #
; ############################
jmp flush

flush:
mov rdi,qword[display_name]
call XFlush
jmp boucle
mov rax,34
syscall

closeDisplay:
    mov     rax,qword[display_name]
    mov     rdi,rax
    call    XCloseDisplay
    xor	    rdi,rdi
    call    exit
	
