%macro SYS_WRITE 0
    mov rax, 1
%endmacro

%macro SYS_READ 0
    xor rax, rax
%endmacro

%macro SYS_EXIT 0
    mov rax, 60
%endmacro

section .rodata
        ; Tablica mapowania - Rozwiązanie zadania polega na tym, że z każdym kodem morsa jest utożsamiana 
        ; pewna liczba (mapowanie znajduje się w tabeli map) i jej zapis binarny po usunięciu pierwszej 
        ; jedynki dekoduje znak morse - '0' odpowiada '.' zaś '1' odpowiada '-'. 
    map db 'E', 2, 'T', 3, 'I', 4, 'A', 5, 'N', 6, 'M', 7, 'S', 8, 'U', 9, 'R', 10, 'W', 11, 'D', 12, 'K', 13, 'G', 14, 'O', 15, 'H', 16, 'V', 17, 'F', 18, 'L', 20, 'P', 22, 'J', 23, 'B', 24, 'X', 25, 'C', 26, 'Y', 27, 'Z', 28, 'Q', 29, '5', 32, '4', 33, '3', 35, '2', 39, '1', 47, '6', 48, '7', 56, '8', 60, '9', 62, '0', 63

section .bss
    buffer_in resb 8192                                    ; Bufor wejściowy
    buffer_out resb 49152                                  ; Bufor wyjściowy - sześć razy większy niż bufor wejściowy. 

section .text
    global _start
_start:

    xor r8b, r8b                                           ; r8b - informacja o kierunku konwersji.
    mov r9b, 1                                             ; r9b - rejestr pomocniczy.
     
        ; Wczytywanie danych - Po wczytaniu danych do bufora wejściowego sprawdzamy czy nie ma końca pliku
        ; lub nie ma błędu. Następnie ustawiamy odpowiednie rejestry oraz sprawdzamy czy nie jesteśmy już 
        ; w trakcie konwersji (r8b = 1 oznacza morse->text zaś r8b = 2 oznacza text->morse).
read_loop:
    SYS_READ                                               
    mov rsi, buffer_in
    mov rdx, 8192
    xor rdi, rdi
    syscall
    test rax, rax                                          ; Sprawdzenie, czy koniec pliku lub błąd.
    jz end_program                                         ; Zakończ, jeśli rax == 0 (EOF).
    js exit_error                                          ; Zakończ, jeśli rax < 0 (błąd).
    mov rcx, rax                                           ; rcx - liczba wczytanych bajtów.
    mov rsi, buffer_in                                     ; rsi - wskaźnik na bufor wejsciowy.
    mov rdi, buffer_out                                    ; rdi - wskaźnik na bufor wyjściowy.
    cmp r8b, 1                                               
    je morse_to_text
    cmp r8b, 2
    je text_to_morse
    
        ; Sprawdzanie kierunku konwersji - Funkcja wykonuje się do momentu napotkania pierwszego znaku
        ; który nie jest spacją. W kolejnych wczytywaniach danych do bufora funkcja jest pomijana.
check_input:
    mov al, byte [rsi]                                     ; al - pojedynczy znak z bufora.
    cmp al, ' '
    je skip_space
    cmp al, '.'
    je morse_to_text
    cmp al, '-'
    je morse_to_text
    jmp text_to_morse
skip_space:                                                ; Pomijanie początkowtch spacji. 
    mov [rdi], al
    inc rdi
    inc rsi
    dec rcx
    test rcx, rcx
    jz print_buffer
    jmp check_input

        ; Zamiana kodu morsa na alfabet - Rejestr pomocniczy r9b jest początkowo równy 1. Gdy napotykamy
        ; kropkę to mnożymy go przez 2 a gdy kreskę to mnożymy przez 2 i dodajemy 1. W ten sposób do 
        ; początkowej jedynki konkatenujemy 0 lub 1 odpowiednio. Po natrafieniu na spację wyszukujemy
        ; daną liczbę w tabeli map, zaś jeśli danej liczby nie ma to oznacza że kod był niepoprawny i 
        ; zgłaszamy błąd. Jeśli wczytamy znak różny od ' ', '.' lub '-' to zgłaszamy błąd.        
morse_to_text:
    mov r8b, 1
    test rcx, rcx                                          ; Jeśli wczytano cały bufor wejściowy to
    je print_buffer                                        ; skocz do wypisywania bufora.
    mov al, byte [rsi]
    dec rcx
    cmp al, ' '
    je space
    cmp al, '.'
    je dot
    cmp al, '-'
    je dash
    jmp exit_error
