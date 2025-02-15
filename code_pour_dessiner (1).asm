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
display_name:	resq	1
screen:			resd	1
depth:         	resd	1
connection:    	resd	1
width:         	resd	1
height:        	resd	1
window:		resq	1
gc:		resq	1
foyers_x: resq 50    ; tableau pour stocker les coordonnées x des foyers
foyers_y: resq 50    ; tableau pour stocker les coordonnées y des foyers
nb_foyers: resd 1    ; nombre de foyers
point_x: resd 1      ; coordonnée x du point courant
point_y: resd 1      ; coordonnée y du point courant
dist_temp: resd 1    ; distance temporaire pour les calculs
min_dist: resd 1     ; distance minimale
closest_foyer: resd 1 ; index du foyer le plus proche

section .data

event:		times	24 dq 0

x1:	dd	0
x2:	dd	0
y1:	dd	0
y2:	dd	0
seed: dd 42          ; graine pour le générateur aléatoire

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
dessin:
    ; Générer les foyers
    mov dword[nb_foyers], 15   ; on commence avec 15 foyers
    
    ; Boucle pour générer les foyers
    xor r12, r12              ; compteur de foyers
generate_foyers:
    ; Générer x aléatoire (0-399)
    mov edi, 400
    call random
    mov [foyers_x + r12*8], eax
    
    ; Générer y aléatoire (0-399)
    mov edi, 400
    call random
    mov [foyers_y + r12*8], eax
    
    inc r12
    cmp r12, [nb_foyers]
    jl generate_foyers
    
    ; Dessiner 1000 points
    mov r13, 1000            ; nombre de points à dessiner
draw_points:
    ; Générer point aléatoire
    mov edi, 400
    call random
    mov [point_x], eax
    
    mov edi, 400
    call random
    mov [point_y], eax
    
    ; Trouver le foyer le plus proche
    mov dword[min_dist], 0x7FFFFFFF  ; initialiser avec une grande valeur
    xor r14, r14                     ; index du foyer courant
    
find_closest:
    ; Calculer distance = (x2-x1)²+(y2-y1)²
    mov eax, [foyers_x + r14*8]
    sub eax, dword[point_x]
    imul eax, eax                    ; (x2-x1)²
    mov dword[dist_temp], eax
    
    mov eax, [foyers_y + r14*8]
    sub eax, dword[point_y]
    imul eax, eax                    ; (y2-y1)²
    add dword[dist_temp], eax        ; distance = (x2-x1)²+(y2-y1)²
    
    ; Comparer avec la distance minimale
    mov eax, dword[dist_temp]
    cmp eax, dword[min_dist]
    jge not_closer
    mov dword[min_dist], eax
    mov dword[closest_foyer], r14d
    
not_closer:
    inc r14
    cmp r14, [nb_foyers]
    jl find_closest
    
    ; Dessiner la ligne entre le point et son foyer le plus proche
    mov rdi, qword[display_name]
    mov rsi, qword[gc]
    mov edx, 0x000000               ; couleur noire
    call XSetForeground
    
    ; Dessiner la ligne
    mov rdi, qword[display_name]
    mov rsi, qword[window]
    mov rdx, qword[gc]
    mov ecx, dword[point_x]         ; x1
    mov r8d, dword[point_y]         ; y1
    mov r15d, dword[closest_foyer]
    mov r9d, [foyers_x + r15*8]     ; x2
    push qword[foyers_y + r15*8]    ; y2
    call XDrawLine
    add rsp, 8                      ; nettoyer la pile
    
    dec r13
    jnz draw_points

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
	
; Fonction pour générer un nombre aléatoire entre 0 et max-1
random:
    push rbp
    mov rbp, rsp
    
    mov eax, dword[seed]
    imul eax, 1103515245
    add eax, 12345
    mov dword[seed], eax
    
    xor edx, edx
    div edi     ; divise par le paramètre max (dans edi)
    mov eax, edx ; retourne le reste
    
    mov rsp, rbp
    pop rbp
    ret
	