dot:
    shl r9b, 1
    inc rsi
    jmp morse_to_text
dash:
    shl r9b, 1
    add r9b, 1
    inc rsi
    jmp morse_to_text
space:
    cmp r9b, 1
    je double_space
    mov rbx, map                                           ; rbx - wskaźnik na tablice map.
find_map:                                                  ; Szukanie odpowiedniego znaku w tablicy map.
    mov al, byte [rbx]
    cmp al, 0
    je exit_error
    inc rbx
    cmp r9b, byte [rbx]                                    ; r9b - liczba której szukamy w tablicy. 
    je found_map
    add rbx, 1
    jmp find_map
found_map:                                                 ; Znaleziono szukaną literę.
    mov al, byte [rbx-1]                                   ; Litera z tablicy.
    mov [rdi], al
    inc rdi
    inc rsi
    mov r9b, 1
    jmp morse_to_text
double_space:                                              ; Przepisanie podwójnej spacji.
    mov al, ' '
    mov [rdi], al
    inc rdi
    inc rsi
    jmp morse_to_text

        ; Zamiana alfabetu na kod morsa - Dla danej litery szukamy w tabeli map odpowiadającą jej postać 
        ; binarną. Po znalezieniu odkodowujemy dana liczbę na kod morsa. Jeśli ostatnim bitem jest 0 to 
        ; zamieniamy je na kropkę, zaś jeśli ostatnim bitem jest 1 to zamieniamy je na kreskę. Robimy to
        ; przy użyciu rekurencji wstecznej, czyli po sprawdzeniu ostatniego bitu liczby przesuwamy binarnie
        ; do momentu aż liczba staje się jedynką (jest to początkowa jedynka którą chcemy usunąć).        
text_to_morse:
    mov r8b, 2
    mov al, byte [rsi]
    cmp al, ' '
    je copy_space
    mov rbx, map                                           ; rbx - wskaźnik na tablice map. 
    xor r9b, r9b
find_binary:                                               ; Znajdź odpowiednią wartość binarną w tablicy map.
    cmp al, byte [rbx + r9]
    je found_binary
    add r9b, 2
    cmp r9b, 70
    ja exit_error
    jmp find_binary
found_binary:                                              ; Znaleziono szukaną liczbę.
    movzx r9, r9b
    mov r9b, [rbx+r9+1]                                    ; Wartość binarna z tablicy.
    call encode_morse
copy_space:                                                ; Przepisanie spacji.
    mov byte [rdi], ' '
    inc rdi
    inc rsi
    loop text_to_morse
    jmp print_buffer                                       ; Jeśli koniec pętli (rcx = 0) to wypisz bufor.
encode_morse:                                              ; Odkodowywanie liczby na znaki morse (rekurencja wsteczna).
    cmp r9b, 1
    jle end_code
    test r9b, 1
    jz print_dot
    shr r9b, 1
    call encode_morse
    mov byte [rdi], '-'
    inc rdi
    ret
print_dot:
    shr r9b, 1
    call encode_morse
    mov byte [rdi], '.'
    inc rdi
    ret
end_code:
    ret

		; Wyjście z błędem. 
exit_error:                                                
    SYS_EXIT
    mov rdi, 1
    syscall

		; Wypisanie bufora wyjściowego - Po przeanalizowaniu wszystkich znaków z bufora wejściowego 
		; wypisujemy wynik czyli bufor wyjściowy. Bufor wyjściowy ma sześć razy większą długość niż 
		; bufor wejściowy gdyż w pesymistycznym przypadku (text_to_morse) dla każdego wczytanego znaku 
		; (cyfry) musimy wypisać sześć znaków (pięć '.' lub '-' oraz dodatkowa spacja). 
print_buffer:                                              
    mov rdx, rdi
    sub rdx, buffer_out
    SYS_WRITE
    mov rsi, buffer_out
    mov rdi, 1
    mov rax, 1
    syscall
    test rax, rax
    js exit_error
    jmp read_loop

		; Zakończenie programu - Sprawdzamy czy w konwersji morse_to_text ostatnim znakiem jest spacja.
		; Jeśli nie to zwracamy błąd.
end_program:                                              
    cmp r9b, 1                                             
    jne exit_error                                         
    SYS_EXIT
    xor rdi, rdi
    syscall
